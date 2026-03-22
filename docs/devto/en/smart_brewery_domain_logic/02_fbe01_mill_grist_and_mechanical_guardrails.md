---
title: "Smart Brewery domain: the mill talks back — grist and mechanical guardrails"
published: false
description: "Part 2 of 10 — Batch #47’s grist hits the mill; vibration climbs; Mara hears the change before she sees it. R_04 steps in—ISO 10816-3 as vocabulary, not a stamped report."
tags: brewing, mechanical, iso10816, safety, elixir
series: smart-brewery-domain
---

# The mill talks back — grist and mechanical guardrails

**Part 2 of 10** — [Part 1](01_why_this_twin_maps_a_brewery_line.md) · [Series index](README.md)

## The hook (scene)

Batch #47 begins where every beer still begins in the imagination: **malt falling**, rollers biting, dust controlled just enough that the corridor does not taste like toast. Mara checks the **hopper level** on the HMI; the mill motor has been hunting a steady RPM. Somewhere between “normal Monday noise” and “something is wrong,” the trend tile for **vibration** twitches—once, twice—before the number commits. She does not need the alarm banner yet; her ear already filed a **timbre change**—the kind veteran operators pretend is unmeasurable until maintenance agrees it was real all along.

The twin, which does not have ears, receives the same facts the SCADA would: RPM, hopper, motor temperature, vibration, feed valve state. In the story, this is the first time the **rules** prove they are not decoration. When vibration crosses the twin’s “zone C” story threshold, **R_04** reduces motor speed; when the story escalates to “zone D,” the feed valve closes—an abrupt, almost rude act that in a real plant would be coordinated with interlocks and procedures we do not simulate here.

**Bridge from Part 1:** the prologue promised fifty-seven facts and twelve rules; at the mill we touch only **five facts** and **one rule**, but they establish the **pattern** for the whole series: watch a small set of atoms, evaluate a guard over memory, act through an FBE module, notify for telemetry. Everything downstream—lauter stress, kettle foam, grid cost—is the same choreography with different nouns.

If you are writing for dev.to, keep one foot in **story** and one in **inspectability**: encourage readers to open `smart_brewery.ex`, find `@fatos_iniciais` for `fbe_01_*`, and nudge values in IEx. The mill is the gentlest place to learn that **PON rules are not background jobs**—they are reactive processes that **compete for attention** with the same urgency as a flashing tile, only without the red pigment.

## What the floor demands

A grist mill is a **load-following machine**: dull rolls, tramp metal, or a starving feed can show up as heat and vibration before they show up as quality lab numbers. The floor asks: **slow down or stop before metal meets metal**, and never run “air” through a choked inlet. Hopper starvation while RPM stays positive is how you teach bearings to write resignation letters. Temperature rise without a matching change in throughput hints at friction, misalignment, or electrical grief—none of which this twin diagnoses, but all of which justify **backing off** in fiction and in code.

Standards like **ISO 10816-3** exist so plants classify vibration severity on **real classes of machinery**, with mounting details, power ratings, and measurement points that matter. Our twin borrows that **language** with numbers chosen for the lab. When you publish, say clearly: these thresholds are **not** the outcome of a site vibration survey; they are **pedagogical zones** so Elixir readers can see `edge_triggered` behave like a latched protection philosophy instead of a buzzing nuisance.

If nobody acts—human or twin—the narrative consequence is unglamorous: **equipment damage**, **fire risk** in the worst stories, and **grist inconsistency** that shows up three hours later as conversion headaches in the mash tun. Part 3 picks up there; for now, the floor only demands that **mechanical pride** does not outrun **mechanical humility**.

Maintenance cultures often separate **predictive** and **protective** layers: predictive tries to schedule downtime; protective tries to prevent a single bad minute from becoming a capital expense. **R_04** is unapologetically **protective**—it does not predict *when* a bearing will fail; it responds when the twin’s simplified observables say **conditions are already wrong**. That is a deliberate teaching position: you can bolt on forecasting later (Part 10’s ML lane), but you should not pretend the absence of a model equals safety.

Operators also carry **social** constraints the twin ignores: lock-out/tag-out, permit-to-work, noise exposure limits. Name those gaps in a footnote when you publish so industrial readers trust you are not smuggling a cartoon PLC into their safety case.

## What the twin does — R_04, `RegraProtecaoMoinho`

