#!/usr/bin/env python3
"""
Anomalias com supervisão fraca (artigo 16): pseudo-rótulos de `anomaly_events` + pesos
e destilação leve professor → aluno (RandomForest → Regressão logística / árvore rasa).

Features: janelas de telemetria FBE_01 (vibração, rpm, etc.) a partir de
`telemetry_events.csv`. Rótulo binário por janela: houve disparo de anomalia na janela
(merge por tempo).

Usage:
  python pilot_anomaly_weak_supervision.py /tmp/ml_export
  python pilot_anomaly_weak_supervision.py /tmp/ml_export --metrics-out /tmp/anom_ws.json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report, roc_auc_score
from validation import time_ordered_indices


def build_windows(root: Path, window_minutes: int = 5) -> tuple[np.ndarray, np.ndarray, np.ndarray] | None:
    tel = pd.read_csv(root / "telemetry_events.csv", parse_dates=["ts"])
    ano = pd.read_csv(root / "anomaly_events.csv", parse_dates=["ts"])
    if tel.empty:
        return None
    f1 = tel[tel["fact_name"].str.startswith("fbe_01_", na=False) & tel["value_float"].notna()]
    if f1.empty:
        f1 = tel[tel["value_float"].notna()].head(5000)
    wide = f1.pivot_table(index="ts", columns="fact_name", values="value_float", aggfunc="mean")
    wide = wide.sort_index().resample(f"{window_minutes}min").mean().ffill().fillna(0.0)
    if wide.shape[0] < 10:
        return None

    # pseudo-label: qualquer anomalia com fact fbe_01 no intervalo da linha temporal
    if not ano.empty:
        ano = ano[ano["fact_name"].str.startswith("fbe_01", na=False)]
    label_ts = set(ano["ts"].dt.floor(f"{window_minutes}min")) if not ano.empty else set()

    X_list, y_list, w_list = [], [], []
    for ts in wide.index:
        row = wide.loc[ts]
        y = 1 if ts in label_ts else 0
        # peso menor para positivos (evitar copiar só a heurística 3σ)
        w = 0.6 if y == 1 else 1.0
        X_list.append(row.values.astype(np.float64))
        y_list.append(y)
        w_list.append(w)

    X = np.stack(X_list)
    y = np.array(y_list)
    sw = np.array(w_list)
    return X, y, sw


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("export_dir", type=Path)
    ap.add_argument("--metrics-out", type=Path, default=None)
    ap.add_argument("--test-ratio", type=float, default=0.2)
    args = ap.parse_args()

    data = build_windows(args.export_dir)
    if data is None:
        print("Dados insuficientes.", file=sys.stderr)
        sys.exit(1)
    X, y, sw = data
    if np.unique(y).size < 2:
        print("Uma só classe nos pseudo-rótulos — rode a simulação mais tempo.", file=sys.stderr)
        sys.exit(0)

    n = X.shape[0]
    tr_idx, te_idx = time_ordered_indices(n, train_ratio=1.0 - args.test_ratio)
    X_tr, X_te = X[tr_idx], X[te_idx]
    y_tr, y_te = y[tr_idx], y[te_idx]
    sw_tr = sw[tr_idx]

    teacher = RandomForestClassifier(
        n_estimators=120, max_depth=10, class_weight="balanced", random_state=42, n_jobs=-1
    )
    teacher.fit(X_tr, y_tr, sample_weight=sw_tr)
    proba_te = teacher.predict_proba(X_te)[:, 1]

    # aluno: regressão logística em probabilidades do professor (destilação simples)
    z_tr = teacher.predict_proba(X_tr)[:, 1].reshape(-1, 1)
    z_te = teacher.predict_proba(X_te)[:, 1].reshape(-1, 1)
    student = LogisticRegression(max_iter=500, random_state=42)
    student.fit(z_tr, y_tr)
    student_pred = student.predict(z_te)
    student_proba = student.predict_proba(z_te)[:, 1]

    out = {
        "teacher_auc": float(roc_auc_score(y_te, proba_te)) if len(np.unique(y_te)) > 1 else None,
        "student_auc": float(roc_auc_score(y_te, student_proba)) if len(np.unique(y_te)) > 1 else None,
        "n_train": int(len(tr_idx)),
        "n_test": int(len(te_idx)),
    }
    print(json.dumps(out, indent=2))
    print("--- teacher test report ---")
    print(classification_report(y_te, teacher.predict(X_te), digits=3))
    print("--- student (distilled) on teacher logits ---")
    print(classification_report(y_te, student_pred, digits=3))

    if args.metrics_out:
        args.metrics_out.write_text(json.dumps(out, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
