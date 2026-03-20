#!/usr/bin/env python3
"""
Previsão multivariada (artigo 16): ICFT (few-shot por similaridade) + Chronos opcional.

1. **ICFT (In-Context Fine-Tuning sem backprop)**: normaliza janelas, busca os k vizinhos
   mais similares (MSE no prefixo) no treino e média dos sufixos como previsão.
2. **Chronos (opcional)**: se `chronos-forecasting` estiver instalado, usa
   `ChronosPipeline` (amazon/chronos-t5-tiny) em CPU para um alvo univariado.

Dados: `telemetry_events.csv` ou CAGG `telemetry_events_1min.csv` (preferir 1min para volume).

Usage:
  python pilot_tsfm_forecast.py /tmp/ml_export --fact fbe_06_internal_temp --horizon 6
  python pilot_tsfm_forecast.py /tmp/ml_export --use-chronos --fact fbe_04_steam_pressure
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd

from validation import time_ordered_indices


def load_series_1min(root: Path, fact: str) -> pd.Series | None:
    p = root / "telemetry_events_1min.csv"
    if not p.exists():
        p = root / "telemetry_events.csv"
        if not p.exists():
            return None
        df = pd.read_csv(p, parse_dates=["ts"])
        df = df[df["fact_name"] == fact]
        if df.empty or "value_float" not in df.columns:
            return None
        s = df.set_index("ts")["value_float"].sort_index().resample("1min").mean()
        return s.dropna()
    df = pd.read_csv(p, parse_dates=["bucket"])
    df = df[df["fact_name"] == fact]
    if df.empty:
        return None
    s = df.set_index("bucket")["value_float_avg"].sort_index()
    return s.dropna()


def icft_forecast(
    series: np.ndarray,
    *,
    context_len: int,
    horizon: int,
    k: int,
) -> tuple[np.ndarray, dict]:
    """Few-shot por vizinhos no conjunto de prefixos históricos (treino)."""
    n = len(series)
    if n < context_len + horizon + k:
        raise ValueError("série curta para ICFT")
    # janelas [t : t+context], alvo médio do próximo trecho (ou primeiro ponto)
    Xw, yw = [], []
    for t in range(0, n - context_len - horizon + 1):
        ctx = series[t : t + context_len]
        tgt = series[t + context_len : t + context_len + horizon]
        Xw.append(ctx)
        yw.append(tgt)
    Xw = np.stack(Xw)
    yw = np.stack(yw)
    tr, te = time_ordered_indices(len(Xw), train_ratio=0.85)
    X_tr, y_tr = Xw[tr], yw[tr]
    X_te = Xw[te]
    # normalizar por janela
    def norm(x):
        m = np.mean(x)
        s = np.std(x) + 1e-9
        return (x - m) / s, m, s

    preds = []
    for x in X_te:
        xn, xm, xs = norm(x)
        dists = []
        for i in range(len(X_tr)):
            zn, _, _ = norm(X_tr[i])
            dists.append(np.mean((xn - zn) ** 2))
        dists = np.array(dists)
        idx = np.argsort(dists)[:k]
        pred = np.mean(y_tr[idx], axis=0)
        preds.append(pred)
    pred = np.stack(preds)
    y_true = yw[te]
    mae = float(np.mean(np.abs(pred - y_true)))
    return pred, {"icft_mae_holdout": mae, "n_test_windows": len(te)}


def chronos_forecast_univariate(
    series: np.ndarray, horizon: int
) -> tuple[np.ndarray | None, dict | None]:
    try:
        import torch
        from chronos import ChronosPipeline
    except ImportError:
        return None, None
    try:
        pipeline = ChronosPipeline.from_pretrained(
            "amazon/chronos-t5-tiny",
            device_map="cpu",
            torch_dtype=torch.float32,
        )
        context = torch.tensor(series[-512:], dtype=torch.float32)
        if context.numel() < 8:
            return None, None
        forecast = pipeline.predict(context, prediction_length=horizon, num_samples=20)
        arr = forecast.numpy() if hasattr(forecast, "numpy") else np.asarray(forecast)
        # (num_samples, horizon) ou (batch, num_samples, horizon)
        if arr.ndim == 3:
            arr = arr[0]
        q = np.quantile(arr, 0.5, axis=0)
        return q, {"chronos": "amazon/chronos-t5-tiny"}
    except Exception:
        return None, None


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("export_dir", type=Path)
    ap.add_argument("--fact", type=str, default="fbe_06_internal_temp")
    ap.add_argument("--horizon", type=int, default=6)
    ap.add_argument("--context-len", type=int, default=48)
    ap.add_argument("--k", type=int, default=5, help="vizinhos ICFT")
    ap.add_argument("--use-chronos", action="store_true")
    ap.add_argument("--out-json", type=Path, default=None)
    args = ap.parse_args()

    s = load_series_1min(args.export_dir, args.fact)
    if s is None or len(s) < args.context_len + args.horizon + 20:
        print(
            f"Série ausente ou curta para {args.fact}. Verifique export e fact_name.",
            file=sys.stderr,
        )
        sys.exit(1)

    arr = s.values.astype(np.float64)
    out: dict = {"fact": args.fact, "n_points": len(arr)}

    try:
        _, icft_metrics = icft_forecast(
            arr,
            context_len=args.context_len,
            horizon=args.horizon,
            k=args.k,
        )
        out["icft"] = icft_metrics
    except Exception as e:
        out["icft"] = {"error": repr(e)}

    if args.use_chronos:
        fc, meta = chronos_forecast_univariate(arr, args.horizon)
        if fc is None:
            out["chronos"] = {
                "skipped": "install chronos-forecasting + torch ou série curta"
            }
        else:
            out["chronos"] = {**meta, "point_forecast": fc.tolist()}

    print(json.dumps(out, indent=2))
    if args.out_json:
        args.out_json.write_text(json.dumps(out, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
