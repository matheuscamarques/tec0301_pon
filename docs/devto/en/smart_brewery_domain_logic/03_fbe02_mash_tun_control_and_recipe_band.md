---
title: "Smart Brewery domain: mash tun — keeping Batch #47 in the band"
published: false
description: "Part 3 of 10 — The mash tun steams; pH and temperature drift; Mara’s recipe lives in a band, not a single point. R_05 is the twin’s gentle correction—ISA-88 as distant cousin, not a full batch engine."
tags: brewing, mash, isa88, processcontrol, elixir
series: smart-brewery-domain
---

# Mash tun — keeping Batch #47 in the band

**Part 3 of 10** — [Part 2](02_fbe01_mill_grist_and_mechanical_guardrails.md) · [Series index](README.md)

## The hook (scene)

After the mill, the story softens: **steam**, the **agitator** coughing once as it engages, the tun’s wall warm through insulated cladding. Batch #47’s mash is not romantic—it is **enzymes and time**. Mara watches **temperature** trace a plateau and **pH** hug a range that the lab signed off last quarter. Then the level gauge does something annoying: it climbs while the agitator status tile says **off**. The twin does not panic; it has a rule for “this is not where we agreed to be.” She leans closer—not because the numbers are catastrophic yet, but because **drift** is how bad batches start when everyone is busy elsewhere.

The corridor outside still smells of crushed grain from Part 2; inside the tun room, humidity paints the handrails. Somewhere a steam trap ticks. In prose we borrow those senses; in code we only have **six facts** and the honesty to admit viscosity is a **proxy** for “something about flow and body” rather than a full rheology model. That humility is part of the pedagogical contract: we name the mash as a **control problem** without claiming we solved starch chemistry in fifty lines of Elixir.

She might still be carrying the mill’s story in her head: **R_04** fired or did not; either way, the grist is committed. Mash is where **variance becomes soup**—particle size distributions from milling meet strike water and time. The twin will not resolve that variance into predicted extract; it will only know **when** the bulk variables leave a cartoon window. That is enough for software pedagogy and intentionally insufficient for **QA sign-off**—repeat that sentence in talks when someone asks “can we ship this to my plant?” If they need extract prediction, point them to **lab data** and **SKU-specific models**, not to this rule block alone.

**Bridge from Part 2:** if **R_04** was the mill’s protective voice, **R_05** is the mash tun’s **corrective** voice—less about catastrophe, more about **staying inside a band** long enough for biology to finish its homework. The grain bill from the mill is already inside the tun; Mara’s attention shifts from mechanical stress to **enzymatic real estate**.

## What the floor demands

Mashing is **band control** in plain clothes: too cold, conversion drags; too hot, you denature what you need; pH out of range skews enzyme happiness; a full tun without agitation invites **stratification** and misleading probes. The floor asks for **small, boring corrections** before the brewer has to shout. In larger plants, recipes encode **ramps, rests, and holds**; operators fight **deadbands** and **cascade loops**; labs backstop with **iodine tests** and **extract targets**. Our twin collapses that richness into a predicate **`mostura_fora_faixa?/1`** and two gentle actions—**start agitator** and **adjust water flow**—because the teaching goal is to show **where** a rule attaches in the graph, not to ship a full DCS.

If the band breaks silently—no agitation, wrong pH, temperature walking—downstream you pay in **lauter viscosity**, **yield**, and **flavour stability** arguments nobody wants at 3 a.m. Part 4’s lauter bed will inherit whatever sins the mash committed. Mara’s shift culture might say “the tun forgives”; the twin says **only if we nudge it back**.

ISA-88 appears in brewery conversations as **phases** and **operations**: mash-in, conversion rest, vorlauf prelude. This repository does **not** implement a batch engine with equipment modules and SFC charts. In the story, steal the **idea** of phase discipline—**do not advance** to aggressive filtration if mash truth says otherwise (that advance is **R_09** in Part 4). Here, keep the reader oriented: **flat facts + one rule** stand in for a hierarchy that would deserve its own repository.

## What the twin does — R_05, `RegraControleMostura`

`RegraControleMostura` watches mash temperature, pH, liquid level, and agitator state. The predicate **`mostura_fora_faixa?/1`** bundles the twin’s simplified recipe window: temperature outside **60–72 °C**, pH outside **5.0–5.8**, or **liquid level above 90%** while the agitator is **off**—a stratification hazard framed as a boolean story. When the band breaks, the rule calls **`FBE_02.start_agitator/0`**, **`FBE_02.adjust_water_flow(50)`**, and **`RegraNotifier.notify(:r_05)`**—narratively, “stir and dilute or circulate” without modelling individual shell-and-tube paths.

