#!/usr/bin/env python3
"""
Piloto: Isolation Forest em fatos FBE_01 (moinho) multivariados.
Opcionalmente cruza com anomaly_events para ver sobreposição de alertas.

Usage: python pilot_anomaly_iforest.py /tmp/ml_export
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python pilot_anomaly_iforest.py EXPORT_DIR", file=sys.stderr)
        sys.exit(1)
    root = Path(sys.argv[1])
    tel = pd.read_csv(root / "telemetry_events.csv", parse_dates=["ts"])
    if tel.empty:
        print("telemetry_events vazio.")
        sys.exit(0)
    sub = tel[tel["fact_name"].str.startswith("fbe_01_", na=False)].copy()
    sub = sub[sub["value_float"].notna()]
    if sub.empty:
        print("Sem floats em fbe_01_* — preencha simulação/telemetria.")
        sys.exit(0)
    wide = sub.pivot_table(
        index="ts", columns="fact_name", values="value_float", aggfunc="mean"
    )
    wide = wide.sort_index().ffill().dropna()
    if len(wide) < 20:
        print(f"Poucas linhas após pivot ({len(wide)}), precisa >= 20.")
        sys.exit(0)
    X = wide.values.astype(np.float64)
    iso = IsolationForest(random_state=42, contamination="auto", n_estimators=100)
    pred = iso.fit_predict(X)
    # -1 = anomalia no sklearn
    scores = pred == -1
    n_anom = int(scores.sum())
    print(f"Rows={len(wide)} isolation_anomalies={n_anom} ({100 * n_anom / len(wide):.1f}%)")
    print("(Opcional) cruze com anomaly_events.csv em notebook — alinhar timestamps por minuto.")


if __name__ == "__main__":
    main()
