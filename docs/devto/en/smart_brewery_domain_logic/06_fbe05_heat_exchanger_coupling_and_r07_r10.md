---
title: "Smart Brewery domain: cooling coupling — wort meets glycol"
published: false
description: "Part 6 of 10 — Hot wort must land cool enough to pitch; Mara watches in and out temperatures diverge. R_07 opens cooling; R_10 refuses a boil without a path for heat to leave."
tags: brewing, heatexchanger, thermal, interlocks, elixir
series: smart-brewery-domain
---

# Cooling coupling — wort meets glycol

**Part 6 of 10** — [Part 5](05_fbe04_boil_kettle_safety_and_r06.md) · [Series index](README.md)

## The hook (scene)

After the kettle’s drama, the brewhouse exhales into **metal plates** and **cold water or glycol** on the other side. Batch #47’s wort still “wants” to be hot; the cellar downstream wants it **polite**. Mara traces two temperatures: **in** and **out**. When the gap stops making sense—hot in, still-too-hot out—the valve position for glycol becomes the quiet protagonist. Somewhere else on the graph, the kettle still says **boiling**, and the exchanger cannot pretend the cooling path is closed.

## What the floor demands

Heat exchangers punish **sequence mistakes**: boiling wort with **no cooling arm** is how legends are born—in the bad way. The floor demands **optimization** when the approach is lazy (open cooling) and **interlocks** when the process tries to cheat physics.

## What the twin does — R_07 and R_10

**R_07 — `RegraOtimizacaoTrocador`** — When outlet wort is still warm while inlet is hot and the glycol valve is not already maxed, the twin **increases glycol valve opening**—more cold side, more apology to the yeast later.

**R_10 — `RegraIntertravamentoFervuraTrocador`** — When boil temperature is high and glycol valve reads **closed**, the twin forces the valve to move—**the story’s way of saying** “you do not boil without a place for heat to go.”

*Drafting note:* paste both `defrule` blocks from [`smart_brewery_regras.ex`](../../../../lib/tec0301_pon/examples/smart_brewery_regras.ex).

## Evidence locker (twin sheet)

### Facts (FBE_05)

| Fact | Role |
|------|------|
| `fbe_05_wort_in_temp` | °C |
| `fbe_05_wort_out_temp` | °C |
| `fbe_05_glycol_valve_pos` | % open |
| `fbe_05_water_pressure` | bar |

### Rules

- **R_07** — optimization.
- **R_10** — boil–exchanger **interlock**.

### Narrative diagram (when drafting)

Small sequence: **FBE_04 → FBE_05 → FBE_06** on the wort path—one mermaid or ASCII arrow in the published post.

### Twin parameters

Thresholds on temperatures and valve % are **simulation choices**; fouling, approach ΔT, and real hydraulic limits are out of scope unless you extend the model.

## Further reading

- Briggs et al. — heat exchange, wort handling.
- Perry’s Handbook (HX fundamentals) — optional depth.
- [`DOMAIN_BIBLIOGRAPHY.md`](DOMAIN_BIBLIOGRAPHY.md).

## Next

**Part 7** — [Fermentation holds and the grid knocks](07_fbe06_fbe07_fermentation_phases_and_grid_coupling.md)