The helper and rule, as implemented:

```elixir
# From lib/tec0301_pon/examples/smart_brewery_regras.ex
def mostura_fora_faixa?(memoria) when is_map(memoria) do
  mash_temp = memoria[:fbe_02_mash_temp]
  ph_level = memoria[:fbe_02_ph_level]
  liquid_level = memoria[:fbe_02_liquid_level]
  agitator_status = memoria[:fbe_02_agitator_status]

  (mash_temp != nil and (mash_temp < 60 or mash_temp > 72)) or
    (ph_level != nil and (ph_level < 5.0 or ph_level > 5.8)) or
    (liquid_level != nil and agitator_status == :off and liquid_level > 90)
end

defrule(RegraControleMostura,
  watch: [:fbe_02_mash_temp, :fbe_02_ph_level, :fbe_02_liquid_level, :fbe_02_agitator_status],
  when: Tec0301Pon.Examples.SmartBrewery.Regras.mostura_fora_faixa?(memoria),
  do:
    (
      Tec0301Pon.Examples.SmartBrewery.FBE_02.start_agitator()
      Tec0301Pon.Examples.SmartBrewery.FBE_02.adjust_water_flow(50)
      Tec0301Pon.Examples.SmartBrewery.RegraNotifier.notify(:r_05)
    )
)
```

**Why extract the predicate?** Readable guards make classroom diffs easy: students can unit-test **`mostura_fora_faixa?/1`** without booting the entire PON mesh. It also mirrors how real batch software separates **recipe limits** from **execution engines**—even when our “recipe” is three inequalities and a level/agitator coupling.

**Operator ethics:** a real mash correction might need **lab sign-off** on pH adjustments, **water chemistry** checks, or **vessel limits**. The twin bypasses paperwork on purpose. When publishing, footnote that **no food-safety or QA narrative** is implied—only **reactive storytelling** tied to atoms in [`smart-brewery-fatos-regras.md`](../../../smart-brewery-fatos-regras.md).

## Evidence locker (twin sheet)

### Facts (FBE_02)

| Fact | Notes |
|------|--------|
| `fbe_02_mash_temp` | °C — primary band |
| `fbe_02_water_flow_rate` | L/min — adjusted by rule action |
| `fbe_02_agitator_status` | `:off` / `:on` |
| `fbe_02_ph_level` | pH band |
| `fbe_02_viscosity` | cP — twin texture (not wired into R_05) |
| `fbe_02_liquid_level` | % — vs agitator interlock inside predicate |

Boot values appear in `@fatos_iniciais` inside [`smart_brewery.ex`](../../../../lib/tec0301_pon/examples/smart_brewery.ex)—for example mash **65 °C**, pH **5.2**, level **0** at the pedagogical cold start; your LiveView or Monte Carlo path may initialise differently when staging demos.

### Rule

- **R_05** — `RegraControleMostura`; notifier tag **`:r_05`**.

### ISA-88 (conceptual)

Real plants express mash as **phases** in a batch recipe. This repo uses **flat facts + one rule**—in the story, say: “We are stealing the *idea* of phase discipline without shipping a full S88 engine.” If readers want UML/SFC depth, send them to ISA documents and to MES vendors; if they want **Elixir**, send them back to Part 5’s architecture article on the PON lab.

### Twin parameters

Numeric bands in code are **teaching values**, not a validated mash profile for a branded beer. Adjunct-heavy mashes, step mashes, and decoction narratives **will not fit** these constants—invite contributors to fork **`mostura_fora_faixa?/1`** for regional recipes and to document their thresholds as **twin parameters** in pull requests.

### Cross-links

- **R_09** (Part 4) uses mash temperature and level to **block lauter pump** aggression—sequence interlock, not mash quality optimisation.
- **FBE_02** actions should remain **idempotent** in spirit: repeated `start_agitator` calls should not oscillate the HMI in a real port; the demo may simplify.

### Simulation note

Monte Carlo layers in `simulacoes_visuais` may jitter temperature and pH slightly; watch whether **R_05** fires more often under noise—an opportunity to discuss **debounce**, **hysteresis**, and **minimum dwell** in industrial controllers—topics the twin leaves as exercises.

## Further reading — beyond the story

**ISA-88** — Batch control models (procedures, unit procedures, operations, phases). Use it to explain **why** breweries speak in “mash-in” and “conversion” sentences while this repo stores **atoms** instead of phase charts. Always note: **no full S88 implementation** here.

**ISA-95** — Enterprise vs control integration. Useful when contrasting **cell-level mash rules** with **ERP batch orders**—Batch #47 is deliberately **below** the ERP storyline.

