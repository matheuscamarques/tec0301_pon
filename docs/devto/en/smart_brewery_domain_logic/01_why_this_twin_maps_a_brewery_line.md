---
title: "Why this digital twin maps a brewery line"
published: false
description: "Part 1 of 10 — Before Batch #47 starts: a story-led tour of the Smart Brewery twin, eleven FBEs, twelve rules, and why ISO 23247 is our map—not a certificate."
tags: brewing, digitaltwins, industry40, elixir, iot
series: smart-brewery-domain
---

*Companion series:* [PON + Smart Brewery on dev.to](https://dev.to/matheuscamarques) — start with [Part 5 — Smart Brewery as a PON lab](https://dev.to/matheuscamarques/smart-brewery-a-digital-twin-brewery-as-a-pon-lab-36mf) for architecture; **this** track is domain-first and **narrative-led**.

# Why this digital twin maps a brewery line

**Part 1 of 10** — [Series index](README.md)

## The hook (scene) — the plant before the story

Imagine the lights in the corridor to the brewhouse: white tile, condensing pipes, the low hum of a Monday that has already started without you. Nothing in this repository is that physical wall—but the **Smart Brewery** twin in code is written so that a reader can **walk the same path** as wort: mill, mash, lauter, boil, cool, ferment, package, with CIP loops, robots, and a grid story woven in. The corridor is imaginary; the **order of operations** is not.

Over the next nine parts we follow **Batch #47** (fictional) with **Mara** on shift as our human anchor. The **digital twin** is the other protagonist: it holds fifty-seven **facts** and reacts through twelve **rules** (`R_01`–`R_12`). Your job as author is to make the reader **feel** the sequence; your job as engineer is to keep every threshold honest as a **lab parameter**, not a stamped approval from a real boiler or a real mill. That distinction matters because the prose will sound authoritative—steam, pressure, conductivity—and authority without disclaimers is how teaching demos get mistaken for sign-offs.

Before the first auger turns, the twin is already a **graph of attention**: each fact is a process variable the runtime can subscribe to; each rule is a named habit that fires when watched variables cross a condition. The Elixir modules do not simulate fluid dynamics in CFD fidelity; they **name** the same worries a cell operator carries (bed stress, foam, tariff spikes, a capper jam) and show how **reactive rules** attach consequences. This prologue exists so that when Part 2 opens at the mill, you already know what kind of machine you are reading about.

## What the floor demands — a pact with the reader

We promise three things, and we add a fourth that the floor would insist on if it could speak.

1. **Story first, evidence second** — each chapter opens in prose; the **Evidence locker** holds tables, code pointers, and norms. The story buys attention; the locker buys trust.

2. **No fake compliance** — when we name **NR-13**, **ISO 10816-3**, or **ISO 23247**, we mean “this is the vocabulary industries use,” not “this repo passed an audit.” Brazilian pressure-equipment culture, vibration severity zones, and digital-twin framework blocks are **maps**, not medals.

3. **Continuity** — Part 2 picks up at the **mill** as Batch #47’s grist enters the line; Part 9 steps sideways into **CIP** as an interlude; Part 10 ends in the **control-room debrief** (OEE, anomalies, rule traces, ML).

4. **Traceability** — every rule in the story exists in [`smart_brewery_regras.ex`](../../../../lib/tec0301_pon/examples/smart_brewery_regras.ex); every initial fact value is listed in [`smart_brewery.ex`](../../../../lib/tec0301_pon/examples/smart_brewery.ex). If the narrative says “the twin dropped pump speed,” you should be able to find the `defrule` and the FBE helper it calls.

If that contract works for you, turn the page—virtually—to the mill in Part 2. If you are the kind of reader who needs the cast list before the play, the next section names every **functional block element (FBE)** and what it is responsible for in one breath each.

Keep a personal margin: if you paste these drafts into dev.to, front matter and navigation links do not count as “reading time” for your audience—the body still should feel like a **single sitting** for a motivated engineer. That is why the series README sets **≥2000 words** as a floor, not a ceiling.

## What the twin does — the cast of the play

The repo instantiates **eleven functional block elements (FBEs)** and **fifty-seven atomic facts** (`Tec0301Pon.PON.Fato`), bootstrapped in [`smart_brewery.ex`](../../../../lib/tec0301_pon/examples/smart_brewery.ex). Rules live in [`smart_brewery_regras.ex`](../../../../lib/tec0301_pon/examples/smart_brewery_regras.ex): each `defrule` is a **named habit** the twin performs when watched facts change.

**FBE_01 — Mill / grist** — Rollers, hopper, motor thermal and mechanical stress. The story’s opening mechanical voice; **R_04** protects against vibration and starvation patterns.

**FBE_02 — Mash tun** — Temperature, pH, level, agitator, water flow, viscosity proxy. **R_05** nudges the mash back into a teaching band; **R_09** later forbids lauter aggression when mash is “not ready.”

**FBE_03 — Lauter / filter** — Differential pressure, clarity, rake, pump, sparge temperature. **R_01** optimises under bed stress; **R_09** interlocks mash and filter.

**FBE_04 — Boil kettle** — Boil temperature, steam pressure, foam, evaporation, hop doser. **R_06** is the kettle’s “back off” voice; **R_10** couples boil to cooling readiness.

**FBE_05 — Heat exchanger** — Wort in/out, glycol valve, water pressure. **R_07** pushes cooling when the twin sees hot wort exiting with valve headroom; **R_10** opens glycol when boil says cooling must not be blocked.

**FBE_06 / FBE_07 — Fermenters A & B** — Temperature, pressure, gravity, jacket, CO₂, phase (and pH on A). **R_03** and **R_08** connect fermentation loads to **FBE_11** when tariffs and buffers allow shifting chill or discharging V2G-style storage in the lab model.

**FBE_08 — Packaging line** — Conveyor, fill head, capper, sensors. **R_02** halts the line when capper, fill quality, or **FBE_10** collision signals demand it.

**FBE_09 — CIP** — Caustic/acid tank levels, return conductivity, pump, flow. Not glamorous, but it is how the narrative admits that **hygiene loops** compete for utilities with fermentation in Part 9.

**FBE_10 — AMR fleet** — Battery, pose, status, collision, payload. **R_11** recalls a low-battery robot on mission; **R_02** treats collision as a packaging emergency.

**FBE_11 — Smart grid** — Power cost, V2G buffer, main load, fault flag. **R_03**, **R_08**, and **R_12** are the twin’s **energy grammar**: peak shaving, load balancing, islanding fiction.

Together, the twelve rules are a **cross-cutting grammar** over those blocks: optimisation, safety-flavoured backoff, sequencing interlocks, and grid-aware load management—each wired to `RegraNotifier` so downstream telemetry and demos can record **which rule spoke**.

### Boot sequence — `start_link/0`

When the twin “energizes,” the code spawns one `Fato` process per fact, then starts each rule process. The excerpt below is the heart of that choreography (paths relative to repo root):

```elixir
# From lib/tec0301_pon/examples/smart_brewery.ex
def start_link do
  for {nome, valor} <- @fatos_iniciais do
    Fato.start_link(nome, valor)
  end

  Tec0301Pon.Examples.SmartBrewery.Regras.RegraOtimizacaoFiltracao.start_link()
  Tec0301Pon.Examples.SmartBrewery.Regras.RegraIntertravamentoEnvase.start_link()
  Tec0301Pon.Examples.SmartBrewery.Regras.RegraSmartGridLoadBalancing.start_link()
  Tec0301Pon.Examples.SmartBrewery.Regras.RegraProtecaoMoinho.start_link()
  Tec0301Pon.Examples.SmartBrewery.Regras.RegraControleMostura.start_link()
  Tec0301Pon.Examples.SmartBrewery.Regras.RegraSegurancaCaldeira.start_link()
  Tec0301Pon.Examples.SmartBrewery.Regras.RegraOtimizacaoTrocador.start_link()
  Tec0301Pon.Examples.SmartBrewery.Regras.RegraLoadBalancingFermentadorB.start_link()
  Tec0301Pon.Examples.SmartBrewery.Regras.RegraIntertravamentoMosturaFiltro.start_link()
  Tec0301Pon.Examples.SmartBrewery.Regras.RegraIntertravamentoFervuraTrocador.start_link()
  Tec0301Pon.Examples.SmartBrewery.Regras.RegraGestaoBateriaAMR.start_link()
  Tec0301Pon.Examples.SmartBrewery.Regras.RegraResilienciaRede.start_link()

  {:ok, self()}
end
```

The module also ships `simular/0`, a scripted walk that nudges facts into a corridor where **R_01**, **R_02**, and **R_03** can fire in sequence—useful when you want the **same story** in an IEx session as on a slide deck.

### Rule index (R_01–R_12)

| Rule module | Idea |
|-------------|------|
| `RegraOtimizacaoFiltracao` | R_01 — high ΔP, poor clarity, aggressive pump → ease off |
| `RegraIntertravamentoEnvase` | R_02 — packaging emergency + AMR collision awareness |
| `RegraSmartGridLoadBalancing` | R_03 — cold ferment + CIP + peak tariff → shift loads |
| `RegraProtecaoMoinho` | R_04 — mill protection (vibration / temperature / starvation) |
| `RegraControleMostura` | R_05 — mash band recovery |
| `RegraSegurancaCaldeira` | R_06 — kettle backoff |
| `RegraOtimizacaoTrocador` | R_07 — HEX glycol push |
| `RegraLoadBalancingFermentadorB` | R_08 — fermenter B + grid + V2G |
| `RegraIntertravamentoMosturaFiltro` | R_09 — mash/filter sequence |
| `RegraIntertravamentoFervuraTrocador` | R_10 — boil vs glycol interlock |
| `RegraGestaoBateriaAMR` | R_11 — AMR low battery on mission |
| `RegraResilienciaRede` | R_12 — grid fault → island / shed / discharge |

Full `watch` lists, types, and action descriptions: [`docs/smart-brewery-fatos-regras.md`](../../../smart-brewery-fatos-regras.md).

## Evidence locker (twin sheet)

### FBE overview (fact counts)

| FBE | Concept | Fact count (twin) |
|-----|---------|-------------------|
| 01 | Mill / grist | 5 |
| 02 | Mash tun | 6 |
| 03 | Lauter / filter | 5 |
| 04 | Boil kettle | 5 |
| 05 | Heat exchanger | 4 |
| 06 | Fermenter A | 7 |
| 07 | Fermenter B | 6 |
| 08 | Packaging | 6 |
| 09 | CIP | 5 |
| 10 | AMR fleet | 5 |
| 11 | Smart grid | 4 |

**Total:** 57 facts, 12 rules — full names in [`smart-brewery-fatos-regras.md`](../../../smart-brewery-fatos-regras.md).

### ISO 23247 — map of the story’s “acts”

Normative **framework blocks** from **ISO 23247**—physical entity, data collection, digital representation, information exchange, cross-entity applications—are mirrored in teaching prose (PT) in [`docs/artigos/12_mapeamento_iso_23247.md`](../../../artigos/12_mapeamento_iso_23247.md) and in Elixir as `SimulacoesVisuais.SmartBrewery.ISO23247.map_components/0`. Use ISO 23247 to explain **where LiveView, PubSub, TimescaleDB, and rule traces sit** in a digital-twin discussion without claiming the repository is a certified ISO implementation.

### ISA-95 (stack context)

When Part 10 mentions OEE and enterprise historians, **ISA-95** gives you the polite vocabulary for “this demo is cell-level, not ERP.” One diagram in a published post is enough: enterprise vs MES vs SCADA vs the twin’s Elixir nodes—**pedagogical only**.

### Twin parameters (global reminder)

Every numeric threshold in rules is a **tunable simulation**. Validate against real datasheets, OEM manuals, and site P&IDs before quoting numbers as plant limits. The series repeats this so readers who skim Part 1 still see it again beside **NR-13** and **ISO 10816-3** in later chapters.

### How this connects to the Phoenix lab (optional pointer)

If you run the visual app, facts surface through `SimulacoesVisuais.SmartBrewery.FatoDescriptions` for UI copy, while Monte Carlo and TSDB paths (see [`docs/ml-smart-brewery-data.md`](../../../ml-smart-brewery-data.md)) stress the same atoms under noise. Thinking of **facts as the stable API** and **rules as policies** helps when you jump from this domain series back to the architecture article: the twin is not “a LiveView,” but LiveView is one honest window into the fact graph.

### PON mechanics in one paragraph

Each `Fato` holds a value and notifies dependents when it changes. Each `defrule` declares a `watch` list and a `when` guard over a **memory map** snapshot; on a match, it executes side effects through small `FBE_XX` modules (pump speed, valve position, notifier hooks). Some rules use `edge_triggered: true` so repeated ticks with a latched condition do not spam the floor—an implementation detail that matters when you later read **process mining** exports from `rule_events`: you want events that resemble **operator interventions**, not infinite loops.

## Further reading — beyond the prologue

**Grieves (2014)** — *Digital Twin: Manufacturing Excellence Through Virtual Factory Replication* is the shorthand citation everyone argues about; use it to anchor **twin vocabulary** (product, process, performance mirrors) before you show Elixir processes as a literal mirror of “things that update when facts change.”

**ISO 23247 (2021)** — Framework for manufacturing digital twins. Read the standard’s scope as **architecture**, not a project checklist. Pair it with the repo’s `ISO23247` module and the Portuguese mapping article for bilingual teams.

**ISA-95** — Enterprise–control integration. Helps you position the Smart Brewery demo relative to MES and ERP without overclaiming.

**ISA-88** — Batch control models. The mash and filtration chapters borrow **phase-gating ideas** without implementing a full recipe engine.

**Briggs et al.; Lewis & Young; Bamforth** — Brewing science and unit operations. When the story names enzymes, bed stress, or foam, these texts are where serious brewers send engineers who ask “why would anyone care about that probe?”

**ISO 10816-3** — Mechanical vibration severity. Appears again at the mill; thresholds in code are **illustrative zones**, not a vibration study.

**NR-13 (Brasil)** — Pressure equipment and institutional memory around boilers. Named in the kettle chapter; the twin is **not** a PSSR substitute.

**Full domain bibliography:** [`DOMAIN_BIBLIOGRAPHY.md`](DOMAIN_BIBLIOGRAPHY.md).

**Platform / PON / ML track:** [`docs/devto/BIBLIOGRAPHY_PON_SERIES.md`](../../BIBLIOGRAPHY_PON_SERIES.md) and [`docs/ml-smart-brewery-data.md`](../../../ml-smart-brewery-data.md) when you connect facts to TimescaleDB and walk-forward validation.

**van der Aalst / PM4py** — If you already care about `rule_events`, process mining is the natural sequel: discovery and conformance over event logs pair well with a twin that emits **named rule firings** instead of only raw sensor frames.

## Next in series

**Part 2** — [The mill talks back: grist and R_04](02_fbe01_mill_grist_and_mechanical_guardrails.md)
