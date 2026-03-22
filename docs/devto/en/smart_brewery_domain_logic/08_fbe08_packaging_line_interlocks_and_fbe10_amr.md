---
title: "Smart Brewery domain: line speed — and the robot in the way"
published: false
description: "Part 8 of 10 — Bottles claim the conveyor; a capper jams; an AMR blinks low battery in motion. R_02 halts the line; R_11 sends the robot home to charge."
tags: brewing, packaging, amr, safety, elixir
series: smart-brewery-domain
---

# Line speed — and the robot in the way

**Part 8 of 10** — [Part 7](07_fbe06_fbe07_fermentation_phases_and_grid_coupling.md) · [Series index](README.md)

## The hook (scene)

Packaging is where the brewhouse’s patience becomes **geometry**. Batch #47—now beer—meets **IR sensors**, **fill heads**, and a **capper** that either runs boring or becomes folklore. Mara’s eyes jump between **liquid level detect** and **conveyor speed**; the HMI does not show the AMR until it **almost** matters—then **collision alert** paints the tile red.

The twin’s story here is **human-scale**: stop the line before bad bottles become a pile; send the robot to charge before it dies in the aisle.

## What the floor demands

Interlocks exist because **injury and scrap** scale with speed. The floor demands: **jam → stop**; **bad fill → stop**; **robot conflict → stop + reroute**. Battery management is the slower drumbeat: **do not run flat** while pretending you are still productive.

## What the twin does — R_02 and R_11

**R_02 — `RegraIntertravamentoEnvase`** — Capper jam **or** liquid level fail **or** collision alert → **emergency halt conveyor** on the line and **recalculate route avoidance** on the AMR side (twin metaphors for coordinated safety PLC + fleet logic).

**R_11 — `RegraGestaoBateriaAMR`** — Battery low while robot status is not idle → **request charge station return**—policy as code, narrated as “Mara sees the twin whisper: go home.”

*Drafting note:* paste both `defrule` blocks from [`smart_brewery_regras.ex`](../../../../lib/tec0301_pon/examples/smart_brewery_regras.ex).

## Evidence locker (twin sheet)

### Facts (FBE_08)

- IR bottle detect, conveyor speed, fill head, liquid level detect, capper jam, stop sensor — see [`smart-brewery-fatos-regras.md`](../../../smart-brewery-fatos-regras.md).

### Facts (FBE_10)

- Battery %, location tuple, status atom, collision alert, payload — note **tuple** serialization caveat for TSDB in catalog.

### Markov flavour

- `FBE08Markov`, `FBE10Markov` — discrete **states** vs continuous physics elsewhere; one paragraph on “stochastic line moods” for engaged readers.

### Rules

- **R_02**, **R_11** — notify `:r_02`, `:r_11`.

### Twin parameters

Jam booleans and battery **20%** threshold are **story knobs**.

## Further reading

- ISO 3691 family — high-level industrial truck / AMR safety framing.
- Packaging machinery safety standards (regional).
- [`DOMAIN_BIBLIOGRAPHY.md`](DOMAIN_BIBLIOGRAPHY.md).

## Next

**Part 9** — [Interlude: while the tun sleeps — CIP](09_fbe09_cip_conductivity_and_process_hygiene.md)