**Bamforth — *Brewing: New Technologies*** — Mash biochemistry and practical modern constraints; good for **why pH and temperature bands exist** beyond “because the code says so.”

**Lewis & Young — *Brewing* (2nd ed.)** — Foundational mash chapter; pair with Briggs for **engineering-heavy** audiences.

**Briggs et al. — *Brewing Science and Practice*** — Equipment and process detail when you describe **agitator duty** and **wort collection** transitions—even if the twin models them thinly.

**ISO 23247** — Digital twin framework; position mash facts as **digital representation** fed by **data collection** stubs, with rules as **cross-entity applications** nudging state.

**DOMAIN_BIBLIOGRAPHY.md** — Normalised entries and URLs for the above.

**docs/ml-smart-brewery-data.md** — When mash telemetry lands in TimescaleDB, tie **continuous variables** to supervised models cautiously—mash quality labels are expensive; prefer **anomaly** framing early (Part 10).

**docs/devto/BIBLIOGRAPHY_PON_SERIES.md** — Return path to Phoenix, PubSub, and PON philosophy when mash prose feels too “soft.”

### Instructor note

Have students **tune** the pH band by ±0.1 and observe how often `notify(:r_05)` fires in a noisy simulation—then relate **false positive rate** to operator trust. That single experiment connects brewing to **human factors** without extra code.

### Water and steam subplots the twin ignores

Real mash control couples **strike water volume**, **mineral profile**, **grist temperature**, and **heat loss** through vessel walls. `fbe_02_water_flow_rate` exists as a fact the rule can nudge, but there is no enthalpy balance proving the mash will land back in band after **`adjust_water_flow(50)`**. Treat that call as **symbolic**: “open the trim valve to a teaching setpoint.” If you extend the twin, consider a **simple energy ledger**—strike temp, mass flow, specific heat—so Mara’s story gains **thermodynamic teeth** without CFD.

### pH: process vs measurement

Portable pH meters disagree with inline probes after fouling or temperature compensation errors. The twin assumes **one true pH** atom. In published prose, acknowledge **sensor hygiene** and **calibration drift** as reasons plants run **redundant** analytics—another hook for Part 10’s anomaly layer when pH wanders without a matching temperature story.

### Agitator semantics

`:off` and `:on` hide **VFD speed**, **shear sensitivity**, and **foam** on high-adjunct mashes. If your audience includes mechanical engineers, invite them to map `:on` to “≥ minimum RPM for homogeneity” in a real port. Batch #47 stays polite: when level > 90 and agitator is off, the twin assumes **dangerous stratification** rather than “we meant to settle the bed.”

### Shift handover angle

Mara’s relief operator cares about **who changed water flow** and **why pH moved**. `rule_events` with `:r_05` timestamps become **shift diary lines**—use that in Part 10 when discussing process mining: mash corrections are **human-audible** when named rules back them.

### Viscosity fact (unused by R_05)

`fbe_02_viscosity` is part of the FBE_02 tableau for future extensions—filtration prediction, pump curves, or **lauter premonition**. Mention it so readers do not assume the table is minimal by accident; it is **reserved narrative space**.

### Comparison to PLC ladder habits

PLCs often implement mash holds with **timers** and **sequencers**. Elixir rules here are **stateless guards** over memory unless you add your own state machines. Discuss the trade-off: declarative rules are easy to read; sequencers are easy to certify. The Smart Brewery sits in the **readable** camp on purpose.

### Batch #47 micro-timeline (optional fiction beat)

Minute zero: mash-in completes; temperature sits near **65 °C**. Minute twenty: a door draft or a lazy steam trap lets temp sag toward **59 °C**—`mostura_fora_faixa?` goes true; **R_05** stirs and pushes water flow. Minute forty-five: pH drifts high after an unexpected mineral hitch; the same rule fires again. Mara sees **two `:r_05` events** with different fact causes if your log captures memory snapshots—great fodder for **explainability** essays. None of this is simulated automatically; it is a **storyboard** you can implement by nudging facts in IEx.

### Glossary snippet for dev.to

- **Band:** acceptable interval, not a setpoint religion.
- **Stratification:** dense zones in the tun that lie to probes.
- **Vorlauf:** clarity recycle prelude—outside this module but culturally adjacent to Part 4.

**Closing reminder:** R_05 is a **teaching rule**. Production mashes deserve **models, procedures, and alarms** tuned to your water, your malt lot, and your vessel—not to a generic Elixir example repo. Treat every threshold as **fork-friendly**, not **law**. Document your fork in the repo that actually runs your brewhouse.

## Next

**Part 4** — [When the lauter bed fights back](04_fbe03_lauter_filtration_physics_and_r01.md)
