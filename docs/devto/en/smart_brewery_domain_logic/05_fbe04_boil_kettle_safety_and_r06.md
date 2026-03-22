---
title: "Smart Brewery domain: boil — foam, steam, and the kettle’s temper"
published: false
description: "Part 5 of 10 — The kettle rolls; foam climbs the sight glass; steam pressure taps the gauge. R_06 is the twin’s safety voice—NR-13 names the real world, the repo stays a fable with numbers."
tags: brewing, boil, safety, nr13, elixir
series: smart-brewery-domain
---

# Boil — foam, steam, and the kettle’s temper

**Part 5 of 10** — [Part 4](04_fbe03_lauter_filtration_physics_and_r01.md) · [Series index](README.md)

## The hook (scene)

By the time wort hits the kettle, the brewhouse sounds like a **sea**. Batch #47 boils for reasons both poetic and blunt: **isomerization**, **stripping**, **sanitation**. Mara trusts the **foam** to stay a hands-width below panic, trusts the **steam pressure** needle to live in green, trusts the **hop doser** not to argue with a kettle that is already furious. Then one of those trusts wobbles—the foam trend steepens, or the pressure trace bumps, or temperature and doser state disagree.

The twin does not feel heat; it reads facts. The **story** still needs the reader to smell steam.

## What the floor demands

Real kettles sit inside **regulatory and mechanical reality**: relief paths, interlocks, operator training, and—in Brazil—**NR-13** framing for pressure equipment culture. The floor demands: **never let novelty outrun relief**. Our twin cannot replace a safety valve; it can **teach** how reactive rules express “back off” logic.

## What the twin does — R_06, `RegraSegurancaCaldeira`

When foam spikes, or steam pressure crosses the twin’s limit, or boil temperature is extreme while the hop doser is not idle, the rule **pauses the doser** and **reduces steam pressure**—a stand-in for coordinated operator + basic automation response.

*Drafting note:* paste `defrule(RegraSegurancaCaldeira, …)` from [`smart_brewery_regras.ex`](../../../../lib/tec0301_pon/examples/smart_brewery_regras.ex).

## Evidence locker (twin sheet)

### Facts (FBE_04)

| Fact | Role |
|------|------|
| `fbe_04_boil_temp` | °C |
| `fbe_04_steam_pressure` | bar |
| `fbe_04_evaporation_rate` | % proxy |
| `fbe_04_hop_doser_state` | atom — coordination |
| `fbe_04_foam_level` | % — visual crisis proxy |

### Rule

- **R_06** — `RegraSegurancaCaldeira`; `RegraNotifier.notify(:r_06)`.

### NR-13 and disclaimer (required paragraph in published post)

**NR-13** applies to real boilers and pressure vessels under Brazilian regulation. The Smart Brewery simulation is **illustrative software**. No PSSR narrative, no hydrotest story—name NR-13 to honour **why** operators train, then separate **twin parameters** from **legal limits**.

### Twin parameters

Foam **85%**, steam **4 bar**, boil **103 °C** in code are **plot points** for the lab graph.

## Further reading

- Official **NR-13** text (gov.br) — for readers who need compliance paths.
- Lewis & Young — boiling, foam, hop addition practice.
- [`DOMAIN_BIBLIOGRAPHY.md`](DOMAIN_BIBLIOGRAPHY.md).

## Next

**Part 6** — [Cooling coupling: wort meets glycol](06_fbe05_heat_exchanger_coupling_and_r07_r10.md)
