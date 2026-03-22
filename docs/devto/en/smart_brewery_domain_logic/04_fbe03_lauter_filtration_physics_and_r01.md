---
title: "Smart Brewery domain: when the lauter bed fights back"
published: false
description: "Part 4 of 10 — Differential pressure climbs; clarity stalls; Mara eases the pump. R_01 optimizes the bed—R_09 reminds the tun and the filter who is boss."
tags: brewing, filtration, lauter, simulation, elixir
series: smart-brewery-domain
---

# When the lauter bed fights back

**Part 4 of 10** — [Part 3](03_fbe02_mash_tun_control_and_recipe_band.md) · [Series index](README.md)

## The hook (scene)

The lauter tun does not forgive vanity. Batch #47’s wort wants to leave; the **spent grain bed** wants to keep it—just a little longer, with **differential pressure** as the argument. Mara sees the pump speed creep because someone, maybe her past self, chased time. The clarity trace looks **tired**. The board’s ΔP number is no longer “background”; it is **the story’s villain** for the next five minutes. She hovers a finger over the **rake** control without clicking—operators learn that pride and rakes negotiate in millimetres, not heroics.

Meanwhile the mash tun still whispers in the data model: if temperature or level say “not ready,” the twin must not let the lauter side **bully** the upstream truth. That whisper is not mysticism; it is **R_09**, a sequencing interlock that zeros the lauter pump when mash conditions violate a simplified “ready” predicate. The scene’s tension is **two truths**: the filter wants flow; the mash says **not yet** or **not still**. Good brewhouses choreograph that argument with procedures; our brewhouse choreographs it with **atoms and guards**.

**Bridge from Part 3:** **R_05** kept the mash in band; now the narrative **spends** that band’s goodwill at the boundary between conversion and separation. Whatever the mash did not finish becomes **viscosity, particle packing, and fines** in the bed—physics the twin only partially models through simulation modules discussed below. Mara’s ears hear the pump; her eyes watch **clarity** because the story insists **quality** and **mechanical stress** share a timeline.

## What the floor demands

Filtration is a negotiation: **pressure**, **clarity**, **rake height**, **pump rate**. Push too hard and you compact the bed; hang back and you lose the brewhouse clock. The floor demands **two kinds of wisdom**: (1) when the bed is stressed, **back off mechanically**—drop pump speed, lower rake, breathe; (2) when upstream says the mash is not in range, **do not run the lauter pump as if it were** independent. Plants express (2) with **interlocks**, **procedural holds**, and sometimes bitter experience from stuck mashes.

Real wort separation texts talk about **permeability**, **compressible cakes**, **Darcy-type intuition**, and operator craft during **sparge**. Our twin names a few scalars and lets **R_01** optimise under stress while **R_09** enforces a mash–filter contract. Neither rule replaces a **lauter design engineer**; both teach **how reactive policies read on a board** when Batch #47 is fiction but the code is real.

If you ignore both wisdoms, you get **channeling**, **stuck runoff**, **turbid wort**, and **evening overtime**—the sort of shift story that becomes a brewery’s oral tradition. The twin cannot taste polyphenol harshness from bad runoff; it can still **force** pump speed to zero when mash truth is wrong, which is a blunt stand-in for “stop hurting the bed.”

## What the twin does — R_01 and R_09

**R_01 — `RegraOtimizacaoFiltracao`** — When ΔP is high *and* clarity is poor *and* the pump is aggressive, the twin **drops pump speed** and **lowers the rake**—a bedside manner for grain. The thresholds are **lab parameters**: **>150 mbar**, **<20% clarity**, **>50% pump** in the reference implementation.

**R_09 — `RegraIntertravamentoMosturaFiltro`** — If the filter pump is running but mash temperature is below **65 °C** *or* mash liquid level is below **50%**, the rule **zeros the pump**. Narratively: “You are not allowed to win this argument against physics upstream.” The numbers encode a **cartoon ISA-88 spirit**—phase gating—without implementing batch phases.

```elixir
# From lib/tec0301_pon/examples/smart_brewery_regras.ex
defrule(RegraOtimizacaoFiltracao,
  watch: [:fbe_03_diff_pressure, :fbe_03_wort_clarity, :fbe_03_pump_speed],
  when:
    memoria[:fbe_03_diff_pressure] > 150 and memoria[:fbe_03_wort_clarity] < 20 and
      memoria[:fbe_03_pump_speed] > 50,
  do:
    (
      Tec0301Pon.Examples.SmartBrewery.FBE_03.reduce_pump_10pct()
      Tec0301Pon.Examples.SmartBrewery.FBE_03.lower_rake_position()
      Tec0301Pon.Examples.SmartBrewery.RegraNotifier.notify(:r_01)
    )
)

defrule(RegraIntertravamentoMosturaFiltro,
  watch: [:fbe_02_mash_temp, :fbe_02_liquid_level, :fbe_03_pump_speed],
  when:
    memoria[:fbe_03_pump_speed] != nil and memoria[:fbe_03_pump_speed] > 0 and
      ((memoria[:fbe_02_mash_temp] != nil and memoria[:fbe_02_mash_temp] < 65) or
         (memoria[:fbe_02_liquid_level] != nil and memoria[:fbe_02_liquid_level] < 50)),
  do:
    (
      Tec0301Pon.Examples.SmartBrewery.FBE_03.zero_pump()
      Tec0301Pon.Examples.SmartBrewery.RegraNotifier.notify(:r_09)
    )
)
```

