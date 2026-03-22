---
title: "Smart Brewery domain: fermentation holds — and the grid knocks"
published: false
description: "Part 7 of 10 — Two fermenters breathe CO₂; glycol jackets hum; Batch #47 waits. Then power cost spikes—R_03 and R_08 ask fermentation to yield a little cold for the bill."
tags: brewing, fermentation, energy, demandresponse, elixir
series: smart-brewery-domain
---

# Fermentation holds — and the grid knocks

**Part 7 of 10** — [Part 6](06_fbe05_heat_exchanger_coupling_and_r07_r10.md) · [Series index](README.md)

## The hook (scene)

Fermentation is the part of the story where **time becomes a character**. Batch #47 sits in **Fermenter A**—internal temperature steady enough that Mara stops staring. Fermenter B runs its own subplot: same yeast family, different thermal personality. The phases (`:lag`, and friends in the twin) are shorthand for “biology doing bookkeeping.”

Then the **grid** tile changes mood: **power cost** climbs past the twin’s “expensive afternoon” threshold. Somewhere, CIP is **on**—auxiliary load already gossiping on the bus. The story is no longer only about beer; it is about **sharing inconvenience** across units without fantasy physics.

## What the floor demands

Real cellars negotiate **refrigeration capacity** with **utility prices** and **demand response** programs. Our twin uses a **parable**: if Fermenter A (or B) has thermal headroom *and* the grid is “expensive” *and* CIP is running, **pause glycol chilling** on that tank and **discharge a V2G-style buffer**—teaching names for peak-shaving, not a signed utility contract.

## What the twin does — R_03 and R_08

**R_03 — `RegraSmartGridLoadBalancing`** — Watches **FBE_06** temperature, **FBE_09** CIP pump, **FBE_11** grid cost; acts on **FBE_06** glycol and **FBE_11** buffer.

**R_08 — `RegraLoadBalancingFermentadorB`** — Parallel story for **FBE_07** and the same grid vocabulary—symmetry for tests and for the narrative of **two assets, one bill**.

*Drafting note:* paste both `defrule` blocks; mention `FBE11SmartGrid` simulation module for readers who open the code.

## Evidence locker (twin sheet)

### Facts (FBE_06 / FBE_07)

- Temperature, pressure, Brix/gravity, glycol jacket state, CO₂ exhaust, **ferm_phase** atoms; pH on A.

### Grid (FBE_11)

- `fbe_11_grid_power_cost`, `fbe_11_v2g_battery_lvl`, `fbe_11_main_load_draw`, `fbe_11_grid_fault_detec` — see catalog.

### Simulation modules

- `FBE06Fermentation`, `FBE07Fermentation`, `FBE11SmartGrid`.

### Citations in prose

- Brewing texts for fermentation kinetics; **Siano (2014)** or similar for demand-response vocabulary; disclaim **V2G** numbers as **not utility-grade**.

### Twin parameters

Cost threshold **150**, temperature **19 °C**, V2G **20%** — lab knobs for narrative tension.

## Further reading

- Lewis & Young — fermentation.
- Siano — demand response survey.
- [`ml/smart_brewery/README.md`](../../../../ml/smart_brewery/README.md) — DRL / grid safety note.
- [`DOMAIN_BIBLIOGRAPHY.md`](DOMAIN_BIBLIOGRAPHY.md).

## Next

**Part 8** — [Line speed and the robot in the way](08_fbe08_packaging_line_interlocks_and_fbe10_amr.md)
