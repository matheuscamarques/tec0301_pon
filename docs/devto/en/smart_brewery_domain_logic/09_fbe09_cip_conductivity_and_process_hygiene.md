---
title: "Smart Brewery domain: interlude — while the tun sleeps (CIP)"
published: false
description: "Part 9 of 10 — Fermentation holds; the brewhouse washes. Return conductivity tells a silent story. R_03 already knew CIP was on—here we honour the loop itself."
tags: brewing, cip, hygiene, cleaning, elixir
series: smart-brewery-domain
---

# Interlude — while the tun sleeps (CIP)

**Part 9 of 10** — [Part 8](08_fbe08_packaging_line_interlocks_and_fbe10_amr.md) · [Series index](README.md)

## The hook (scene) — narrative time slip, on purpose

Parts 2–8 marched with **wort and beer**. Now we **widen the clock**: while Fermenter A keeps its slow promise, the **CIP skid** runs acid and caustic dreams through pipes that Batch #47 already touched. Mara is either on a second lap of the shift or the story simply admits that **cleaning is not a side quest**—it is the reason the next batch is allowed to exist.

This interlude avoids pretending the plant is linear; it says: **hygiene has its own plot**.

## What the floor demands

CIP ends when **conductivity**, **time**, and **visual/turbidity checks** agree the line is honest again. The floor demands: **do not fake validation**—the twin exposes tank levels, return conductivity, pump state, and flow velocity as **scalar truth**, not ATP swabs.

## What the twin does — honouring FBE_09 and R_03’s prelude

**FBE_09** facts drive the **hygiene tableau**: caustic and acid tank levels, **return conductivity** (µS/cm as a story-friendly “how much chemistry is still in the water”), **CIP pump** on/off, **flow velocity**.

**R_03** (`RegraSmartGridLoadBalancing`) already used **CIP pump on** as part of its condition—back in Part 7’s narrative, that was “aux load gossip.” In **this** chapter, revisit that choice: the same fact means **we are washing**, which changes how aggressive the twin can be about **shedding chiller work** when power is expensive.

*Drafting note:* quote `defrule(RegraSmartGridLoadBalancing, …)` **selectively** (watch list includes `fbe_09_cip_pump_state`) or cross-link Part 7 instead of repeating the full rule—your call for pacing.

## Evidence locker (twin sheet)

### Facts (FBE_09)

| Fact | Role |
|------|------|
| `fbe_09_caustic_tank_lvl` | % |
| `fbe_09_acid_tank_lvl` | % |
| `fbe_09_return_conduct` | µS/cm — endpoint proxy |
| `fbe_09_cip_pump_state` | atom |
| `fbe_09_flow_velocity` | m/s |

### Rules touching CIP

- **R_03** — grid / fermentation balancing; **CIP on** as precondition in twin logic.

### No food-safety certification claim

State clearly: no **HACCP** narrative, no validated CIP recipe—EHEDG / 3-A are **reading lists** for engineers who ship real plants.

## Further reading — beyond the interlude

- EHEDG guidelines; Timperley-style CIP chapters; 3-A sanitary standards.
- [`DOMAIN_BIBLIOGRAPHY.md`](DOMAIN_BIBLIOGRAPHY.md).

## Next

**Part 10** — [Control-room debrief: OEE, anomalies, traces, ML](10_cross_cutting_oee_anomalies_rule_sequences_and_ml.md)
