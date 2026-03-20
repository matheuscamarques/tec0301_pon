#!/usr/bin/env python3
"""
Híbrido OEE (artigo 16): variáveis exógenas derivadas de forma da série + SARIMAX.

- **Baseline geométrica leve**: janelas deslizantes → desvio-padrão e amplitude
  (proxy de complexidade temporal; homologia persistente completa exigiria Giotto-TDA).

Requer: `pip install statsmodels` (já em requirements.txt principal).
Uso: python pilot_oee_tda_sarimax.py /tmp/ml_export

Se a série for curta, o script pode falhar — aumente `--since-hours` no export.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from statsmodels.tsa.statespace.sarimax import SARIMAX

from validation import time_ordered_indices


def _rolling_features(series: pd.Series, window: int) -> pd.DataFrame:
    s = series.astype(float)
    return pd.DataFrame(
        {
            "roll_std": s.rolling(window, min_periods=max(2, window // 2)).std(),
            "roll_amp": s.rolling(window, min_periods=max(2, window // 2)).apply(
                lambda x: float(np.max(x) - np.min(x)), raw=True
            ),
        },
        index=s.index,
    )


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("export_dir", type=Path)
    ap.add_argument("--window", type=int, default=12)
    ap.add_argument("--order", type=str, default="1,1,1", help="SARIMAX order p,d,q")
    ap.add_argument("--seasonal", type=str, default="0,0,0,0", help="seasonal P,D,Q,s")
    ap.add_argument("--metrics-out", type=Path, default=None)
    args = ap.parse_args()

    oee_path = args.export_dir / "oee_snapshots.csv"
    if not oee_path.exists():
        print("oee_snapshots.csv não encontrado.", file=sys.stderr)
        sys.exit(1)

    oee = pd.read_csv(oee_path, parse_dates=["ts"]).sort_values("ts")
    oee = oee.dropna(subset=["oee_pct"])
    if len(oee) < 40:
        print("Série OEE muito curta para SARIMAX estável.", file=sys.stderr)
        sys.exit(1)

    y = oee["oee_pct"].astype(float).values
    idx = pd.RangeIndex(len(y))
    exog = (
        _rolling_features(pd.Series(y), args.window)
        .reindex(idx)
        .bfill()
        .fillna(0.0)
    )

    exog_m = exog.values.astype(float)
    p, d, q = (int(x) for x in args.order.split(","))
    P, D, Q, s = (int(x) for x in args.seasonal.split(","))

    tr_idx, te_idx = time_ordered_indices(len(y), train_ratio=0.75)
    y_tr, y_te = y[tr_idx], y[te_idx]
    ex_tr, ex_te = exog_m[tr_idx], exog_m[te_idx]

    try:
        model = SARIMAX(
            y_tr,
            exog=ex_tr,
            order=(p, d, q),
            seasonal_order=(P, D, Q, s),
            enforce_stationarity=False,
            enforce_invertibility=False,
        )
        fit = model.fit(disp=False)
        fc = fit.get_forecast(steps=len(te_idx), exog=ex_te)
        pred = fc.predicted_mean
    except Exception as e:
        print(f"SARIMAX fit failed: {e!r}", file=sys.stderr)
        sys.exit(1)

    mae = float(np.mean(np.abs(y_te - pred)))
    rmse = float(np.sqrt(np.mean((y_te - pred) ** 2)))
    out = {
        "model": "sarimax_exog_rolling",
        "mae": mae,
        "rmse": rmse,
        "n_train": int(len(tr_idx)),
        "n_test": int(len(te_idx)),
    }
    print(json.dumps(out, indent=2))
    if args.metrics_out:
        args.metrics_out.write_text(json.dumps(out, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
