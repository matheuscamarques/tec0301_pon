---
title: "Smart Brewery domain: control-room debrief — OEE, anomalies, traces, ML"
published: false
description: "Part 10 of 10 — End of Batch #47’s story arc: the board sums the day in OEE, EMA whispers drift, rule_events read like a diary—then export.ml and the pilots wait backstage."
tags: brewing, oee, anomalydetection, processmining, machinelearning, elixir
series: smart-brewery-domain
---

# Control-room debrief — OEE, anomalies, traces, ML

**Part 10 of 10** — [Part 9](09_fbe09_cip_conductivity_and_process_hygiene.md) · [Series index](README.md)

## The hook (scene)

The brewhouse noise thins. Mara stays long enough for the **shift handover** screen: not romance—**OEE** as a single cruel bar, **anomaly** tiles that glowed once during the mill episode, a **rule log** that reads like a staccato diary (`r_04`, `r_01`, `r_06`…). Batch #47 is no longer “in progress”; it is **data**.

The twin’s epilogue is not silence—it is **aggregation**: what happened, how hard, how weird, in what order.

## What the floor demands

Operations asks: **did we win the day** (OEE), **what drifted** (anomalies), **what decisions fired** (rules in sequence). Engineering asks: **can we train on this** without lying about time—hence **walk-forward splits** and honest table joins. The floor demands both **human closure** and **machine-readable honesty**.

## What the twin does — OEE, EMA, `rule_events`, export

**OEE — `SimulacoesVisuais.SmartBrewery.OEE`** — Default mode derives **Availability × Performance × Quality** from **facts** (mill, filter, packaging proxies in @moduledoc). Optional **Nakajima** mode uses planned shift and cycle-time language—tell that as “the board can speak TPM if you configure it.”

**EMA anomalies — `SmartBrewery.EMA`** — Moving average and sigma bands; PubSub `smart_brewery:anomalias` and `anomaly_events` for TSDB—narrate as “the twin noticed the sensor’s personality change.”

**Process trace — `rule_events` + `CaseContext`** — UUID **case_id** per session groups the day’s rule fires for **PM4Py / XES**—the story’s **director’s cut**.

**ML bridge** — `mix export.ml`, pilots in Elixir and Python; **PON Part 9** remains the stack authority—here, end with “Batch #47’s rows are waiting in CSV.”

*Drafting note:* paste short excerpts from `oee.ex` @moduledoc and one `{:anomalia, ...}` shape; link [`ml-smart-brewery-data.md`](../../../ml-smart-brewery-data.md).

## Evidence locker (twin sheet)

### Modules / tables

| Concern | Repo anchor |
|---------|-------------|
| OEE | `apps/.../smart_brewery/oee.ex` |
| EMA | `apps/.../smart_brewery/ema.ex` |
| Anomaly persistence | `anomaly_event_writer.ex` (if cited in ML doc) |
| Case id | `case_context.ex` |
| Export | `MLDatasetExport`, `mix export.ml` |

### Citations

- **Nakajima** / TPM — OEE lineage.
- **van der Aalst** / **PM4Py** — process mining with `rule_events`.
- **Breck et al.** — ML production readiness (optional closing note).

### Twin parameters

Throttle intervals, EMA windows, OEE Nakajima flags—**config**, not destiny.

## Further reading — closing the bookshelf

- Nakajima; PM4Py docs; Breck et al. ML Test Score.
- [`BIBLIOGRAPHY_PON_SERIES.md`](../BIBLIOGRAPHY_PON_SERIES.md).
- [`DOMAIN_BIBLIOGRAPHY.md`](DOMAIN_BIBLIOGRAPHY.md).

## End of series

- Rewind: [Part 1 — why this twin maps a line](01_why_this_twin_maps_a_brewery_line.md).
- Architecture twin: [PON Part 5 on dev.to](https://dev.to/matheuscamarques/smart-brewery-a-digital-twin-brewery-as-a-pon-lab-36mf).
