#!/usr/bin/env python3
"""
Carrega CSVs exportados por `mix export.ml` e imprime resumo (linhas, colunas, amostra).
Uso:
  python ingest.py /tmp/ml_export
"""
from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd


def load_export(dir_path: Path) -> dict[str, pd.DataFrame]:
    out: dict[str, pd.DataFrame] = {}
    for name in (
        "telemetry_events.csv",
        "oee_snapshots.csv",
        "anomaly_events.csv",
        "rule_events.csv",
        "telemetry_events_1min.csv",
        "dim_equipamento_fbe.csv",
        "dim_variaveis_mapeamento.csv",
    ):
        p = dir_path / name
        if not p.exists():
            continue
        out[name.removesuffix(".csv")] = pd.read_csv(p, low_memory=False)
    return out


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python ingest.py EXPORT_DIR", file=sys.stderr)
        sys.exit(1)
    d = Path(sys.argv[1])
    if not d.is_dir():
        print(f"Not a directory: {d}", file=sys.stderr)
        sys.exit(1)
    frames = load_export(d)
    if not frames:
        print("No known CSV files found.")
        sys.exit(0)
    for key, df in frames.items():
        print(f"\n=== {key} ===")
        print(f"rows={len(df)} cols={list(df.columns)}")
        print(df.head(2).to_string())


if __name__ == "__main__":
    main()