When vibration or motor temperature crosses the twin’s guard bands—or when the hopper is dangerously low while the mill still spins—the rule **reduces RPM** and, in the worst vibration case, **closes the feed valve**. It fires with **`edge_triggered: true`** so the story is not “the alarm screams forever”; it is “the twin intervenes once per crossing, like a latched operator acknowledgment.” That detail matters for **process mining** later: you want discrete **protection events**, not an infinite stream of identical firings while a sensor stays high.

The implementation watches five facts and combines mechanical and starvation logic with **OR** semantics—any serious stress path can trigger protection. The `when` clause also gates on `nil` safely for teaching robustness. Below is the actual `defrule` from the repository:

```elixir
# From lib/tec0301_pon/examples/smart_brewery_regras.ex
defrule(RegraProtecaoMoinho,
  watch: [
    :fbe_01_motor_temp,
    :fbe_01_vibration_level,
    :fbe_01_hopper_level,
    :fbe_01_motor_rpm,
    :fbe_01_feed_valve_state
  ],
  when:
    (memoria[:fbe_01_vibration_level] != nil and memoria[:fbe_01_vibration_level] > 80) or
      (memoria[:fbe_01_motor_temp] != nil and memoria[:fbe_01_motor_temp] > 70) or
      (memoria[:fbe_01_hopper_level] != nil and memoria[:fbe_01_motor_rpm] != nil and
         memoria[:fbe_01_hopper_level] < 15 and memoria[:fbe_01_motor_rpm] > 0),
  edge_triggered: true,
  do:
    (
      Tec0301Pon.Examples.SmartBrewery.FBE_01.reduce_motor_rpm()

      if memoria[:fbe_01_vibration_level] != nil and memoria[:fbe_01_vibration_level] > 95,
        do: Tec0301Pon.Examples.SmartBrewery.FBE_01.close_feed_valve()

      Tec0301Pon.Examples.SmartBrewery.RegraNotifier.notify(:r_04)
    )
)
```

**Reading the rule with Mara in mind:** the first two disjuncts are classic **condition monitoring** stories—vibration above **80** (mm/s in the twin’s fiction) or motor temperature above **70 °C**. The third disjunct is **process sense**: hopper below **15%** while RPM is still positive means “we are pretending there is grain when physics says otherwise.” The inner `if` escalates to **95 mm/s** vibration to **close the feed valve**—a harsher cut than RPM reduction alone. Finally, `RegraNotifier.notify(:r_04)` ensures dashboards, logs, and later ML exports can say **which rule spoke**.

Initial conditions for the mill facts boot from [`smart_brewery.ex`](../../../../lib/tec0301_pon/examples/smart_brewery.ex)—for example hopper at **80%**, motor temperature **45 °C**, vibration **0** at rest—so demonstrations usually **perturb** vibration or temperature in IEx to see the rule fire.

**Why `edge_triggered: true` deserves a second coffee:** in production-grade rule engines, “latching” behaviour prevents **thrashing** when actuators and sensors chase each other. Here, the latch is minimal—enough to make classroom demos readable. If you remove it for an experiment, watch how `notify(:r_04)` might spam subscribers; that failure mode is **educational** when you are teaching observability budgets.

## Evidence locker (twin sheet)

### Facts (FBE_01)

| Fact | Typical unit / type | Story role |
|------|---------------------|------------|
| `fbe_01_motor_rpm` | RPM | Throughput |
| `fbe_01_vibration_level` | mm/s | Mechanical stress |
| `fbe_01_hopper_level` | % | Starvation risk |
| `fbe_01_motor_temp` | °C | Thermal overload |
| `fbe_01_feed_valve_state` | atom | Final cut-off |

Catalog with types and initial values: [`smart-brewery-fatos-regras.md`](../../../smart-brewery-fatos-regras.md).

### Rule

- **R_04** — `RegraProtecaoMoinho`; notify `:r_04` for `rule_events` / process mining.

### Twin parameters vs plant limits

Thresholds such as **80 / 95 mm/s** or **70 °C** in code are **simulation knobs**. A real mill would use class, mounting, and manufacturer curves—cite ISO 10816-3 as **how plants think**, then show your lab numbers as **explicitly fictional**. The **15%** hopper floor is likewise a teaching line: some plants meter feed gravimetrically and would not use a single % without calibration.

### Code paths beyond the rule

Action helpers live under `Tec0301Pon.Examples.SmartBrewery.FBE_01` (`reduce_motor_rpm/0`, `close_feed_valve/0`). When you extend the twin, keep **side effects** in those modules so the `defrule` block stays readable as policy.

### Anomalies and Part 10 (foreshadowing)

