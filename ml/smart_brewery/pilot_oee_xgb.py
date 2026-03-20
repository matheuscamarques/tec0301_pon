#!/usr/bin/env python3
"""
Piloto OEE (artigo 16): XGBoost com validação walk-forward e objetivo robusto (reg:pseudohubererror).

Requer CSVs de `mix export.ml`. Métricas em JSON (stdout ou --metrics-out).
Opcional: SHAP (pip install shap).

Usage:
  python pilot_oee_xgb.py /tmp/ml_export
  python pilot_oee_xgb.py /tmp/ml_export --metrics-out /tmp/oee_xgb_metrics.json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import mean_absolute_error, r2_score
from xgboost import XGBRegressor

from validation import (
    aggregate_walk_forward_metrics,
    walk_forward_folds,
)


def build_xy(root: Path):
    tel = pd.read_csv(root / "telemetry_events.csv", parse_dates=["ts"])
    oee = pd.read_csv(root / "oee_snapshots.csv", parse_dates=["ts"])
    if tel.empty or oee.empty:
        return None, None, []
    f8 = tel[tel["fact_name"].str.startswith("fbe_08_", na=False) & tel["value_float"].notna()]
    if f8.empty:
        f8 = tel[tel["value_float"].notna()].copy()
    wide = f8.pivot_table(
        index="ts", columns="fact_name", values="value_float", aggfunc="mean"
    )
    wide = wide.sort_index().resample("1min").mean().ffill().fillna(0.0)
    oee = oee.sort_values("ts").dropna(subset=["oee_pct"])
    feature_names = list(wide.columns)
    X_list, y_list = [], []
    for _, row in oee.iterrows():
        ts = row["ts"]
        sub = wide.loc[:ts]
        if sub.empty:
            continue
        X_list.append(sub.iloc[-1].values.astype(np.float64))
        y_list.append(float(row["oee_pct"]))
    if len(X_list) < 12:
        return None, None, feature_names
    X = np.stack(X_list)
    y = np.array(y_list)
    return X, y, feature_names


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("export_dir", type=Path)
    ap.add_argument("--min-train", type=int, default=16, help="mínimo de amostras na janela de treino")
    ap.add_argument("--test-size", type=int, default=1, help="tamanho do bloco de teste por fold")
    ap.add_argument("--step", type=int, default=1)
    ap.add_argument("--mode", choices=("rolling", "anchored"), default="rolling")
    ap.add_argument("--metrics-out", type=Path, default=None)
    ap.add_argument("--preds-jsonl", type=Path, default=None, help="opcional: JSONL para import.ml.predictions")
    ap.add_argument("--shap", action="store_true", help="SHAP summary (requer shap)")
    args = ap.parse_args()

    root = args.export_dir
    X, y, names = build_xy(root)
    if X is None:
        print("Dados insuficientes (telemetria/OEE vazios ou poucas amostras).", file=sys.stderr)
        sys.exit(1)

    n = X.shape[0]
    folds = walk_forward_folds(
        n,
        min_train_size=args.min_train,
        test_size=args.test_size,
        step=args.step,
        mode=args.mode,
    )
    if not folds:
        print("Walk-forward: poucos pontos para os parâmetros dados.", file=sys.stderr)
        sys.exit(1)

    y_true_all, y_pred_all = [], []
    preds_records = []
    for i, fold in enumerate(folds):
        tr, te = fold.train_slice, fold.test_slice
        X_tr, y_tr = X[tr], y[tr]
        X_te, y_te = X[te], y[te]
        model = XGBRegressor(
            n_estimators=120,
            max_depth=6,
            learning_rate=0.08,
            subsample=0.85,
            objective="reg:pseudohubererror",
            random_state=42,
            n_jobs=-1,
        )
        model.fit(X_tr, y_tr)
        pred = model.predict(X_te)
        y_true_all.append(y_te)
        y_pred_all.append(pred)
        for j, row_idx in enumerate(range(te.start, te.stop)):
            preds_records.append(
                {
                    "model_name": "oee_xgb_walkforward",
                    "target_name": "oee_pct",
                    "value_float": float(pred[j]),
                    "metadata": {"fold": i, "row": row_idx},
                }
            )

    agg = aggregate_walk_forward_metrics(y_true_all, y_pred_all)
    yt = np.concatenate([a.ravel() for a in y_true_all])
    yp = np.concatenate([a.ravel() for a in y_pred_all])
    agg["r2"] = float(r2_score(yt, yp)) if len(yt) > 1 else 0.0
    agg["mae_sklearn"] = float(mean_absolute_error(yt, yp))
    agg["n_folds"] = len(folds)
    agg["n_samples"] = n
    agg["feature_count"] = len(names)

    print(json.dumps(agg, indent=2))
    if args.metrics_out:
        args.metrics_out.write_text(json.dumps(agg, indent=2), encoding="utf-8")

    if args.preds_jsonl:
        with open(args.preds_jsonl, "w", encoding="utf-8") as f:
            for rec in preds_records:
                f.write(json.dumps(rec) + "\n")

    if args.shap:
        try:
            import shap
        except ImportError:
            print("pip install shap para --shap", file=sys.stderr)
            return
        model = XGBRegressor(
            n_estimators=120,
            max_depth=6,
            learning_rate=0.08,
            objective="reg:pseudohubererror",
            random_state=42,
            n_jobs=-1,
        )
        split = max(1, int(n * 0.8))
        model.fit(X[:split], y[:split])
        explainer = shap.TreeExplainer(model)
        sv = explainer.shap_values(X[split:])
        print("SHAP mean |value| (último bloco teste simples):")
        mean_abs = np.mean(np.abs(sv), axis=0)
        order = np.argsort(mean_abs)[::-1][: min(12, len(names))]
        for j in order:
            label = names[j] if j < len(names) else f"feat_{j}"
            print(f"  {label}: {mean_abs[j]:.6f}")


if __name__ == "__main__":
    main()
