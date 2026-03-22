---
title: "Building DSLs in Elixir (Part 7): multi-head macros and alternative shapes"
published: false
description: "Part 7 of 10 — Sam wants edge_triggered and alternate bodies; Maya splits defmacro heads and case acao like Tec0301Pon.PON.Builder."
tags: elixir, metaprogramming, macros, dsl
series: elixir-dsl-building
---

*If this helped you, you can [support the author with a coffee on dev.to](https://dev.to/matheuscamarques/support-with-a-coffee-2oa0).*

# Building DSLs in Elixir (Part 7): multi-head macros and alternative shapes

**Part 7 of 10** — [Index](README.md) · [Part 6](06_hygiene_and_var_bang_injecting_memoria_safely.md) · Next: [Part 8 — Sam reads the security section](08_eval_strings_vs_quoted_ast_escape_hatch.md)

**Reading time:** long-form draft (~10 min). Target **2,000+ words** per part.

---

Sam—wearing the product hat that week—did not ask for a second DSL, only for **two ways** the same sentence could end. Ops needed a rule that fired **once on the rising edge** of a fault, not on every notification while the fault stayed true. Another team wanted **`instigations`**—MFA tuples spawned as tasks—instead of a fat `do:` block on the hot path.

Maya’s first instinct was a single macro with a forest of `if`s on AST. Jordan suggested something blunter: **let the parser help**. If Elixir can distinguish call shapes at the surface, use **multiple `defmacro` clauses** and guards. If the shape is the same but the **`do:`** subtree differs, branch with **`case`** inside one `build_*` helper—then share the outer `defmodule` template.

That is exactly how [`defrule`](../../../lib/tec0301_pon/pon/builder.ex) reads in production: four heads for string vs AST `when:` and optional `edge_triggered`; inner `case acao` for instigations vs block.

---

## From the codebase: four heads, one shared story

Open [`builder.ex`](../../../lib/tec0301_pon/pon/builder.ex) and search for `defmacro defrule`. You will see four clauses:

1. `when:` is a **binary** → `build_defrule_string(..., edge_triggered? = false)`  
2. `when:` binary + **`edge_triggered:`** → `build_defrule_string(..., edge?)`  
3. `when:` is normal AST → `build_defrule_ast(..., false)`  
4. AST + **`edge_triggered:`** → `build_defrule_ast(..., edge?)`

The guard `when is_binary(condicao)` is the **entire** reason the compiler can pick the string path without runtime `is_binary/1` inside a single fat macro. Elixir’s pattern matching on macro heads is your friend: **syntax-level dispatch** stays readable in code review and in stack traces.

**Design lesson:** when a new option changes **only data** passed to `Regra.start_link/3`—like `edge_triggered`—you often **do not** need a new `defmacro` head; you add a keyword to existing heads and `unquote` the boolean into `start_link_impl`. When a new option changes **how `when:` is represented**—AST vs string—you almost always need a **separate head** or a guard, because the parser and author ergonomics diverge.

---

## Branching on `do:` — block vs `instigations:`

Inside `build_defrule_ast/6`, `acao` is either a **block AST** or `[instigations: list]`. The `case` builds different `executar` bodies:

- **Instigations:** `_ = var!(memoria)` then `for {mod, fun, args} <- unquote(instigation_list), do: Task.start(mod, fun, args)`  
- **Block:** `var!(memoria)` then `unquote(acao)`

…and different `start_link_impl` fragments, because `Regra.start_link/3` accepts `instigation_list:` only when needed.

The outer story—`defmodule unquote(modulo)`, `avaliar`, `executar`, `start_link`—stays **one** template. Riverbank copied that structure for their own DSL: **variant logic returns quoted fragments**, **shell logic assembles fragments**. If you inline everything into one `quote`, you will fear your own PRs within a month.

---

## From the test suite: `RegrasInstigations`

[`test/tec0301_pon/pon/builder_test.exs`](../../../test/tec0301_pon/pon/builder_test.exs) defines `RegrasInstigations` with a rule that uses **`do: [instigations: [{Module, :fun, []}]]`**. The test registers receivers, starts the generated `start_link/0`, pushes fact values through `Fato`, and asserts the instigation fired. That module is the **minimal executable spec** for the instigation branch—shorter than prose, harder to lie.

When Maya onboarded engineers, she assigned “read `RegrasInstigations` and narrate the data flow” before letting them edit `build_defrule_ast/6`. If they could not name which process runs `executar/1` and which process runs `InstigationHelper.notify/0`, they were not ready to patch Task spawning.

---

## Worked example: `edge_triggered` in Smart Brewery

[`smart_brewery_regras.ex`](../../../lib/tec0301_pon/examples/smart_brewery_regras.ex) includes `RegraProtecaoMoinho` with **`edge_triggered: true`**. The PON [Part 3](../03_metaprogrammed_dsl_defrule_defpremissa.md) explains the semantics: [`Regra`](../../../lib/tec0301_pon/pon/regra.ex) executes the action on **false → true** transitions of the condition, not on every notification while the condition stays true. That matters when notifications arrive in bursts from the mesh—without edge triggering, a safety rule could spam actuators or logs.

In Builder, `edge_triggered` is **not** a separate macro; it is **data** threaded into `start_link`. Maya’s whiteboard note: **“If the AST shape is identical, prefer passing flags; if the author writes different syntax, prefer new heads.”** Sam’s edge case was a flag; Ops’ string rules (Part 8) were a new head.

---

## `defcondicao` and compile-time `raise`

Part 7 is not only about `defrule`. [`defcondicao`](../../../lib/tec0301_pon/pon/builder.ex) uses a `cond` to reject **both** `:merge` and `:when`:

```elixir
Keyword.has_key?(opts, :when) and Keyword.has_key?(opts, :merge) ->
  raise ArgumentError, "defcondicao: use either :merge or :when, not both"
```

Sam smiled when that landed: **illegal combinations die in CI**, not in production, and the message tells authors exactly how to fix the call. Voelter-style DSL discipline treats **good errors** as part of the language product. When Riverbank added their own aggregate macro, they copied the pattern: **detect contradiction at expansion**, **name the legal shapes** in the string.

---

## What the PON series already said (options recap)

[Part 3](../03_metaprogrammed_dsl_defrule_defpremissa.md) lists options worth knowing: `edge_triggered: true`, `do: [instigations: ...]`, and string `when:` with warnings. This part is the **implementation** companion: **where** those options become different `defmacro` heads or different `case` branches, and **why** that split keeps the compiler and reviewers sane.

---

## Process / checklist: adding a variant to your macro

1. **Write the call** you want in a scratch module; capture `quote do: ...` for the macro arguments.  
2. Ask: does the **surface syntax** differ enough for a new `defmacro` head? If yes, add a clause with guards.  
3. If syntax matches but **inner AST** differs, extend `case` in the builder—keep returning parallel `{fragment_a, fragment_b}` tuples.  
4. **Factor** the outer `defmodule` shell into one place; never copy-paste the shell per variant.  
5. Add a **tiny compile module** in `test/` that uses the new shape (Part 10).  
6. If runtime semantics change, update `@moduledoc` and link to [`Regra` docs](../../../lib/tec0301_pon/pon/regra.ex).

---

## Anti-pattern: the mega-macro with runtime `Macro.escape/2` soup

When a variant explosion hits, teams sometimes centralize on one head that pattern-matches **everything** and calls helper functions that return **runtime** values escaped into AST at the last second. It can work—it is also how you lose reviewers. Riverbank’s rule of thumb: if you need more than **two** levels of `case`/`cond` inside a builder, extract **named builder functions** (`build_action_instigations/2`, `build_action_block/2`) and keep each under a screen of code. Builder follows that readability curve; steal it.

---

## Refactoring journal: extracting a shared template

Maya’s team twice refactored Riverbank DSL internals. The winning approach matched Part 2: **one outer `quote`**, **multiple inner quoted fragments** assembled by pure functions that take **only** data (`fatos`, `condicao`, `acao`, `caller`, flags). Tests targeted those pure functions with **minimal** env structs where possible—`Module.concat` tests did not need a full `%Macro.Env{}`.

---

## Interview questions Riverbank actually used

- “Why four `defmacro` heads for `defrule` instead of one?”  
- “Where does `edge_triggered` live in the generated code?”  
- “How would you add `debounce_ms:` without breaking existing rules?”  

Strong answers referenced **parser-visible shape** vs **runtime options** and pointed at `case acao` symmetry.

---

## Narrated flowchart (textual) for a `defrule` call

Author types `defrule R, watch: [:a], when: expr, do: body` inside `Parent`. Compiler expands `use` imports. The `defrule` macro head matches AST `when:`. `build_defrule_ast/6` computes `name_atoms` → `Module.concat([Parent, :R])`. `case acao` selects instigation vs block quotes. Outer `quote` returns `defmodule Parent.R` with `avaliar`, `executar`, `start_link`. Compiler compiles the child module. At runtime, `Application` starts `Parent.R.start_link/0`, which calls `Regra.start_link([:a], Parent.R, ...)`. Notifications flow; `avaliar` runs; maybe `executar` runs. **No macro code** runs on the hot path.

When Sam asked “where is the cost?” Maya pointed at **compile time** and **developer attention**, not request latency.

---

## When *not* to add another head

If two call shapes differ only by **optional keyword** with a default, prefer **one** head and `Keyword.get(opts, :edge_triggered, false)` inside the builder—*if* the parser still sees the same surface form. Elixir keyword order and presence can make this subtle; when in doubt, write both call sites in scratch files and compare `quote` output.

---

## Dispatch shape mirrors Erlang clause selection

Cesarini & Thompson describe **pattern matching** as the organizing principle of Erlang APIs—first match wins, guards refine. Multi-head macros echo that at compile time: the **first matching head** expands the call. Sum-type thinking helps too: `do:` is either **block** or **instigations list**; model it with `case acao`, not with `is_list` alone (keyword AST is also a list).

---

## Takeaway Maya pinned next to Part 2’s loop

**Multiple heads** when **syntax** differs. **`case` on AST** when the first argument matches but inner forms diverge. **Flags** when semantics tweak runtime options without changing the author’s surface form.

---

## A footnote for the curious (literature)

Dispatch on **shape** mirrors Erlang-style clause selection (Cesarini & Thompson, 2016). Sum-type thinking—`do:` as either block or instigations—matches `case acao`. Compile-time `raise` on illegal option pairs is Voelter-style DSL discipline (2013). Multi-stage boundaries (Taha, 1999) appear when you choose **which** variants exist at expansion time versus **which** flags are mere data for runtime—both are “stages,” but only one belongs in the macro head list.

McCord’s *Metaprogramming Elixir* shows multi-head macros in practical libraries; compare Phoenix’s `schema` macros and Ecto’s changeset helpers mentally—not for copying their internals, but to see **clause count** as a complexity metric. Full citations: [BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md).

---

## Sam’s next question landed heavier

“What if the condition lives in a **database string**?” Jordan opened a security bookmark. Maya swallowed. [Part 8](08_eval_strings_vs_quoted_ast_escape_hatch.md) is that meeting.

---

## See also (cross-links)

Multi-head macros sit **after** naming (`Module.concat`, `__CALLER__`) and **before** eval policy: changing heads without revisiting Part [4](04_generating_modules_names_from_macro_arguments.md)–[6](06_hygiene_and_var_bang_injecting_memoria_safely.md) risks fixing syntax while breaking namespaces or hygiene. Part [9](09_layered_dsls_premises_conditions_examples.md) repeats the same head/`case` patterns for `defpremissa` / `defcondicao`. Part [10](10_testing_and_inspecting_macros.md) should list **which** heads your smoke compile covers—explicitly, in checklist form.

---

## Appendix: how to read `defrule` clauses in order

Open [`builder.ex`](../../../lib/tec0301_pon/pon/builder.ex) and scroll the four `defmacro defrule` heads in sequence. Read them as **decision table rows**: columns are `when` shape (binary vs AST), `edge_triggered` present or absent, and target builder (`build_defrule_string` vs `build_defrule_ast`). Newcomers who skim only the first head miss half the language. Maya printed the table in the internal wiki and linked the raw lines on GitHub—reducing “why does my string rule compile differently?” tickets.

When you add a fifth concern—say `async: true` for actions—first ask whether it changes **AST shape** or only **options** passed to `Regra.start_link/3`. That single question prevents both under-engineering (missing head) and over-engineering (duplicate module templates).

---

## Pair-programming script (90 minutes)

Minute 0–15: read four heads aloud. Minute 15–35: walk `case acao` in `build_defrule_ast/6` on the projector. Minute 35–55: open `RegrasInstigations` in tests and narrate the mailbox. Minute 55–75: change a toy rule to `edge_triggered: true` and predict stats. Minute 75–90: write the retro note “what broke if we merged heads?”—team keeps the note for the next hiring loop.

---

## Telemetry and variant selection (advanced)

If you need metrics per **rule flavor** (instigation vs block, string vs AST), add **compile-time** module attributes set inside the quoted template, e.g. `@rule_kind :instigations`, and read them in `c:telemetry` handlers attached in `Application.start/2`. Do not branch on strings at runtime to guess flavor—encode the knowledge **once** when generating modules.

---

## Budgeting complexity: heads vs options

Riverbank capped **`defmacro` heads at six** for any single macro name—arbitrary but useful. Beyond six, they forced a redesign: either a **builder function** with options map, or splitting the DSL into two macros (`defrule` vs `defrule_from_string`) even if implementation shared code. The cap prevented “match-all” heads that nobody could explain in onboarding. Builder’s four heads sit comfortably under that ceiling; your fork may differ—document the ceiling in `AGENTS.md` or internal RFCs.

Jordan added that **every** new head requires an entry in the internal “macro decision log”—one paragraph: problem, rejected alternatives, chosen shape. The log prevented re-debating solved arguments every year.

---

## References

- Elixir [`defmacro`](https://hexdocs.pm/elixir/Kernel.html#defmacro/2).
- Cesarini, F.; Thompson, S. (2016). *Programming Erlang* (2nd ed.).
- McCord, C. (2015). *Metaprogramming Elixir*.
- Voelter, M.; et al. (2013). *DSL Engineering*.
- [`Tec0301Pon.PON.Builder`](../../../lib/tec0301_pon/pon/builder.ex); [`builder_test.exs`](../../../test/tec0301_pon/pon/builder_test.exs).
- [PON Part 3](../03_metaprogrammed_dsl_defrule_defpremissa.md).

[BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md) · [BIBLIOGRAPHY_PON_SERIES.md](../../BIBLIOGRAPHY_PON_SERIES.md).
