#!/usr/bin/env python3
"""
Process mining (artigo 15 / 16): event log a partir de rule_events.csv.
- Usa `case_id` quando preenchido (sessão LiveView / Monte Carlo).
- Caso contrário, segmenta casos por lacuna temporal > 30 min.
- Com `--xes-out caminho.xes` exporta log no formato XES (PM4Py).

Requer: pip install pm4py pandas

Usage:
  python process_mining_pm4py.py /tmp/ml_export
  python process_mining_pm4py.py /tmp/ml_export --xes-out /tmp/rules.xes
"""
from __future__ import annotations

import sys
from pathlib import Path

import argparse

import pandas as pd


def assign_cases_by_gap(df: pd.DataFrame, gap_minutes: float = 30.0) -> pd.Series:
    df = df.sort_values("ts")
    ts = pd.to_datetime(df["ts"])
    gap = ts.diff() > pd.Timedelta(minutes=gap_minutes)
    case_counter = gap.cumsum()
    return case_counter.astype(str).radd("case_")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("export_dir", type=Path)
    ap.add_argument("--xes-out", type=Path, default=None)
    args = ap.parse_args()
    path = args.export_dir / "rule_events.csv"
    if not path.exists():
        print("rule_events.csv não encontrado — rode mix export.ml primeiro.")
        sys.exit(0)
    df = pd.read_csv(path, parse_dates=["ts"])
    if df.empty:
        print("rule_events vazio.")
        sys.exit(0)
    if "case_id" in df.columns and df["case_id"].notna().any():
        case_col = df["case_id"].astype(str)
    else:
        case_col = assign_cases_by_gap(df)
    df = df.assign(**{"case:concept:name": case_col})
    df["concept:name"] = df["regra_id"].astype(str)
    df["time:timestamp"] = pd.to_datetime(df["ts"])

    try:
        import pm4py
        from pm4py.algo.discovery.heuristics import algorithm as heuristics_miner
        from pm4py.objects.conversion.log import converter as log_converter
    except ImportError:
        print("pm4py não instalado — pip install pm4py")
        sys.exit(0)

    df_pm = df[["case:concept:name", "concept:name", "time:timestamp"]]
    try:
        df_pm = pm4py.format_dataframe(df_pm)
        log = log_converter.apply(df_pm)
        if args.xes_out:
            pm4py.write_xes(log, str(args.xes_out))
            print(f"XES written to {args.xes_out}")
        net, im, fm = heuristics_miner.apply(log)
        print(f"Places: {len(net.places)} Transitions: {len(net.transitions)}")
        print("Heuristic net discovered (Petri net). Use pm4py vis se disponível para visualizar.")
    except Exception as e:
        print(f"PM4Py discovery failed ({e!r}). Verifique versão pm4py e colunas do event log.")
        print(df_pm.head().to_string())


if __name__ == "__main__":
    main()
