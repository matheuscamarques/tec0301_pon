---
title: "Building DSLs in Elixir (Part 9): layered DSLs — premises, aggregate conditions, and real examples"
published: false
description: "Part 9 of 10 — Riverbank adds premises and aggregates; defpremissa and defcondicao mirror Tec0301Pon.PON.Builder. Tour of repo examples."
tags: elixir, metaprogramming, macros, dsl, rules
series: elixir-dsl-building
---

*If this helped you, you can [support the author with a coffee on dev.to](https://dev.to/matheuscamarques/support-with-a-coffee-2oa0).*

# Building DSLs in Elixir (Part 9): layered DSLs — premises, aggregate conditions, and real examples

**Part 9 of 10** — [Index](README.md) · [Part 8](08_eval_strings_vs_quoted_ast_escape_hatch.md) · Next: [Part 10 — The green light test](10_testing_and_inspecting_macros.md)

**Reading time:** long-form draft (~10 min). Target **2,000+ words** per part.

---

The whiteboard looked like a plumbing diagram. Jordan pointed at a repeated fragment: three rules all began with the same temperature inequality. “We are not going to paste that forever,” he said. Maya agreed—but she did not want a **bigger** `defrule`. She wanted a **second sentence** in the same language family: a premise that **derived** `:temp_alta`, then rules that **watched** the derived fact.

That is the story of **layered** macros in [`Tec0301Pon.PON.Builder`](../../../lib/tec0301_pon/pon/builder.ex): **`defrule`** remains the workhorse; **`defpremissa`** and **`defcondicao`** add reusable derived facts and boolean aggregation. Each layer expands to nested modules + `start_link/0`, reusing the same mechanical tools (`quote`, `Module.concat`, `__CALLER__`, `var!`) while delegating runtime to [`Premissa`](../../../lib/tec0301_pon/pon/premissa.ex), [`Condicao`](../../../lib/tec0301_pon/pon/condicao.ex), or [`Regra`](../../../lib/tec0301_pon/pon/regra.ex).

Riverbank’s fictional spike followed the same discipline the repo already encodes.

---

## From the codebase: `@doc` contracts for `defpremissa` / `defcondicao`

Builder’s `@doc` for **`defpremissa`** states the NOP-flavored behavior: watch one or two facts, evaluate `when:`, update the derived fact **only when the boolean changes**, optional `criar_fato: true` to seed `false`. The example mirrors the PON article’s temperature story—authors should read `@doc` as the **canonical** spelling.

**`defcondicao`** documents `merge: :all | :any` (strict AND / OR over watched values) **or** a custom `when:` over `memoria`, plus `derive:` and optional `criar_fato`. The doc example wires `defcondicao` → `defrule` watching the derived aggregate—exactly the pipeline Jordan drew.

Implementation detail you should expect in your own layered DSLs: **`defcondicao`** uses `cond` to reject illegal combinations and to dispatch between `build_defcondicao_merge/6` and `build_defcondicao_when/6`—same “shape dispatch” lessons as Part 7.

---

## Growing from one macro to a family

Find duplication that is **conceptual**, not only textual—repeated `when:` shapes, repeated ANDs over premise facts. Write the **runtime** behavior without macros first. Mirror the successful `defrule` pattern: same name resolution, different callback names and `start_link` targets. **`raise` at expand** when options contradict—Sam still smiles about that from Part 7.

Compose docs as **pipelines**: premise → aggregate condition → rule, not three unrelated spells. Voelter et al. call this **language composition**—notation pieces that **nest** with predictable semantics.

---

## What the PON series already said (composed example)

[Part 3](../03_metaprogrammed_dsl_defrule_defpremissa.md) combines `defpremissa` and `defrule` in one module for a brewery-flavored story. Re-read that block with Parts 4–6 eyes: **`use`** imports macros; **`caller.module`** prefixes nested names; **`var!`** aligns `memoria` inside `condicao/1` and `avaliar/1`. The product post explains **policies**; this serial explains **the compiler’s bookkeeping**.

---

## From the tests: `GrafoPremissaCondicaoRegra`

[`builder_test.exs`](../../../test/tec0301_pon/pon/builder_test.exs) module `GrafoPremissaCondicaoRegra` builds a small graph: two premises, one `defcondicao` with `merge: :all`, then a `defrule` watching the derived aggregate. Tests assert that **propagating facts** through `Fato` eventually fires the rule **via** the composed chain.

That test is the **shortest proof** the layered macros interoperate—more valuable than another paragraph of prose. When Riverbank cloned the pattern, they renamed facts to greenhouse nouns but kept the **topology** identical: premise facts → aggregate → action rule.

---

## Industrial scale: Smart Brewery facts and rules (doc link)

For a longer **industrial** narrative—what facts exist, how premises compose, how rules fan out—read [`docs/smart-brewery-fatos-regras.md`](../../../docs/smart-brewery-fatos-regras.md). It is not a metaprogramming tutorial; it grounds why **layers** exist beyond DRY. Link it from internal wikis when PMs ask “why can’t this be one giant `when:`?”

---

## Walking the repo like a visitor from Riverbank (expanded tour)

**[`alarme_simples_regras.ex`](../../../lib/tec0301_pon/examples/alarme_simples_regras.ex)** — One screen, one breath: a single rule shows the **minimal** `watch` / `when` / `do` triangle. New hires map author lines to `Regra` in under ten minutes.

**[`estufa_regras.ex`](../../../lib/tec0301_pon/examples/estufa_regras.ex)** — Riverbank’s spiritual cousin: irrigation, safety, adapters; `do:` blocks stay imperative Elixir—the macro removed **plumbing**, not **thinking**. Follow one rule from `when:` through adapters to `Fato.atualizar/2` and note how **side effects** stay explicit.

**[`vendas_regras.ex`](../../../lib/tec0301_pon/examples/vendas_regras.ex)** — Shows `|| 0`, `in`, and local bindings inside `do:`; anything legal in a function body survives expansion. If sales domain feels foreign, treat it as a **stress test** for readability.

**[`smart_brewery_regras.ex`](../../../lib/tec0301_pon/examples/smart_brewery_regras.ex)** — Scale: many rules, `edge_triggered`, helper functions referenced inside `when:`—macros should **call out** to ordinary functions when lines grow. This file pairs with the smart-brewery doc above.

**Other examples** — `predio_inteligente_regras`, `mira_alvo_regras`, `portao_eletronico_regras`, `alarme_correlacao_regras`: same Builder, different stories. Skim **one screen each** to see how domains reshape `watch` lists without reshaping the macro machinery.

---

## Layer 1: `defrule` (recap)

Rules **watch** facts, **evaluate** `memoria`, **execute** actions. Parts 2–8 showed how that compiles. Domain vocabulary: [PON Part 3](../03_metaprogrammed_dsl_defrule_defpremissa.md).

---

## Layer 2: `defpremissa` — derived facts

A premise observes sources, evaluates a condition, updates a **derived** fact when truth **changes**—so downstream rules `watch: [:temp_alta]` instead of duplicating `(memoria[:temp_ambiente] || 0) > 30`.

```elixir
defpremissa TempAlta,
  watch: [:temp_ambiente],
  when: (memoria[:temp_ambiente] || 0) > 30,
  derive: :temp_alta,
  criar_fato: true
```

Same nested-module story; runtime partner is `Premissa`, not `Regra`. Expansion uses `condicao(var!(memoria))` callback naming—Part 6’s hygiene story applies unchanged.

---

## Layer 3: `defcondicao` — aggregates

Combine facts with **`merge: :all`** (AND) or **`merge: :any`** (OR), or a custom **`when:`**. The macro forbids **both** `:merge` and `:when`—`ArgumentError` at expansion.

```elixir
defcondicao AlarmeHabilitado,
  watch: [:temp_alta, :umidade_baixa],
  merge: :all,
  derive: :cond_alarme,
  criar_fato: true

defrule DispararAlarme,
  watch: [:cond_alarme],
  when: memoria[:cond_alarme] == true,
  do: ...
```

---

## Design lesson (longer)

Rules **react**. Premises **maintain derived truth**. Conditions **aggregate**. The machinery repeats; only the runtime interpreter changes. When Riverbank drew layers, they also drew **data ownership**: premises own **how** a boolean is computed; conditions own **how** booleans combine; rules own **what** happens when the world matches intent. Confusing those verbs creates DSLs that read like English but execute like mud.

---

## Process / checklist: layering your own DSL

1. **Identify** repeated subexpressions that are **stable boolean** truths.  
2. **Extract** a runtime primitive (`Premissa`-shaped) before macro sugar.  
3. **Generate** submodules with the same `Module.concat` pattern as `defrule`.  
4. **Document** the pipeline with one worked example in `@moduledoc`.  
5. **Test** composition with a tiny graph test like `GrafoPremissaCondicaoRegra`.  
6. **Review** for cycles: derived facts must not secretly depend on themselves.

---

## Screen-by-screen: `estufa_regras.ex` as a teaching script

**Screen 1 — imports and module:** note `use Tec0301Pon.PON.Builder` and the parent module name; predict generated children prefixes.  
**Screen 2 — first `defrule`:** underline `watch` atoms; map each to a `Fato` name your app will register.  
**Screen 3 — `when:` clause:** identify pure boolean tests; call out `|| 0` guards for missing keys.  
**Screen 4 — `do:` block:** list side effects (adapters, `Fato.atualizar/2`); discuss idempotence if notifications repeat.  
**Screen 5 — supervision:** where `start_link/0` for each child is invoked in your app—DSL does not remove this step.

Jordan turned that outline into a **lunch-and-learn**; Maya turned it into **onboarding issues** in their tracker.

---

## Failure modes: premises vs rules

Premises that **flap** (boolean oscillates rapidly) can churn derived facts and downstream notifications. Rules with `edge_triggered` damp some storms; premises do not magically debounce. When designing layers, ask **how often** the source fact updates and whether you need **hysteresis** in ordinary Elixir functions the premise calls.

---

## Hexagonal reminder (from `Tec0301Pon` moduledoc)

[`Tec0301Pon`](../../../lib/tec0301_pon.ex) lists ports and adapters beside PON core and DSL. Layered macros should **not** import adapter modules into the DSL module globally—keep adapters inside `do:` blocks or instigations so tests can swap them. The DSL is **notation** for processes; hex boundaries stay explicit.

---

## Comparison table: premise vs condition vs rule

| Layer | Watches | Computes | Updates / acts | Typical runtime |
| --- | --- | --- | --- | --- |
| Premise | Source facts | Boolean condition on `memoria` | Derived fact on **boolean change** | `Premissa` |
| Condition | Usually premise outputs | AND/OR or custom combine | Derived aggregate fact | `Condicao` |
| Rule | Mixed facts | Boolean `when:` | Side effects / instigations | `Regra` |

Use the table in design reviews to ensure **verbs** match **process types**. Mixing concerns—say, putting actuator I/O inside a premise—violates the table even if it compiles.

---

## Boot order caveat

Premises and conditions must **`start_link`** before rules that depend on their derived facts **if** you require initial `false`/`true` seeding semantics. Riverbank documented bootstrap sequences in `Application` alongside the PON graph diagram. Macros do not solve ordering; **supervision trees** do.

---

## The last gate before merge

Jordan tapped the CI board. “We need proof the **language** compiles and the **greenhouse** behaves.” Maya queued the smoke tests and expansion probes. [Part 10](10_testing_and_inspecting_macros.md) closes the serial—Riverbank’s branch finally meets `main`.

---

## One-paragraph tour each: `vendas`, `predio`, `portao`

**Vendas** rules stress-test readable arithmetic and membership checks—good for teaching sales engineers that DSLs are still Elixir. **Prédio inteligente** layers building automation vocabulary; use it when audiences think in floors and schedules, not moisture. **Portão eletrônico** is a compact narrative about access control—pair with Sam’s security hat from Part 8 when discussing external inputs. None of these files introduce new macros; they prove **notation stability** across domains.

**Mira alvo** and **alarme correlação** reward readers who want cross-sensor logic without immediately jumping to industrial brewery scale—use them in workshops when Smart Brewery feels overwhelming.

---

## Closing metaphor Riverbank kept

Maya called premises **adjectives**, conditions **conjunctions**, and rules **verbs**. Grammar is not perfect—`Condicao` with custom `when:` is more than AND/OR—but the metaphor helped PMs read files without knowing OTP. Jordan winced at poetry in engineering docs; Sam kept it because adoption rose.

## Doc sync checklist when adding `defcondicao`

Update: Builder `@moduledoc`, PON Part 3 cross-links, this series Part 9, internal wiki graph, **`builder_test.exs`** graph module, and any ASCII diagram in `docs/smart-brewery-fatos-regras.md` if brewery facts change. Missing one surface is how divergent dialects appear across teams.

## Premise arity and sensor fusion

When two physical sensors feed one premise (`watch: [:a, :b]`), document **which** failure mode you want: missing key vs stale value. Builder’s premise docs mention one or two facts—stay within that contract or add a new runtime primitive instead of overloading `defpremissa` with silent semantics. Riverbank learned that lesson when a “temporary” third watch snuck into a fork and broke notification batching assumptions.

---

## A footnote for the curious (literature)

**Language composition** is central to DSL engineering (Voelter et al., 2013; Fowler, 2010). NOP/PON literature (Simão et al., 2013) contextualizes reactive facts and rules—see [PON bibliography](../../BIBLIOGRAPHY_PON_SERIES.md). Hexagonal boundaries (Cockburn; Fowler summary in PON bib) mirror separating DSL surface from OTP cores—**ports** for adapters appear in [`Tec0301Pon`](../../../lib/tec0301_pon.ex) moduledoc as the wider architecture.

Composition also raises **staging** questions again (Taha, 1999): premises compile to modules at **stage 1**; their **runtime** updates happen continuously—do not smuggle compile-only config into premise `when:` clauses without understanding recompilation. [BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md).

---

## See also (cross-links)

Layered macros assume you understood Parts [3](03_use_pattern___using__.md) (`use`), [4](04_generating_modules_names_from_macro_arguments.md)–[5](05___CALLER___and_lexical_module_context.md) (nesting), [6](06_hygiene_and_var_bang_injecting_memoria_safely.md) (`var!` in `condicao`/`combine`), and [7](07_multi_head_macros_and_alternative_shapes.md) (`defcondicao` errors). Part [8](08_eval_strings_vs_quoted_ast_escape_hatch.md) matters if anyone tries string `when:` in premises—Builder discourages it; your fork should too. Part [10](10_testing_and_inspecting_macros.md) points at `GrafoPremissaCondicaoRegra` as the graph smoke test. Run that test after **any** change to premise batching.

When onboarding solution architects, pair this part with a **live** `iex` session updating facts—people grok layers faster when they see boolean flips propagate.

End workshops by asking teams to **sketch** their own three-layer graph on paper before touching code—misdrawn edges predict bugs cheaper than missed tests.

Keep those sketches in the ticket; they age better than Slack threads.

---

## References

- Voelter, M.; et al. (2013). *DSL Engineering*. [dslbook.org](http://dslbook.org/).
- Fowler, M. (2010). *Domain-Specific Languages*. Addison-Wesley.
- Simão, J. M.; et al. (2013). *NOP and Imperative Paradigm: A Comparative Study*. [IJSEA / SCIRP](https://www.scirp.org/journal/paperinformation?paperid=19842).
- Cockburn, A. (2005); Fowler, M. (2015) — [PON bibliography](../../BIBLIOGRAPHY_PON_SERIES.md).
- Elixir [`Macro`](https://hexdocs.pm/elixir/Macro.html).
- [`Builder`](../../../lib/tec0301_pon/pon/builder.ex); [`smart-brewery-fatos-regras.md`](../../../docs/smart-brewery-fatos-regras.md); [`builder_test.exs`](../../../test/tec0301_pon/pon/builder_test.exs).

[BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md) · [BIBLIOGRAPHY_PON_SERIES.md](../../BIBLIOGRAPHY_PON_SERIES.md).
