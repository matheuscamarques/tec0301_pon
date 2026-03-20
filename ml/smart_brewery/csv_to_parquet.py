#!/usr/bin/env python3
"""
Converte CSVs do export ML para Parquet (Polars).
Uso:
  python csv_to_parquet.py /tmp/ml_export /tmp/ml_parquet
"""
from __future__ import annotations

import sys
from pathlib import Path

import polars as pl


def main() -> None:
    if len(sys.argv) < 3:
        print("Usage: python csv_to_parquet.py EXPORT_DIR OUT_DIR", file=sys.stderr)
        sys.exit(1)
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    dst.mkdir(parents=True, exist_ok=True)
    for p in src.glob("*.csv"):
        df = pl.read_csv(p, try_parse_dates=True)
        out = dst / (p.stem + ".parquet")
        df.write_parquet(out)
        print(f"Wrote {out}")


if __name__ == "__main__":
    main()
