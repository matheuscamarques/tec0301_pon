#!/usr/bin/env python3
"""
Próxima regra PON (artigo 16 — baseline antes de DAW-Transformer): cadeia de Markov de 1ª ordem
sobre `regra_id` em `rule_events.csv`, com avaliação hold-out temporal.

Uso: python pilot_next_rule_baseline.py /tmp/ml_export
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

import pandas as pd

from validation import time_ordered_indices


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("export_dir", type=Path)
    ap.add_argument("--metrics-out", type=Path, default=None)
    args = ap.parse_args()

    path = args.export_dir / "rule_events.csv"
    if not path.exists():
        print("rule_events.csv não encontrado.", file=sys.stderr)
        sys.exit(1)

    df = pd.read_csv(path, parse_dates=["ts"]).sort_values("ts")
    if df.empty or "regra_id" not in df.columns:
        print("rule_events vazio ou sem regra_id.", file=sys.stderr)
        sys.exit(0)

    seq = df["regra_id"].astype(str).tolist()
    n = len(seq)
    if n < 20:
        print("Poucos eventos de regra.")
        sys.exit(0)

    pairs = list(zip(seq[:-1], seq[1:]))
    tr_idx, te_idx = time_ordered_indices(len(pairs), train_ratio=0.8)
    tr_pairs = [pairs[i] for i in tr_idx]
    te_pairs = [pairs[i] for i in te_idx]

    counts = defaultdict(Counter)
    for a, b in tr_pairs:
        counts[a][b] += 1

    correct = 0
    for a, b_true in te_pairs:
        nx = counts.get(a)
        if not nx:
            pred = None
        else:
            pred = nx.most_common(1)[0][0]
        if pred == b_true:
            correct += 1

    acc = correct / len(te_pairs) if te_pairs else 0.0
    out = {
        "model": "markov_order1",
        "holdout_accuracy": acc,
        "n_pairs_test": len(te_pairs),
        "n_states_seen": len(counts),
    }
    print(json.dumps(out, indent=2))
    if args.metrics_out:
        args.metrics_out.write_text(json.dumps(out, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
