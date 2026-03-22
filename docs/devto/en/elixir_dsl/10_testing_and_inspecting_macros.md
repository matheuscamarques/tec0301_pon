---
title: "Building DSLs in Elixir (Part 10): testing and inspecting macros"
published: false
description: "Part 10 of 10 — Riverbank’s DSL meets CI: smoke compile, behavior tests, Macro.expand. Epilogue of the serial; PON series continues the product story."
tags: elixir, metaprogramming, macros, dsl, testing
series: elixir-dsl-building
---

*If this helped you, you can [support the author with a coffee on dev.to](https://dev.to/matheuscamarques/support-with-a-coffee-2oa0).*

# Building DSLs in Elixir (Part 10): testing and inspecting macros

**Part 10 of 10** — [Index](README.md) · [Part 9](09_layered_dsls_premises_conditions_examples.md)

**Reading time:** long-form draft (~10 min). Target **2,000+ words** per part.

---

The pipeline went green at 4:47 p.m.—not because the greenhouse was simple, but because Maya had finally **named** what they were testing. Illegal programs had to **fail at expand** with messages Sam could grep. Legal programs had to **compile** every macro head Jordan cared about. Running code had to match the semantics they wrote by hand in Part 1.

This repository often leans on **integration** paths: example modules that compile, processes started under supervision. That is a valid trade. When macros bite, Elixir still offers [`Macro.expand/2`](https://hexdocs.pm/elixir/Macro.html#expand/2), [`Macro.expand_once/2`](https://hexdocs.pm/elixir/Macro.html#expand_once/2), and [`Code.compile_string/2`](https://hexdocs.pm/elixir/Code.html#compile_string/2)—the flashlight under the floorboards.

Riverbank used all three before they trusted the merge button.

---

## Layered testing (the order that survived review)

**Smoke compile** — Tiny modules that `use` the DSL and exercise each macro **head** and option. One test file or `Code.compile_string/2` catches missing imports, arity mistakes, and broken `quote` without booting the world.

**Behavior on generated modules** — Start `start_link` under a test supervisor; assert messages and side effects. Matches production and survives AST metadata tweaks between Elixir patches.

**Selective AST asserts** — For gnarly splices, `Macro.expand_once/2` checks **invariants** (module name, `def avaliar/1` exists). Never snapshot entire trees unless you enjoy churn.

**Regression on error text** — If authors rely on `raise ArgumentError, "defcondicao: ..."`, pin those strings so refactors do not silently worsen UX.

**Doc examples** — Doctest or compile excerpts so `@moduledoc` stays honest as the language moves.

**Statistics and introspection** — When available, assert on domain counters (e.g. [`Regra.estatisticas/1`](../../../lib/tec0301_pon/pon/regra.ex)) to catch accidental double-fires after macro changes.

---

## From the codebase: patterns in `builder_test.exs`

[`test/tec0301_pon/pon/builder_test.exs`](../../../test/tec0301_pon/pon/builder_test.exs) is the **practical textbook** for testing a macro-heavy DSL without going mad:

- **`RegrasDeTeste`** — AST `when:` + block `do:` + registered receiver process; asserts `executar` side effects.  
- **`RegrasWhenString`** — string `when:` path; proves eval rules compile and fire.  
- **`RegrasInstigations`** — `instigations:` branch; asserts `Task` fan-out reaches helpers.  
- **`PremissasDeTeste` / `PremissasSemCriar`** — `criar_fato` true vs false semantics.  
- **`RegraObservaDerivado` / `DuasPremissas`** — premises feeding rules.  
- **`GrafoPremissaCondicaoRegra`** — full layered graph.

When Riverbank cloned the suite, they kept the **same process registry namespacing** tricks (`Process.register/2` receivers) so tests stayed deterministic. They added **tags** (`@tag :dsl_smoke`) for the fast subset in CI.

---

## `Macro.expand_once/2` walkthrough (step by step)

Goal: separate “macro returned garbage” from “call site parsed oddly.”

1. In `iex`, `import Macro` if needed; build `quoted = quote do: Module.defrule(...)` **or** quote a call to your DSL—often easiest inside a `defmodule` in a test file.  
2. Build an env: `env = __ENV__` in the **same** module context if possible; for pure unit tests, construct `%Macro.Env{module: MyTest.Module, file: "test/...", line: 1, ...}` carefully—most folks test expansion **inside** a real module to avoid incomplete envs.  
3. Run `Macro.expand_once(quoted, env)` and `IO.inspect(..., pretty: true)`.  
4. Check **invariants**: presence of `:defmodule`, correct alias, `unquote` resolved away one level.  
5. If stuck, `Macro.expand/2` repeatedly until stable—beware infinite macro loops; cap iterations mentally.

**Teaching note:** `expand_once` is also how Part 2’s `double_ast/1` exercise clicks for newcomers.

---

## Smoke compile with `Code.compile_string/2`

```elixir
Code.compile_string("""
defmodule SmokeDSL do
  use Tec0301Pon.PON.Builder
  defrule R, watch: [:x], when: memoria[:x] == 1, do: :ok
end
""")
```

Coarse, fast, cruel in the best way: if expansion breaks, compilation fails loudly—ideal first CI guard for a new DSL. Riverbank parameterized the string with heredocs for each **macro head** they supported (string `when:`, `edge_triggered`, `instigations`). Failures printed **compiler errors** developers already know how to read.

---

## CI story: the week the cache lied

Jordan’s CI war story: a stale `_build` masked a macro change until a clean runner failed. They added **`mix clean`** to weekly nightly jobs—not for every PR, but enough to catch “works on my laptop” macro drift. Sam added **deterministic seeds** for any property tests touching generated modules. The moral: **macro suites love clean builds** more than average application code.

---

## Assert on structure without painting yourself into a corner

Prefer **invariants** over full AST equality. Strip `line`/`file` metadata in helpers if you compare trees; `Macro.to_string/1` helps humans diff expansions—know it is lossy and not stable across Elixir versions.

**Good invariant examples:** generated module name equals `Module.concat([parent, :RuleX])`; `avaliar/1` arity is 1; `start_link/0` exists.

**Bad invariant examples:** exact metadata tuples; full pretty-printed strings as golden files.

---

## What to test where (table + prose)

| Layer | Suggestion |
| --- | --- |
| Macro expansion | Smoke compile or selective AST asserts |
| Generated modules | `start_link` under test supervision; assert behavior |
| Domain rules | `Regra` / `Fato` via plain APIs when possible |

Use **domain APIs** when you can: if `Fato.atualizar/2` and message flows are trustworthy, macro tests should prove **wiring**, not re-prove PON theory. Meszaros (2007) would call this **layering test doubles** at process boundaries—use real processes for integration, fake clocks only when time matters.

---

## Async tests, race windows, and `assert_receive`

[`builder_test.exs`](../../../test/tec0301_pon/pon/builder_test.exs) registers named processes and uses `assert_receive` patterns. Riverbank copied that style, then hit flakes when CI machines slowed. Fixes: increase timeouts **only** in tagged slow tests; use **`Process.alive?/1` guards** sparingly; prefer **`Regra.estatisticas/1`** when you need deterministic counts instead of message races.

---

## LiveView, Phoenix, and compile-time modules

Phoenix LiveView files are modules too—putting `defrule` in the wrong file still expands, but **supervision** rarely belongs next to UI. Riverbank’s guideline: **keep DSL modules separate** from LiveViews; call contexts or rule supervisors from `Application`. Tests should compile DSL modules in `test/support` or dedicated fixtures, not inside every LiveView test module.

---

## `mix test` slicing for macro work

Use `mix test test/path/to/builder_test.exs` while iterating. When adding a new macro head, **append** a focused test module at the bottom of the file (matching local style) rather than muting unrelated cases—[`builder_test.exs`](../../../test/tec0301_pon/pon/builder_test.exs) demonstrates multiple inner `defmodule` fixtures in one file. If compile times hurt, split fixtures—but keep **one** place greppable for DSL smoke tests.

---

## When to delete an AST golden test

Riverbank deleted two golden AST tests after Elixir bumped metadata. Jordan’s rule: **delete** golden trees that churn on upgrades; **replace** with invariant checks or behavior tests. Keep **one** archived expansion in an internal gist if onboarding needs a Rosetta stone—do not block CI on it.

---

## Pseudocode: invariant test without brittle AST equality

```elixir
expanded =
  quote do
    use Tec0301Pon.PON.Builder
    defrule Z, watch: [:z], when: memoria[:z] == 1, do: :ok
  end
  |> Macro.expand_once(__ENV__)

assert {:defmodule, _, _} = expanded
# walk with Macro.prewalk: ensure a child defmodule name ends with .Z
# assert function exports [:avaliar, :executar, :start_link] in the inner block
```

Exact code varies with Elixir version—**treat this as conceptual**. The point: **walk** the tree for **properties**, not **full equality**.

---

## Doc-driven testing

Riverbank extracted `@moduledoc` examples into **`test/dsl_doc_examples_test.exs`** with `Code.compile_string/2`. When docs drift, CI fails—authors learn to update docs and tests together. Start with **one** example per macro; grow slowly.

---

## CI matrix snippet (conceptual)

Run `mix test` on Elixir **current** and **previous minor** if your macros are central. Run a **`MIX_ENV=test` compile** of all umbrella children. Cache `deps` but **do not** cache `_build` across Elixir versions for macro-heavy apps if you observed metadata drift. Parallelize smoke compiles only when each test file `uses` unique module names—anonymous collisions happen if you `compile_string` the same module name twice without isolation.

---

## Observability in tests

When a macro test fails intermittently, capture **`Regra.estatisticas/1`** before asserting messages—distinguishes “never ran” from “ran twice.” Riverbank tied those stats into ExUnit’s `:telemetry` events in dev for a week to learn baseline distributions.

---

## Flaky registry names in tests

If two tests register the same `Process.register/2` name, order-dependent failures follow. Namespace receiver names with **`:"#{test_module}_recv"`** or use `unique_integer/1` suffixes in setup. [`builder_test.exs`](../../../test/tec0301_pon/pon/builder_test.exs) uses fixed atoms for clarity; smaller suites can be stricter—large suites should randomize.

---

## ExUnit tags for macro suites

Tag slow expansion probes `@tag timeout: 120_000` only on those tests; keep the default fast for day-to-day `mix test`. Use `@moduletag :capture_log` when tests intentionally trigger eval warnings (string rules) so CI logs stay parseable.

---

## Retro questions after shipping a DSL

Did expansion errors read better or worse than hand-written modules? Did onboarding time drop? Did CI catch a macro regression before prod? Did anyone use `var!` in author code against policy? Riverbank answered these quarterly; answers steered Parts 8–10 priorities in this serial.

## Fixture modules: naming and isolation

When generating test-only rule modules, prefix with `Test.Fixtures.` or similar so they never collide with production namespaces in large umbrellas. Use **`@moduletag :async false`** when fixtures register global names. If you must share fixtures across files, move them to `test/support/` and `import` only in tagged cases—avoid compiling the same `defmodule` twice with different bodies.

## Borrowing from property-based testing (light touch)

A few teams used StreamData to generate **random `watch` lists** and **random boolean maps** for `avaliar/1`—not to prove correctness of business rules, but to prove **macro-generated modules don’t crash** on missing keys when using `|| false` patterns. Start small: ten thousand iterations in a nightly job, not every PR.

## Merge queue discipline

Macro PRs skipped “auto-merge” until smoke DSL tests passed on **two** OS images in CI—Linux was enough for BEAM, but path separators in `caller.file` assertions once differed on a contributor laptop. Riverbank standardized on Linux runners for authoritative green, macOS optional advisory.

## Handoff doc template

When Maya rotated off the DSL team, she left a one-pager: **macro entry points**, **files you must edit together**, **tests you must run**, **known sharp edges** (`var!`, string `when:`), **link to Part 10**. The template lived beside `mix.exs`. New maintainers reported **time-to-first-merge** dropped two days on average—cheap documentation win.

---

## Epilogue: Riverbank after the serial

Maya closed the laptop. The humidity alarms were still quiet—now for the right reasons. The team had not invented a new runtime; they had **taught the compiler** to write the boring modules so humans could argue about **policies**, not parentheses.

This **Building DSLs in Elixir** serial used [`Tec0301Pon.PON.Builder`](../../../lib/tec0301_pon/pon/builder.ex) as the honest reference implementation. For the **notification-oriented product** narrative—the brewery, the mesh, the twelve-part arc—continue with the [PON / Smart Brewery series](../01_pon_in_elixir_why_beam.md).

---

## A footnote for the curious (literature)

McCord (2015) pairs **expansion** tests with **behavior** tests—macros are implementation; generated modules are product. Meszaros (2007) layers suites and doubles—**process boundaries** beat brittle tree equality when metadata drifts. Parr (2010) nudges invariant checks on tree walkers—your `Macro.prewalk/3` hygiene checks belong in advanced suites, not every PR.

Fowler (2010) reminds us tests are part of **DSL usability**—if authors fear breaking the language, they stop using it. Voelter et al. (2013) include regression strategies for evolving notations. Full rows: [BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md).

---

## See also (full serial map)

Return to [Part 1](01_when_not_to_reach_for_macros.md) for **when not to macro**; [Part 2](02_ast_essentials_quote_unquote_bind_quoted.md) for **templates**; [Parts 4–5](04_generating_modules_names_from_macro_arguments.md) for **names**; [Part 6](06_hygiene_and_var_bang_injecting_memoria_safely.md) for **`var!`**; [Part 7](07_multi_head_macros_and_alternative_shapes.md) for **variants**; [Part 8](08_eval_strings_vs_quoted_ast_escape_hatch.md) for **eval policy**; [Part 9](09_layered_dsls_premises_conditions_examples.md) for **composition**. Keep [the index](README.md) and [BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md) beside this epilogue. Re-run smoke compiles after every Elixir minor upgrade.

Archive one **green** CI log per release with macro test timings—when slowdowns appear, you will know whether to blame compilation or runtime fixtures.

Name saved logs with **git SHA** and Elixir/OTP versions so comparisons stay honest across months.

If timings jump without code changes, suspect runner contention—not macro malice.

Correlate jumps with CI provider incident pages before opening compiler bugs.

---

## References

- Elixir [`Macro.expand/2`](https://hexdocs.pm/elixir/Macro.html#expand/2), [`Macro.expand_once/2`](https://hexdocs.pm/elixir/Macro.html#expand_once/2), [`Code.compile_string/2`](https://hexdocs.pm/elixir/Code.html#compile_string/2).
- McCord, C. (2015). *Metaprogramming Elixir*. Pragmatic Bookshelf.
- Meszaros, G. (2007). *xUnit Test Patterns*. Addison-Wesley. [xunitpatterns.com](http://xunitpatterns.com/).
- Parr, T. (2010). *Language Implementation Patterns*.
- [`builder_test.exs`](../../../test/tec0301_pon/pon/builder_test.exs).

[BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md) · [BIBLIOGRAPHY_PON_SERIES.md](../../BIBLIOGRAPHY_PON_SERIES.md).
