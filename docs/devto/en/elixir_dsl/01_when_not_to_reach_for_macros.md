---
title: "Building DSLs in Elixir (Part 1): when (not) to reach for macros"
published: false
description: "Part 1 of 10 — Riverbank Greenhouse outgrows copy-pasted rules; Maya wants macros, Jordan demands a plain API first. When defmacro earns its place."
tags: elixir, metaprogramming, macros, dsl
series: elixir-dsl-building
---

*If this helped you, you can [support the author with a coffee on dev.to](https://dev.to/matheuscamarques/support-with-a-coffee-2oa0).*

# Building DSLs in Elixir (Part 1): when (not) to reach for macros

**Part 1 of 10** — [Series index](README.md) · **The story:** Riverbank Greenhouse · Next: [Part 2 — The night the macro would not compile](02_ast_essentials_quote_unquote_bind_quoted.md)

**Reading time:** long-form draft (~10 min). Technical posts in English are often read at roughly 200–250 words per minute; each part in this folder targets about **2,000+ words** so you can go deep beside the Riverbank serial.

---

The humidity alarms at **Riverbank Greenhouse** had been quiet for months—until the week Maya and Jordan shipped the tenth irrigation rule by hand. Each rule was another `defmodule` with the same `start_link` dance, the same callback names, and a condition that *looked* like plain Elixir but had to line up perfectly with the last one. Somewhere between rule seven and rule nine, a `watch` list drifted. The system still compiled. It just stopped agreeing with the spec on Tuesday afternoons.

Maya slammed her laptop shut—not from anger, but from the familiar feeling that the **shape** of the code was fighting them. “We need a macro,” she said. Jordan, who had been burned before by “clever” generators, only raised an eyebrow. “We need to know what a rule *is* without the sugar first,” he answered. “If you cannot write *one* rule in public APIs and sleep at night, a macro will only hide the insomnia.”

That argument is where this series begins. The [PON / Smart Brewery Part 3](../03_metaprogrammed_dsl_defrule_defpremissa.md) tells the **domain** story of `defrule` and `defpremissa`—facts, rules, notifications, OTP. Here we follow Riverbank—and the real [`Tec0301Pon.PON.Builder`](../../../lib/tec0301_pon/pon/builder.ex)—through the **craft** of deciding when metaprogramming is honest help instead of borrowed time.

Sam from platform security would join later with questions about strings and eval; for now, the team only had copy-paste and a whiteboard. This first chapter anchors the **process**: vocabulary, baseline API, golden expansion, staging, and the social cost of magic.

---

## What Riverbank learned: an internal DSL is still Elixir

An **internal DSL** is not a second language with its own parser—not unless you choose that heavier path (Fowler’s **external** DSL, with lexers and parsers and a standalone toolchain). It is a **disciplined way of writing Elixir**—keyword lists, blocks, aliases—so that **macro expansion** can turn each declaration into ordinary modules and functions. The BEAM still runs normal `def`, `GenServer`, and messages. The compiler simply writes more of the boring parts than you would type.

If you cannot describe what the program does **after** expansion, you are still arguing about requirements. If you *can* describe it, the macro is **mechanical transcription** from the author’s notation into that target code. [`Tec0301Pon.PON.Builder`](../../../lib/tec0301_pon/pon/builder.ex) is exactly that: each `defrule` becomes a small module with `avaliar/1`, `executar/1`, and `start_link/0` wired to [`Regra`](../../../lib/tec0301_pon/pon/regra.ex)—behavior that had to exist in words before anyone said `defmacro`.

Jordan made Maya write that sentence on the whiteboard before they touched macros. It sounded dramatic until rule ten broke again.

---

## From the codebase: what exists without any macro sugar

The umbrella application documents the split explicitly. [`Tec0301Pon`](../../../lib/tec0301_pon.ex) states, in its module doc, that the **core** is `Fato`, `Regra`, and Registry as the notification bus, while the **DSL** is optional—`use Tec0301Pon.PON.Builder` and `defrule`. Hexagonal boundaries live in ports and adapters. Nothing in the language forces you to adopt the macro layer; you can drive the engine with the same processes and messages your DSL will eventually generate.

That matters for Riverbank’s discipline: **semantics first, syntax second.** If `Regra` in **module mode** is unclear, no amount of `quote` will fix the greenhouse.

[`Tec0301Pon.PON.Regra`](../../../lib/tec0301_pon/pon/regra.ex) documents two ways to start a rule process: anonymous functions, or a **module atom** with `avaliar/1` and `executar/1`. The module path exists partly for **hot code swapping**: the GenServer holds an atom pointing at your rule module, so when you load a new version of that module in a release, calls dispatch to fresh named functions instead of stale closures trapped in old funs. The PON series (Part 3) and the Portuguese architecture article [`docs/artigos/02_motor_pon_beam.md`](../../../docs/artigos/02_motor_pon_beam.md) walk through that design motivation in more detail; the takeaway for this DSL track is that **your macro is not allowed to invent new runtime semantics**—it should emit modules that `Regra` already knows how to run.

---

## What the PON series already said (and why we repeat it here)

[Part 3 of the Smart Brewery line](../03_metaprogrammed_dsl_defrule_defpremissa.md) lists the repetitive obligations of a rule in module mode: you need **`avaliar/1`** (when to fire over a `memoria` map), **`executar/1`** (the action), and **`start_link/0`** that calls `Regra.start_link(watched_facts, __MODULE__, ...)`. A premise needs a condition function and wiring to `Premissa.start_link/4`. Copying that shape ten times is how subtle bugs creep in—wrong fact in `watch`, mismatched arity, forgotten `edge_triggered` flag.

The Builder macros **expand at compile time** into nested modules under the **caller’s** namespace (e.g. `MyApp.Rules.Cooling` inside `MyApp.Rules`). At runtime you only start processes; there is **no macro cost** on the notification hot path. That separation—compile-time generation versus runtime message handling—is the standard Elixir pattern behind `quote`, `unquote`, and `__CALLER__`, as the PON post points readers to the official [`Macro`](https://hexdocs.pm/elixir/Macro.html) docs and McCord’s *Metaprogramming Elixir*.

Conceptually, if you write `defrule Example, watch: [:a], when: memoria[:a] == 1, do: :ok` inside `MyApp.Rules`, expansion yields something like a submodule `MyApp.Rules.Example` with the three callbacks and a `start_link/0` that registers with `Regra`. The **actual** generated code uses `var!(memoria)` in the function heads so hygiene does not break spliced AST; Part 6 of this series explains that detail. For Part 1, remember only this: **the sketch in Part 3 is the contract your macro must satisfy** before it deserves to exist.

---

## Worked example: one rule from the greenhouse in the repo

The project ships [`Tec0301Pon.Examples.Estufa.Regras`](../../../lib/tec0301_pon/examples/estufa_regras.ex)—irrigation and safety rules that read like operations manuals but compile into OTP-ready modules. A representative rule watches four facts, combines them in a single `when:` expression, and performs side effects in `do:`: talk to `BombaDeAgua`, `AlarmeIO`, and `Fato.atualizar/2`. After expansion, each `defrule` name becomes a nested module you can start with `start_link/0` alongside its siblings.

Walking that file line by line is a good **pre-macro** exercise: identify what is **domain** (thresholds, pump states) versus **plumbing** (every rule’s `start_link` and callback names). The plumbing is what Riverbank—and this entire series—intends to generate once and reuse everywhere.

---

## Jordan’s notebook: the ritual before the first `defmacro`

They agreed on a ritual—not for ceremony, but because skipping it is how teams end up with magic no one can refactor.

**Vocabulary.** Maya listed nouns and verbs out loud: facts, watches, conditions, actions, alarms. If two engineers could not agree on those words, syntax would not save them. DSL engineering texts (Voelter et al.) treat notation as a product decision: if the team cannot align on vocabulary, the “language” will fork in every pull request.

**One manual rule.** She implemented **one** rule using **only** `Fato` and `Regra` (or the anonymous-function mode if that is easier for a spike), **without** `use Tec0301Pon.PON.Builder`. The umbrella doc already promises that path. The exercise hurts usefully: every line that would copy unchanged into rules two through ten gets circled. Those circles are the ROI story for stand-ups and for your future self when someone asks “why macros?”

**Golden module.** For the worst circle, Jordan insisted on the **exact** module he wished the compiler would emit—real `defmodule`, real `avaliar/1`, real `start_link/0`. They diffed it against Maya’s hand-written version until behavior matched. That file is the specification Part 2 implements with `quote` and `unquote`. If you cannot write the golden module, you do not know what your macro returns.

**Staging boundary.** They marked compile-time data (module names, static option lists, macro options) in green and runtime data (sensor readings, dynamic maps, message payloads) in red. Macros should not smuggle runtime-only values into module attributes without understanding recompilation and deployment implications. Taha’s work on multi-stage programming names that boundary formally; Riverbank named it with markers on a whiteboard.

**Author contract.** They listed what is *illegal*: macros inside runtime functions, contradictory options, `defrule` where the parser cannot see a macro. They decided which mistakes `raise` at **expand** time with a helpful message. That sticky note migrates into `@moduledoc` and into tests (Part 10).

**Testing story.** Before the first macro commit, they agreed how they would know nothing regressed: smoke-compile modules that use the DSL, behavioral tests on `Regra`, and—only where needed—AST inspection. Behavior-first tests survive Elixir version bumps better than golden AST dumps.

---

## The tension that never goes away

Authors want to read the greenhouse in sentences: when these sensors move and this holds, do that. Maintainers want **grep**, tests, and stack traces that open to a real line. Macros sit between those wishes. Used well, they remove noise; used carelessly, they **move** behavior into generated code where IDEs and new hires lose the trail.

Elixir makes macros first-class, but **can ≠ should**. Most libraries should stay **functions, structs, behaviours** until repetition or AST capture clearly wins.

---

## Costs Sam would ask you to write down

Onboarding now includes **your** expansion story, not only Elixir. Tooling may stop at call sites; behavior-first tests age better than brittle AST equality. Debugging wants expansions that map to author lines—not logic hidden in strings unless you invest in diagnostics (Part 8). If the pattern still churns weekly, freeze it in a macro API **after** it stabilizes.

**Anti-patterns the Riverbank team literally wrote on the wall:** starting from `defmacro` before a hand-written target exists; stuffing business rules into the macro file instead of plain modules; generating opaque module names (Part 5); defaulting to `eval` because strings felt easier (Part 8).

---

## When Maya was allowed to say “macro” in a commit message

They reached for `defmacro` when the pattern was **stable**, repeated many times, expressible with **syntax Elixir already parses**, backed by a **thin** layer over an existing API, and paired with a **test story** everyone could name.

They stopped at **`use` + light `import`** when only aliases or hooks were needed. They avoided macros when a function API, data config, or external codegen script stayed clearer.

---

## A footnote for the curious (literature)

Martin Fowler’s *Domain-Specific Languages* (2010) distinguishes **internal** and **external** DSLs and catalogs when fluent APIs pay rent versus when they tax comprehension. Voelter et al.’s *DSL Engineering* (2013) treats DSLs as full lifecycle artifacts: notation, semantics, evolution, and tooling—not a weekend macro spike. Those frames explain why Riverbank’s argument was as much **social** as technical.

Walid Taha’s thesis on **multi-stage programming** (1999) formalizes **staging**: computation that belongs at compile time versus computation that must stay at runtime. Elixir macros are one staging mechanism; OTP processes handling `{:notificacao, ...}` messages are another. Keeping that boundary sharp matches both good DSL practice and the architecture Joe Armstrong described for reliable systems on the BEAM (2003 thesis), later distilled in Cesarini and Thompson’s *Programming Erlang* (2016).

Chris McCord’s *Metaprogramming Elixir* (2015) is the practical bridge from theory to `quote` and `__using__`. Full tables and URLs live in [BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md) alongside the shared [PON bibliography](../../BIBLIOGRAPHY_PON_SERIES.md).

---

## What happens next

Maya opened a branch called `riverbank-dsl-spike`. The first commit would not be a macro at all—only `quote`, `unquote`, and a tiny template that made Jordan’s golden module appear as if the compiler had whispered it into existence. [Part 2](02_ast_essentials_quote_unquote_bind_quoted.md) is that night: the AST they had been holding without knowing its name.

---

## References

- Fowler, M. (2010). *Domain-Specific Languages*. Addison-Wesley. [Overview](https://martinfowler.com/books/dsl.html).
- Voelter, M.; et al. (2013). *DSL Engineering*. [dslbook.org](http://dslbook.org/).
- Taha, W. (1999). *Multi-stage programming: its theory and applications* (PhD thesis).
- Armstrong, J. (2003). *Making reliable distributed systems…* (PhD thesis). [erlang.org](https://www.erlang.org/download/armstrong_thesis_2003.pdf).
- Cesarini, F.; Thompson, S. (2016). *Programming Erlang* (2nd ed.). Pragmatic Bookshelf.
- McCord, C. (2015). *Metaprogramming Elixir*. Pragmatic Bookshelf.
- Elixir [`Macro`](https://hexdocs.pm/elixir/Macro.html).
- [PON Part 3 — metaprogrammed DSL](../03_metaprogrammed_dsl_defrule_defpremissa.md) (domain companion).
- [PT — motor PON na BEAM](../../../docs/artigos/02_motor_pon_beam.md) (deeper historical note on hot swap and closures).

Full tables: [BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md) · [BIBLIOGRAPHY_PON_SERIES.md](../../BIBLIOGRAPHY_PON_SERIES.md).
