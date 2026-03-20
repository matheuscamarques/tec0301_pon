#!/usr/bin/env python3
"""
Piloto: regressão Random Forest para oee_pct com features da telemetria FBE_08.
Validação temporal (últimos 20% como teste). Requer CSVs de `mix export.ml`.

Usage: python pilot_oee_rf.py /tmp/ml_export
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, r2_score


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
    if len(X_list) < 8:
        return None, None, feature_names
    X = np.stack(X_list)
    y = np.array(y_list)
    return X, y, feature_names


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python pilot_oee_rf.py EXPORT_DIR", file=sys.stderr)
        sys.exit(1)
    root = Path(sys.argv[1])
    X, y, names = build_xy(root)
    if X is None:
        print("Dados insuficientes (telemetria/OEE vazios ou poucas amostras).")
        sys.exit(0)
    n = len(y)
    split = int(n * 0.8)
    if split < 2 or n - split < 1:
        print("Poucos pontos para split temporal.")
        sys.exit(0)
    X_train, X_test = X[:split], X[split:]
    y_train, y_test = y[:split], y[split:]
    model = RandomForestRegressor(
        n_estimators=80, max_depth=8, random_state=42, n_jobs=-1
    )
    model.fit(X_train, y_train)
    pred = model.predict(X_test)
    mae = mean_absolute_error(y_test, pred)
    r2 = r2_score(y_test, pred)
    print(f"Samples total={n} train={split} test={n - split}")
    print(f"Test MAE={mae:.4f} R2={r2:.4f}")
    imp = model.feature_importances_
    order = np.argsort(imp)[::-1][:12]
    print("Top feature importances:")
    for i in order:
        label = names[i] if i < len(names) else f"feat_{i}"
        print(f"  {label}: {imp[i]:.4f}")


if __name__ == "__main__":
    main()
