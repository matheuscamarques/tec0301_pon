---
title: "Building DSLs in Elixir (Part 6): hygiene and var! — injecting memoria safely"
published: false
description: "Part 6 of 10 — memoria disappears in expansion; var! is the deliberate handshake. Same pattern as Tec0301Pon.PON.Builder and a bridge to Part 8."
tags: elixir, metaprogramming, macros, dsl, hygiene
series: elixir-dsl-building
---

*If this helped you, you can [support the author with a coffee on dev.to](https://dev.to/matheuscamarques/support-with-a-coffee-2oa0).*

# Building DSLs in Elixir (Part 6): hygiene and `var!` — injecting `memoria` safely

**Part 6 of 10** — [Index](README.md) · [Part 5](05___CALLER___and_lexical_module_context.md) · Next: [Part 7 — The PM asks for two flavours at once](07_multi_head_macros_and_alternative_shapes.md)

**Reading time:** long-form draft (~10 min). Target **2,000+ words** per part.

---

The error message was almost polite: something about `memoria` not meaning what Maya thought it meant. She had spliced the author’s `when:` into `def avaliar(memoria), do: ...` and expected the world to align. Elixir’s **hygienic** macros had other plans—they rename to stop accidental capture, which is usually a gift. Here, the gift felt like a trap: the author’s AST still **said** `memoria`, but the parameter might not **be** `memoria` anymore.

Jordan slid a sticky note across the desk: **`var!(memoria)`**. “You are asking the compiler to share a name **on purpose**,” he said. “Use it only at the boundary between your template and their code.”

That is the same handshake [`build_defrule_ast/6`](../../../lib/tec0301_pon/pon/builder.ex) uses for both evaluation and execution:

```elixir
def avaliar(var!(memoria)), do: unquote(condicao)
def executar(var!(memoria)), do: unquote(executar_impl)
```

`defpremissa` uses `var!(memoria)` in `condicao/1`; `defcondicao`’s custom `when:` path uses `var!(memoria)` in `combine/1`. The **string** rule path is different—Part 8 contrasts it deliberately.

---

## What the author writes (and what the template owes them)

```elixir
when: memoria[:temp_ambiente] > 30
```

`memoria` is not a variable in the macro’s scope; it is **inside the quoted AST** that will become the function body. The generated `def` must declare a parameter whose name **matches** those references after expansion. `var!(memoria)` is the documented escape hatch ([`var!/2`](https://hexdocs.pm/elixir/Kernel.SpecialForms.html#var!/2)).

For **`instigations:`**, the Builder uses `_ = var!(memoria)` before the `for` comprehension—honoring hygiene for stray references while making the binding explicit. The block-action path uses `var!(memoria)` followed by `unquote(acao)` so side-effecting bodies can reference `memoria` consistently.

---

## From the codebase: `build_defrule_string` vs AST (preview of Part 8)

In [`build_defrule_string/6`](../../../lib/tec0301_pon/pon/builder.ex), `avaliar/1` is generated as:

```elixir
def avaliar(memoria) do
  {result, _} = Code.eval_string(unquote(expr_string), memoria: memoria)
  result
end
```

No `var!` in the head—because the condition is not spliced AST; it is **evaluated** from a string binding. `executar` uses plain `memoria` with `_ = memoria` in some branches. When debugging Riverbank’s fork, Maya learned to **grep** which path a rule used before assuming hygiene bugs: AST path → `var!`; string path → `Code.eval_string/2`.

The PON series [Part 3](../03_metaprogrammed_dsl_defrule_defpremissa.md) warns that string `when:` is for flexibility (config-driven rules) but is harder to test, refactor, and secure. Part 8 carries that warning into OWASP-flavored operational guidance.

---

## What the PON series already said

The metaprogramming post’s expansion sketch shows `def avaliar(memoria), do: ...` **without** `var!` because it is pedagogical pseudocode. The **real** Builder uses `var!(memoria)` so spliced author trees and parameter names agree. When teaching, Jordan always said: “Trust the repo over the sketch when the compiler disagrees.”

---

## Why plain `memoria` failed Maya that night

A naive `def avaliar(memoria), do: unquote(condicao)` can leave the spliced tree referring to a **renamed** parameter. The rule engine calls `avaliar/1` with a map; names must line up. `var!` opts out locally—use it **sparingly**, only at template boundaries.

**Anti-pattern:** sprinkling `var!` inside author-supplied code—never. **Pattern:** `var!` only in **your** generated function heads and, rarely, to force a shared name in a tight wrapper around `unquote`.

---

## Worked example: read one rule’s expansion mentally

Pick a rule in [`smart_brewery_regras.ex`](../../../lib/tec0301_pon/examples/smart_brewery_regras.ex) with a non-trivial `when:` clause. Copy the `when:` line onto paper. Under it, write `def avaliar(var!(memoria)), do:` and append the same expression. That is the **semantic** contract `Regra` expects. If you mentally rename `memoria` to `ctx`, you must rename every reference in the author’s clause—or keep `var!(memoria)` and forbid `ctx` in docs.

---

## Discipline Riverbank adopted

Do not sprinkle `var!` for convenience. Document `memoria` (and any future binding) in `@moduledoc`. Typos like `memory` fail at compile time—good—if examples are consistent.

**Review rule:** any PR introducing a new binding in the DSL (`env`, `facts`, etc.) must update: docs, **all** examples, and **every** `var!` site in the generator. Missing one site creates heisenbugs that only appear for certain `when:` shapes.

---

## Process / checklist: hygiene debugging

1. Reproduce in a **minimal** module with one `defrule`.  
2. `Macro.expand_once/2` on the call; inspect the generated `def`.  
3. Compare parameter name to references inside `unquote(condicao)`.  
4. If they differ, add `var!` at the **def head** only.  
5. If still broken, check you are not on the **string** eval path.  
6. Add a regression test that asserts **behavior** on a toy rule (Part 10).

---

## `defpremissa` and `defcondicao`: the same handshake, different arity names

[`build_defpremissa/6`](../../../lib/tec0301_pon/pon/builder.ex) generates `def condicao(var!(memoria)), do: unquote(condicao)` because `Premissa` expects a predicate function over the memory map—the name `condicao` is the **callback** name, while `var!(memoria)` still aligns the parameter with author AST. [`build_defcondicao_when/6`](../../../lib/tec0301_pon/pon/builder.ex) emits `def combine(var!(memoria)), do: unquote(expr)` for custom aggregators. The pattern is identical in spirit to `avaliar/1`: **template owns the head**, **author owns the body tree**.

When Riverbank forked Builder for experiments, they briefly renamed `memoria` to `ctx` in docs only—without changing `var!`—and watched every `when:` clause break until they reverted. The lesson: **binding names are API**.

---

## Security bridge (why Part 8 is not optional)

Hygienic splicing and `var!` keep **compile-time** author expressions aligned with generated functions. They do **not** sanitize **strings** fed into `Code.eval_string/2`. If you bypass AST with strings, you leave the hygiene story and enter **eval** policy: who can supply the string, where it is stored, how it is versioned, and what happens when it throws. Sam’s security review (Part 8) starts from that boundary.

---

## When `var!` still fails: typos, shadowing, and `unused` warnings

If the author writes `when: memory[:x]` (typo) while the template declares `var!(memoria)`, the compiler usually errors clearly—**unless** `memory` is bound in an outer scope in a weird nested macro experiment. Riverbank banned nested experiments. They also watched for `@compile {:no_warn_undefined, ...}` pragmas hiding mistakes; DSL files should stay boring.

`_ = var!(memoria)` in instigation branches exists both to silence “variable unused” warnings and to document intent: **the action path may not read memory, but the binding is part of the contract**. When Jordan refactored instigations to async telemetry, he kept the discard for readability.

---

## Mental exercise: translate hygiene to explicit GenServer callbacks

Imagine implementing `avaliar/1` without macros—hand-written `defmodule` with `def avaliar(memoria), do: ...`. Hygiene would not be a discussion; the parameter name is whatever you typed. Macros recreate that **explicit** agreement between parameter and body **after** splicing trees. `var!` is the escape hatch saying “this name is **public API** between template and author fragment,” similar to how Phoenix marks `assigns` in HEEx—different mechanism, same **boundary** instinct.

---

## Teaching new hires: a 10-minute live demo

Maya’s onboarding script: (1) show a broken macro **without** `var!` and the hygiene error; (2) add `var!` and recompile; (3) show `Macro.expand_once/2` before/after trees side by side; (4) open Builder source and point at **three** `var!` sites; (5) contrast `build_defrule_string/6` **without** `var!` in `avaliar`’s head. New hires who survive step 5 without dizziness graduate to Part 7.

---

## Close read: `executar` in the string path uses plain `memoria`

In [`build_defrule_string/6`](../../../lib/tec0301_pon/pon/builder.ex), the block branch quotes:

```elixir
ex =
  quote do
    _ = memoria
    unquote(acao)
  end
```

There is **no** `var!` here because `acao` is still AST spliced into the `executar` body—hygiene will align `memoria` references inside typical `do:` blocks with the function parameter **`def executar(memoria)`**. The nuance: **`avaliar`** uses eval and a plain parameter name; **`executar`** stays on the normal compilation path for the block. Instigation branches use `_ = memoria` without `var!` in some arms. When Riverbank forked Builder, they added a comment above `build_defrule_string` warning maintainers not to “fix” asymmetry without reading both paths—good advice for any patch touching eval.

If you see a bug where **`executar` works in AST rules but not string rules**, compare the **`quote` fragments** side by side before blaming `Regra`. Part 8 names operational risks when strings and blocks mix in one rule.

---

## Anti-pattern: `var!` to silence warnings in author code

Riverbank briefly experimented with letting authors opt into `var!(danger)` to reach outer bindings. Jordan vetoed it: **`var!` is for template authors**, not domain rule authors. The DSL’s public surface should remain **hygienic** for readers; if authors need shared bindings, pass explicit maps (`memoria`) and functions—never implicit capture.

---

## Generating local variables inside `when:`

Keep `when:` a **boolean** expression without side effects—e.g. `(memoria[:a] || 0) > 0`—not a place to sneak logging or `send/2`. Builder does not special-case side effects; **`Regra`** may evaluate conditions often. Document **pure** `when:` clauses in `@moduledoc` so engineers do not hide telemetry inside conditions.

---

## Checklist: code review for `var!` diffs

- Is every `var!` at a **generated** `def` boundary, not inside author-supplied fragments?  
- If a new `var!` appears, do **all** docs and examples use the same name (`memoria`)?  
- Does the string-eval path still avoid `var!` in `avaliar/1` heads (Part 8)?  
- Are instigation branches still spawning tasks with **bounded** fan-out (no user-controlled list lengths without guards)?

Riverbank attached this checklist to the macro OWNERS file in GitHub.

---

## Connecting hygiene to observability

When `avaliar/1` raises, stack traces show **generated** line numbers. Hygiene problems often manifest as **undefined variable** errors before runtime even starts—good. If you instead see confusing **FunctionClauseError** in `Regra`, suspect **wrong arity** or **wrong module atom** (Parts 4–5) before you blame `var!`.

Pair debugging tip: paste **only** the generated `def avaliar` and `def executar` into a scratch module temporarily, replace `var!(memoria)` with `memoria`, and feed a map in `iex`. If the scratch behaves, the bug is elsewhere (supervision, facts). If it fails, the splice is still wrong.

For large rules, paste **only** `avaliar` first—isolate condition truth before debugging actuator side effects in `executar`.

When pairing remotely, paste expanded `avaliar` into a **gist** with secrets redacted—faster than screen-sharing tuple trees. Riverbank’s security bot scanned gists for accidental `SECRET_KEY` literals; humor and paranoia combined.

If gists are banned, use ephemeral pastebin inside the VPN with auto-expire—same workflow, tighter policy.

---

## A footnote for the curious (literature)

**Hygienic macro expansion** (Kohlbecker et al., 1986; Clinger, 1991) exists so macros do not steal bindings by accident. The classic papers show how naive expansion captures variables in the expansion environment and breaks abstraction. Flatt (2016) reframes binding as **sets of scopes**—a model closer to modern macro systems. Elixir’s `var!/2` marks **intentional** sharing across that boundary (see docs; McCord, 2015).

The contrast with `Code.eval_string/2` is not just API trivia: eval reintroduces a **dynamic** scope for the string’s code, separate from Elixir’s compile-time hygiene story. That is why security and testing advice clusters around preferring AST `when:` for application rules. [BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md) includes Kohlbecker and related entries.

---

## Two mental models (Part 8 will pick at this scab again)

- **AST path:** author expression is data spliced into functions; **`var!`** aligns names.  
- **String path:** author expression is text; **`Code.eval_string/2`** binds `memoria:` in the eval environment; **no** `var!` in `avaliar`’s head.

When debugging, know **which path** you are on before you blame hygiene.

---

## Next: variants without chaos

Sam walked in with coffee and a whiteboard marker. “Ops wants rules from a JSON file **and** the pump team wants tasks instead of inline `do:` blocks.” Maya’s macro now needed **several faces** without becoming a `cond` monster. [Part 7](07_multi_head_macros_and_alternative_shapes.md) is that sprint.

---

## See also (cross-links)

Hygiene is the **hinge** between Part 2’s templates and Part 8’s eval escape hatch: AST splicing uses `var!`; string eval uses another binding story—reread both before changing either. Parts [4](04_generating_modules_names_from_macro_arguments.md)–[5](05___CALLER___and_lexical_module_context.md) decide **where** generated modules live; wrong atoms make hygiene debugging a red herring. Part [10](10_testing_and_inspecting_macros.md) shows how to **prove** `var!` contracts survive refactors.

---

## References

- Kohlbecker, E.; et al. (1986). *Hygienic macro expansion*. [DOI 10.1145/319838.319859](https://doi.org/10.1145/319838.319859).
- Clinger, W. (1991). *Macros that work*. POPL.
- Flatt, M. (2016). *Binding as sets of scopes*. [Dagstuhl](https://drops.dagstuhl.de/opus/volltexte/2016/6113/).
- Elixir [`var!/2`](https://hexdocs.pm/elixir/Kernel.SpecialForms.html#var!/2).
- McCord, C. (2015). *Metaprogramming Elixir*.
- [PON Part 3](../03_metaprogrammed_dsl_defrule_defpremissa.md).

[BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md) · [BIBLIOGRAPHY_PON_SERIES.md](../../BIBLIOGRAPHY_PON_SERIES.md).