Monte Carlo noise and EMA layers in the visual app can make **vibration** drift before a rule fires. That is intentional: Part 10 will treat such drift as **early personality change** in telemetry, not only as binary alarms.

### ISO 10816-3 in prose (without faking a report)

Real vibration programs talk about **machine groups**, **support stiffness**, **operating speed**, and **measurement axes**. ISO 10816-3 is part of a family that helps engineers decide whether a mm/s reading is “keep running,” “watch,” or “stop.” Our twin collapses that culture into **two numeric thresholds**—80 and 95 on an abstract **vibration_level** fact—so the code stays small. When you teach, draw a **sketch** of zones A–D on a whiteboard, then label the twin’s numbers as **stand-in ordinates** on that sketch. Students learn the *shape* of the standard’s thinking even when the lab hardware is a keyboard.

### Tabletop exercise (optional callout box)

Ask readers: *If `edge_triggered` were false, how would `rule_events` explode during a sustained fault?* Then ask: *When would you want repeated notifications anyway—perhaps for SIL architectures with diverse proof tests?* The Smart Brewery does not implement safety integrity levels; the question still trains **event semantics**.

### Pairing with `simular/0`

`Tec0301Pon.Examples.SmartBrewery.simular/0` walks filtration, packaging, and grid scenarios—not the mill first—but after you understand **R_04**, try a **custom IEx script**: hold hopper high, raise vibration above 80, observe RPM reduction, then spike past 95 to close the feed valve. Narrate each step as if Mara were reading tiles in order. That rehearsal makes Part 3’s mash band easier because you already trust the **notify** path.

## Further reading — for the standards-minded reader

**ISO 10816-3** — *Mechanical vibration — Evaluation of machine vibration on non-rotating parts* frames severity zones for industrial machines. Use it to explain why vibration appears as a **scalar** in the twin and why real programs attach **FFT**, **mounting**, and **machine class** to that scalar. Do not imply this repo performed zone classification on hardware.

**Briggs, Boulton, Brookes, Stevens — *Brewing Science and Practice*** — Equipment-oriented discussion of mills and grist preparation; helps you narrate **particle size distribution** and **husk integrity** even when the code only exposes RPM and hopper %.

**Lewis & Young — *Brewing* (2nd ed.)** — Mash and wort chapters give the **downstream reason** mills matter: uneven grist changes extraction and lauter behaviour—connecting Part 2 to Part 4 without pretending the twin models particle physics.

**Bamforth — *Brewing: New Technologies*** — Modern unit-operation perspective; useful if you compare **dry milling vs wet conditioning** in prose while the simulation stays abstract.

**Grieves (2014)** — Digital twin vocabulary; the mill is a clean example of a **physical entity** mirrored by **data collection** facts and **cross-entity** rules that will later talk to packaging and grid modules.

**ISO 23247** — Framework context from Part 1; here, emphasize **information exchange** between “mechanical telemetry” and “protection policy.”

**Repository bibliography hub:** [`DOMAIN_BIBLIOGRAPHY.md`](DOMAIN_BIBLIOGRAPHY.md) for normalized citations and URLs.

**PON / platform depth:** [`docs/devto/BIBLIOGRAPHY_PON_SERIES.md`](../../BIBLIOGRAPHY_PON_SERIES.md) when you need Elixir process or LiveView anchors beyond domain prose.

### Mara’s loop (character note for serialised publishing)

When you post this chapter alone, give Mara **one decisive beat** after the twin acts: does she acknowledge the RPM drop on the HMI, walk to the mill to listen again, or call maintenance with a **timestamp**? Human closure sells the idea that **rules are teammates**, not magic. The code already timestamps notifier events if your stack persists them—use that as diegetic detail (“the log said 14:06:22”) without inventing database schemas in prose.

### Grist quality as a silent variable

The twin does not expose **particle size** or **friability** as facts. If advanced readers ask, point them to Briggs and to offline lab tests; explain that **version 1** of the twin prioritises **protective mechanical telemetry** because it pairs cleanly with Elixir message passing. A future **FBE_01 extension** could add a “fines %” fact driven by assay imports—good thesis fodder, not required for Batch #47’s arc.

**Word to the mentor:** assign students to map **each `watch` atom** to a plausible physical sensor and **estimate scan rate**—even a back-of-envelope 1 Hz vs 10 Hz discussion teaches why “reactive rules” are not the same as **PLC scan cycles**, even when the story blurs them for brevity. That single homework closes the loop nicely.

## Next

**Part 3** — [Mash tun: keeping Batch #47 in the band](03_fbe02_mash_tun_control_and_recipe_band.md)
