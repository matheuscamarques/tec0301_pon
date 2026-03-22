---
title: "Building DSLs in Elixir (Part 2): AST essentials — quote, unquote, and bind_quoted"
published: false
description: "Part 2 of 10 — Maya’s first macro mis-fires; tuples on the screen teach quote and unquote. Same night, Riverbank learns how Builder templates work."
tags: elixir, metaprogramming, macros, ast, dsl
series: elixir-dsl-building
---

*If this helped you, you can [support the author with a coffee on dev.to](https://dev.to/matheuscamarques/support-with-a-coffee-2oa0).*

# Building DSLs in Elixir (Part 2): AST essentials — `quote`, `unquote`, and `bind_quoted`

**Part 2 of 10** — [Index](README.md) · [Part 1](01_when_not_to_reach_for_macros.md) · Next: [Part 3 — One line to open the door](03_use_pattern___using__.md)

**Reading time:** long-form draft (~10 min). This folder targets roughly **2,000+ words** per part so you can sit with the Riverbank story and the mechanics together.

---

The branch was quiet except for the fan. Maya had Jordan’s **golden module** on the left monitor and a `defmacro` stub on the right. She expected the compiler to “just insert” the condition the author wrote. Instead, the first compile threw a puzzle: the generated function seemed to call something named `condicao` as if it were a function, not the code she meant to splice.

Jordan leaned in. “You’re holding the author’s expression as **data**,” he said. “The compiler does not guess where to put it. You punch a hole in a template and say **unquote**.”

That night at Riverbank, **AST** stopped being an acronym and became the shape of the work ahead. Everything that follows in this series—`use`, generated modules, `__CALLER__`, hygiene—is mostly **applying** the loop you learn here. The reference implementation they kept peeking at was [`Tec0301Pon.PON.Builder`](../../../lib/tec0301_pon/pon/builder.ex), especially [`build_defrule_ast/6`](../../../lib/tec0301_pon/pon/builder.ex).

---

## The loop Maya taped above her desk

She wrote it in marker because repetition would save Riverbank from another Tuesday bug.

The macro **receives** fragments from the call site—already AST for most arguments. It **combines** them with fixed boilerplate using `quote` as a **template**. It **punches holes** with `unquote` (or `bind_quoted`) where the author’s code or computed values belong. It **returns** one AST; the compiler substitutes it for the original call and continues.

When the template felt cramped, she split it—exactly as `build_defrule_ast/6` builds separate inner quotes for `executar` and `start_link` before wrapping `defmodule`. Big single quotes age badly; small fragments compose. If you ever stare at a macro that is one giant `quote do` block, try the Builder’s rhythm: **compute branches first**, **name the quoted fragments**, **assemble the shell last**.

---

## From the codebase: how `build_defrule_ast/6` is a textbook template

The macro heads in [`Builder`](../../../lib/tec0301_pon/pon/builder.ex) dispatch on whether `when:` is a binary string (Part 8) or normal AST, and whether `edge_triggered:` is present. The AST path funnels into `build_defrule_ast/6`, which does three jobs in order.

First, it **derives a module name** from the rule identifier and the caller’s module (Part 4 previews `Module.concat`). Second, it **pattern-matches on the action** shape: either `[instigations: list]`—which produces a `for` comprehension of `Task.start/3` calls—or an arbitrary block body for `executar/1`. Third, it returns one outer `quote` whose body is `defmodule` with three definitions: `avaliar`, `executar`, and `start_link`.

The snippet below is **not** a paste of the whole function; it is the **structural spine** you should recognize when reading the file:

```elixir
quote do
  defmodule unquote(modulo) do
    @moduledoc false

    def avaliar(var!(memoria)), do: unquote(condicao)
    def executar(var!(memoria)), do: unquote(executar_impl)
    def start_link, do: unquote(start_link_impl)
  end
end
```

Notice how **`condicao`** is spliced once into `avaliar`, while **`executar_impl`** and **`start_link_impl`** were built in a prior `case`—that is the “variant first, fragments second” pattern. When Riverbank adds a third action flavor (say, telemetry-only rules), Maya will add another `case` arm **before** this shell, not another nested `quote` inside `executar` unless she must.

`var!(memoria)` appears because Elixir’s macro hygiene would otherwise rename the parameter away from what the author’s `when:` and `do:` expect. Part 6 unpacks that; for Part 2, treat it as “the template must agree with the author’s variable names on purpose.”

---

## What the PON series already said (expansion sketch)

[Part 3 of the Smart Brewery line](../03_metaprogrammed_dsl_defrule_defpremissa.md) gives the **conceptual** expansion of `defrule`: a nested module with `avaliar/1`, `executar/1`, and `start_link/0` calling `Tec0301Pon.PON.Regra.start_link/3` with the watched facts and options like `edge_triggered`. The post warns that the sketch is not the literal quoted AST—**your** macro may need `var!`, metadata, or extra options—but the **contract** is fixed: the GenServer in `Regra` already knows how to call `modulo.avaliar(memoria)` and `modulo.executar(memoria)` in module mode.

That alignment is why `quote`/`unquote` are not academic here. They are how you **inject** the author’s `when:` tree into `avaliar/1` without turning the condition into a string (until you deliberately choose the string path in Part 8). The same post ties `use Tec0301Pon.PON.Builder` to **importing** the macro definitions; Part 3 of *this* series opens that door explicitly.

---

## Worked example: reading a condition as data

Take a rule from [`Tec0301Pon.Examples.AlarmeSimples.Regras`](../../../lib/tec0301_pon/examples/alarme_simples_regras.ex) (or any small example module in `lib/tec0301_pon/examples/`). When the author writes `when: memoria[:some_fato] == :critical`, the **parser** has already turned that into a nested tuple tree before your macro runs. Your job is not to interpret it at macro-expansion time as a boolean; your job is to **place** that tree inside `def avaliar(var!(memoria)), do: ...` so that **at runtime** each notification merge rebuilds `memoria` and the function returns true or false.

Walk through one rule in the example file: list the **watched** atoms, underline the **when** expression, and separately sketch what the **golden** `defmodule` would look like. Compare your sketch to the PON article’s conceptual module. If they match, your macro is a mechanical transcription problem—exactly what `quote` and `unquote` were invented to express.

---

## `quote`: the greenhouse condition freezes into a tree

```elixir
quote do
  memoria[:temp] > 30
end
# => {:>, _, [{{:., _, [{:memoria, _, _}, :temp]}, _, []}, 30]}
```

Inside `quote do ... end`, most forms are **not evaluated**—they become structure. That is the shape macro arguments already carry when an author writes `when: memoria[:x] == 1`.

Read tuples left to right: **operator or call**, **metadata** (line, file—your friend when errors land in generated code), **children**. You compose with `quote`; you splice with `unquote`. For debugging, `Macro.to_string/1` prints something human; `IO.inspect/2` in a macro body shows what you actually received.

**`unquote` scopes to the innermost `quote`**—keep templates shallow or nest explicitly so you always know which hole you are filling. When Riverbank’s errors pointed at line 1 of a generated file, Maya learned to print `Macro.Env.location(__CALLER__)` beside her debug inspects so she could map back to the author’s source.

---

## `unquote`: punching the hole Jordan asked for

```elixir
defmacro example(condicao) do
  quote do
    def avaliar(var!(memoria)), do: unquote(condicao)
  end
end
```

Without `unquote(condicao)`, the compiler looks for a function named `condicao`. With it, the **contents** of `condicao`—the author’s AST—land inside `def avaliar/1`.

**Rule of thumb:** `quote` freezes structure; `unquote` opens holes for AST fragments or simple literals (watch lists, flags).

**Process detail:** the macro body runs at **compile** time when the call expands. `condicao` binds before the `quote`; `unquote` lifts its **value** into the template. Splice a non-AST by mistake and the error is confusing by design—treat it as “wrong shape here.” When teaching new hires, Jordan paired this with “always expand once in `iex` before you merge.”

---

## When `unquote` bites

Sometimes you need the **opposite** move: keep a piece as **data** inside a larger template—nested `quote`/`unquote` or `Macro.escape/2` for runtime values that must become literals. If you splice a random runtime map where the compiler expects AST, you earn a long afternoon.

A practical Riverbank rule: **never** build AST by hand with raw tuples until `Macro` helpers fail you. Prefer `quote` for structure and `unquote` for holes; reach for `Macro.escape/2` when a runtime value must become a literal in the generated code. The official [`Macro`](https://hexdocs.pm/elixir/Macro.html) module documents traversal and hygiene helpers you will lean on in Parts 5–6.

---

## `bind_quoted`: Maya stops double-expanding herself

```elixir
defmacro with_cond(condicao) do
  quote bind_quoted: [condicao: condicao] do
    def avaliar(var!(memoria)), do: condicao
  end
end
```

`bind_quoted` lists variables that are **automatically unquoted once** inside the body—fewer footguns when many bindings inject. Real Builder code often uses plain `unquote(condicao)`; reach for `bind_quoted` when several values should inject consistently or when you are tired of counting nested `unquote` layers.

Official: [`Kernel.SpecialForms.quote/2`](https://hexdocs.pm/elixir/Kernel.SpecialForms.html#quote/2).

---

## Process / checklist: debugging a macro without losing the afternoon

**Step 1 — Capture the call site AST.** In a scratch module, `quote do: your_macro(...)` shows what the macro receives. Compare that to what you assumed in the `defmacro` head.

**Step 2 — Expand once.** `Macro.expand_once(quoted_call, __ENV__)` shows one expansion step. For deeper expansion, `Macro.expand/2` continues until it stabilizes—useful when your macro calls other macros.

**Step 3 — Pretty-print.** `Macro.to_string/1` on the expanded tree is how Maya explained bugs in stand-up without projecting raw tuples.

**Step 4 — Bisect the template.** Comment out half of the returned `quote` until the error moves; then restore and narrow. Builder-sized macros reward **extracting** inner quotes into private functions with speaking names.

**Step 5 — Golden test.** Keep a tiny module that uses the DSL and assert on **behavior** (`Regra` stats, public API). AST golden tests are a last resort (Part 10).

---

## The exercise that saved Tuesday

In a scratch module:

```elixir
defmacro double_ast(expr) do
  quote do
    unquote(expr) + unquote(expr)
  end
end
```

Maya ran it, then `Macro.expand_once(quote(do: double_ast(1 + 2)), __ENV__)` and watched duplication appear in the tree. She tried `double_ast(a)` with a caller variable and saw hygiene argue back. That half hour cost less than one production drift bug.

**Extended exercise (15 minutes):** implement `triple_ast/1` that multiplies an expression by three using only `quote`/`unquote`. Then implement `wrap_in_io_inspect/1` that wraps any expression in `IO.inspect(expr, label: "riverbank")` **without** evaluating `expr` at macro-expansion time. If the second exercise hurts, reread the `bind_quoted` section—accidental early evaluation is the usual mistake.

---

## Reading `case acao` in Builder as a student of AST

Part 7 will name the pattern formally; you can preview it now in [`build_defrule_ast/6`](../../../lib/tec0301_pon/pon/builder.ex). The macro binds `acao` from the call site—already AST. **`case acao do`** distinguishes `[instigations: list]` from “everything else” treated as a normal block body. Each branch returns `{executar_impl, start_link_impl}` as **two quoted fragments**, not as strings, not as runtime values.

That structure is worth copying in your own DSLs: compute **both** halves of the generated module API in one place so `start_link` options and `executar` side effects cannot drift. When Maya first refactored Riverbank’s spike, she accidentally updated only one branch; tests caught missing `instigation_list:` in `Regra.start_link/3`. The bug was boring; the lesson was not—**branch-local quotes should still return parallel tuples** so reviewers see symmetry.

If you `IO.inspect(acao, structs: false)` from a toy macro, you will see why pattern matching works: `instigations` appears as a keyword list AST with tuple children. Learning to recognize `[instigations: _]` in tree form saves hours compared to guessing from error messages alone.

---

## A footnote for the curious (literature)

“Code as data” predates Elixir by decades; it is the Lisp family’s central teaching. Krishnamurthi’s *Programming Languages: Application and Interpretation* presents interpretation and macro systems with enough rigor that `quote` stops feeling magical and starts feeling like **tree algebra**. Elixir’s `quote`/`unquote` are **quasiquotation**: most of the template is literal structure, except marked holes where another tree is spliced. McCord’s *Metaprogramming Elixir* (2015) is the shortest path from that idea to shipping macros in production code.

**`bind_quoted`** is about **staging** again (Part 1’s footnote named Taha): you decide whether a binding is evaluated **once** when the macro runs or **re-evaluated** because you accidentally nested expansions. Parr’s *Language Implementation Patterns* (2010) is the gentle companion for thinking in trees—AST walks, listeners, and templates—without requiring a full graduate compiler course. When Riverbank later generates modules from external config, those patterns return under different names.

For day-to-day work, the official [`Macro`](https://hexdocs.pm/elixir/Macro.html) module and [`Kernel.SpecialForms.quote/2`](https://hexdocs.pm/elixir/Kernel.SpecialForms.html#quote/2) are the authoritative references. This series cites fuller bibliographic rows in [BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md); the PON series has a parallel table in [BIBLIOGRAPHY_PON_SERIES.md](../../BIBLIOGRAPHY_PON_SERIES.md).

---

## Tomorrow morning

Jordan would paste `use Riverbank.RulesDSL` at the top of the first real rules file—except the macro module did not yet expose a **`__using__`** hook. [Part 3](03_use_pattern___using__.md) is the commit where `use` becomes the greenhouse’s front door.

---

## References

- Krishnamurthi, S. *Programming Languages: Application and Interpretation* (PLAI). [Brown CS](https://cs.brown.edu/~sk/Publications/Books/ProgLangs/2007-04-26/).
- McCord, C. (2015). *Metaprogramming Elixir*. Pragmatic Bookshelf.
- Elixir [`Kernel.SpecialForms.quote/2`](https://hexdocs.pm/elixir/Kernel.SpecialForms.html#quote/2), [`Macro`](https://hexdocs.pm/elixir/Macro.html).
- Parr, T. (2010). *Language Implementation Patterns*. Pragmatic Bookshelf.
- [PON Part 3 — metaprogrammed DSL](../03_metaprogrammed_dsl_defrule_defpremissa.md).

[BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md) · [BIBLIOGRAPHY_PON_SERIES.md](../../BIBLIOGRAPHY_PON_SERIES.md).