**Reading R_01 with the simulators:** `SimulacoesVisuais.SmartBrewery.FBE03Darcy` documents Darcy-style intuition and explicitly ties **rake** restoration to permeability recovery—helpful when students ask *why* lowering rake is a legitimate response. **R_01** is an AND of three inequalities; in classroom debate, ask what fails first when clarity is “okay” but pressure is high—real plants often add **OR** branches and operator overrides; the twin stays minimal.

**Reading R_09 as choreography:** note the **cross-FBE watch list**—mash facts and lauter pump in one rule. That is the **digital thread** lesson: separation is not a silo. When publishing, contrast with a naive PLC program that only looks at lauter instruments.

## Evidence locker (twin sheet)

### Facts (FBE_03)

| Fact | Unit / role |
|------|----------------|
| `fbe_03_diff_pressure` | mbar — bed stress |
| `fbe_03_wort_clarity` | % — quality proxy |
| `fbe_03_sparge_water_temp` | °C |
| `fbe_03_rake_height` | % |
| `fbe_03_pump_speed` | % — aggressiveness |

### Facts (FBE_02) touched by R_09

| Fact | Role in interlock |
|------|-------------------|
| `fbe_02_mash_temp` | Must be ≥ 65 °C while pump runs (twin fiction) |
| `fbe_02_liquid_level` | Must be ≥ 50% while pump runs |

### Simulation spine (physics paragraph)

`SimulacoesVisuais.SmartBrewery.FBE03Darcy` states in `@moduledoc`:

- **Darcy:** ΔP ∝ flow and viscosity, inversely ∝ permeability.
- **Compressible cake:** permeability decays with flow/compaction; rake actions restore **k**.
- Validates **R_01** when diff_pressure **>150**, clarity **<20**, pump **>50**.

`SimulacoesVisuais.SmartBrewery.FBE03Pure` offers simplified dynamics for Monte Carlo noise. Quote whichever module your audience prefers—**Darcy** for engineering students, **Pure** for probabilistic dashboards.

### Rules summary

- **R_01** — optimisation under stress (AND).
- **R_09** — mash–filter **sequence interlock** (ISA-88 *idea*; not a full S88 stack).

### Twin parameters

Values such as **150 mbar**, **20% clarity**, **50% pump**, **65 °C**, **50% level** are **lab thresholds**—tune for drama in teaching, not for a specific lauter geometry. Always separate them from **OEM curves** and **site P&IDs**.

### `simular/0` choreography

`Tec0301Pon.Examples.SmartBrewery.simular/0` nudges clarity and pump before spiking ΔP to **152 mbar** to demonstrate **R_01** firing—use it as a **scripted demo** after students read this chapter.

### Process mining teaser

`:r_01` and `:r_09` events in sequence tell different stories: optimisation loops vs procedural violations. Part 10 returns to **case_id** grouping—here, plant the idea that **interlocks** should appear as **rare, explainable** spikes if training is good.

## Further reading

**Briggs et al. — *Brewing Science and Practice*** — Wort separation, lauter design, and practical operator craft; anchors the **bed** vocabulary when code uses only five facts.

**Lewis & Young — *Brewing*** — Foundational filtration discussion at textbook depth; pair with transport phenomena references if students want **Darcy** derivations beyond the Elixir `@moduledoc`.

**Transport phenomena / porous media texts** — For readers who want **k**, **ε**, and **cake filtration** equations; cite your favourite chapter on **Darcy’s law** and **compressible cakes**.

**ISA-88** — Batch control and **phase** language; use carefully: we borrow **gating**, not an equipment module model.

**ISO 23247** — Position lauter facts as **digital representation** of a physical entity; rules as **cross-entity** responses—useful for enterprise architects in the audience.

**DOMAIN_BIBLIOGRAPHY.md** — Normalised list including digital twin and brewing rows.

**docs/smart-brewery-fatos-regras.md** — Canonical attribute and threshold table for publication cross-checks.

**docs/devto/en/05_smart_brewery_digital_twin_pon_lab.md** — Architecture escape hatch when readers ask how PubSub and LiveView **show** ΔP.

### Mara beat sheet

After **R_01**, she should **confirm** rake motion and pump drop on the HMI; after **R_09**, she should **look upstream** first—never blame the filter alone. That habit is free **human factors** content for your blog version.

### Instructor prompts

- **Sensitivity:** raise clarity threshold from 20 to 25 and count **R_01** firings—discuss **Type I vs Type II** mistakes in plain language.
- **Failure injection:** set mash temp to **64 °C** with pump > 0; verify **R_09** before **R_01** in logs—teaches **priority** if you extend the engine later.

### Legal / safety

No confined-space narrative, no CO₂ pocket story—keep filtration safety prose **procedural** unless you collaborate with site EHS. The twin is software.

## Next

**Part 5** — [Boil: foam, steam, and the kettle’s temper](05_fbe04_boil_kettle_safety_and_r06.md)
