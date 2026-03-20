#!/usr/bin/env python3
"""
Baselines: LSTM leve para prever o próximo passo de variáveis contínuas do fermentador A
(fbe_06_internal_temp, fbe_06_gravity_brix, fbe_06_ph, fbe_06_co2_exhaust_flow, fbe_06_pressure).

Validação: hold-out temporal nos últimos 15% dos passos.

Usage: python pilot_fermentation_lstm.py /tmp/ml_export
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd
import torch
import torch.nn as nn


F6 = [
    "fbe_06_internal_temp",
    "fbe_06_gravity_brix",
    "fbe_06_ph",
    "fbe_06_co2_exhaust_flow",
    "fbe_06_pressure",
]


class LSTMReg(nn.Module):
    def __init__(self, n_feat: int, hidden: int = 32):
        super().__init__()
        self.lstm = nn.LSTM(n_feat, hidden, batch_first=True, num_layers=1)
        self.fc = nn.Linear(hidden, n_feat)

    def forward(self, x):
        y, _ = self.lstm(x)
        return self.fc(y[:, -1, :])


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python pilot_fermentation_lstm.py EXPORT_DIR", file=sys.stderr)
        sys.exit(1)
    root = Path(sys.argv[1])
    tel = pd.read_csv(root / "telemetry_events.csv", parse_dates=["ts"])
    rows = tel[tel["fact_name"].isin(F6) & tel["value_float"].notna()]
    if rows.empty:
        print("Sem dados fbe_06_* float — rode simulação com TSDB.")
        sys.exit(0)
    wide = rows.pivot_table(
        index="ts", columns="fact_name", values="value_float", aggfunc="mean"
    )
    for c in F6:
        if c not in wide.columns:
            wide[c] = np.nan
    wide = wide[F6].sort_index().ffill().dropna()
    if len(wide) < 64:
        print(f"Série curta ({len(wide)} rows), mínimo sugerido 64.")
        sys.exit(0)
    data = wide.values.astype(np.float32)
    mean = data.mean(axis=0, keepdims=True)
    std = data.std(axis=0, keepdims=True) + 1e-6
    data_n = (data - mean) / std

    seq_len = 12
    Xs, Ys = [], []
    for i in range(len(data_n) - seq_len):
        Xs.append(data_n[i : i + seq_len])
        Ys.append(data_n[i + seq_len])
    Xs = np.stack(Xs)
    Ys = np.stack(Ys)
    n = len(Xs)
    split = int(n * 0.85)
    if split < 4 or n - split < 2:
        print("Poucos exemplos para treino/teste.")
        sys.exit(0)
    Xt, Xv = Xs[:split], Xs[split:]
    yt, yv = Ys[:split], Ys[split:]

    device = torch.device("cpu")
    model = LSTMReg(len(F6)).to(device)
    opt = torch.optim.Adam(model.parameters(), lr=1e-2)
    loss_fn = nn.MSELoss()
    Xt_t = torch.tensor(Xt, device=device)
    yt_t = torch.tensor(yt, device=device)
    model.train()
    for epoch in range(120):
        opt.zero_grad()
        pred = model(Xt_t)
        loss = loss_fn(pred, yt_t)
        loss.backward()
        opt.step()
    model.eval()
    with torch.no_grad():
        pv = model(torch.tensor(Xv, device=device)).cpu().numpy()
    rmse = np.sqrt(np.mean((pv - yv) ** 2))
    print(f"Fermentador A next-step RMSE (normalized space): {rmse:.4f}")
    print(f"Train seq={split} test={len(Xv)} window={seq_len}")


if __name__ == "__main__":
    main()
