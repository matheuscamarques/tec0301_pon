---
title: "Building DSLs in Elixir (Part 5): __CALLER__ and lexical module context"
published: false
description: "Part 5 of 10 — Jordan spots __MODULE__ in the wrong brain; __CALLER__ and Macro.Env anchor Riverbank’s rules. Same pattern as Tec0301Pon.PON.Builder."
tags: elixir, metaprogramming, macros, dsl, __CALLER__
series: elixir-dsl-building
---

*If this helped you, you can [support the author with a coffee on dev.to](https://dev.to/matheuscamarques/support-with-a-coffee-2oa0).*

# Building DSLs in Elixir (Part 5): `__CALLER__` and lexical module context

**Part 5 of 10** — [Index](README.md) · [Part 4](04_generating_modules_names_from_macro_arguments.md) · Next: [Part 6 — The variable the compiler wouldn’t share](06_hygiene_and_var_bang_injecting_memoria_safely.md)

**Reading time:** long-form draft (~10 min). Target **2,000+ words** per part.

---

The review comment was one line: “Why is this rule under `Riverbank.RulesDSL`?” Maya stared until the mistake embarrassed her: inside `build_rule_ast/6` she had used **`__MODULE__`**, which meant the **macro definition module**, not the file that **called** `defrule`. The rule did not belong to the greenhouse authors; it belonged to the machinery.

She passed **`__CALLER__`** instead—a `%Macro.Env{}` describing **where the macro was invoked**: `module`, `file`, `line`, `aliases`, `requires`, and more. `caller.module` became the prefix in `Module.concat`, and the namespace snapped back to `Riverbank.Irrigation.Rules.*`.

[`Tec0301Pon.PON.Builder`](../../../lib/tec0301_pon/pon/builder.ex) does exactly this: every `build_*` takes `caller` from `__CALLER__` at the `defmacro` site.

---

## Compile-time vs runtime (again, on purpose)

[Part 2 of the PON draft](../02_from_whiteboard_to_code_otp.md) walks notifications and `GenServer` behavior—**runtime**. Macro expansion and `__CALLER__` are **compile-time**: they decide what **modules exist** before any message flies. Confusing the two is how `__MODULE__` sneaks into the wrong place: at expansion time, `__MODULE__` inside `Tec0301Pon.PON.Builder` is still `Tec0301Pon.PON.Builder`, even though the author mentally “stands” in `Riverbank.Irrigation.Rules`.

Riverbank posted a sticky: **“In `defp` helpers for macros, `__MODULE__` is usually wrong; `caller.module` is usually right.”** The exception is **inside the quoted template** for the **generated** submodule, where `__MODULE__` correctly refers to the child module being defined—`Regra.start_link(fatos, __MODULE__, ...)` in Builder does exactly that **inside** the `quote`.

---

## Threading context (the habit Jordan enforced)

`defmacro defrule(...)` receives `__CALLER__` for the **invocation** environment. Pass it immediately into `build_defrule_ast(..., __CALLER__, opts)`. Inside helpers, read `caller.module`, `caller.file`, `caller.line`; use `caller.module` as the root for `Module.concat` (Part 4). Optionally merge AST `meta` with `caller.line` when raising `ArgumentError` so authors see a helpful line.

Keeping macros thin and pushing work into `defp ...(caller)` makes reviews readable—and advanced tests can fabricate minimal `%Macro.Env{}` structs if you isolate pure logic (name resolution) from expansion.

**Concrete Builder pattern:**

```elixir
defmacro defrule(nome_da_regra, watch: fatos, when: condicao, do: acao) do
  build_defrule_ast(nome_da_regra, fatos, condicao, acao, __CALLER__, false)
end
```

Every clause that dispatches to `build_defrule_ast` or `build_defrule_string` passes `__CALLER__` the same way—no exceptions, no “sometimes we forget in the string clause” drift.

---

## From the codebase: where `caller` lands

Inside `build_defrule_ast/6`, the first use of `caller` is typically `Module.concat([caller.module | name_atoms])`. That single expression is the difference between `Tec0301Pon.Examples.Estufa.Regras.RegraIrrigacao` and a haunted module under the wrong parent. The same `caller` could feed improved error messages: `"invalid defrule in #{inspect(caller.module)} at #{caller.file}:#{caller.line}"`.

---

## What the PON series already said

[Part 3](../03_metaprogrammed_dsl_defrule_defpremissa.md) describes expansion conceptually—nested modules, `start_link/0`, `Regra.start_link(watched_facts, __MODULE__, ...)`. It does not linger on `__CALLER__` because the article targets architecture readers first. **This** part is the debugger’s chapter: when your nested module names look like they came from Mars, print `caller.module` in a temporary `IO.inspect` inside the macro and recompile once.

---

## Debugging “where did this come from?”

Stack traces on generated `def avaliar/1` confuse new hires. Teach them to look for the **parent** module that `use`s the DSL. Teach macros to carry **`caller.file` / `caller.line`** into `raise` messages when you reject bad options.

**Riverbank’s wrong-`__MODULE__` story** (extended): Maya first noticed the bug because `Application` failed to start a child—`Riverbank.RulesDSL.RegraIrrigacao` had no `start_link/0` in the file she edited. The child spec pointed at an atom that existed but lived in the wrong application subtree. Ops had filtered logs by `~r/Riverbank\.Irrigation/` and saw **nothing** when the rule fired. The silence was worse than a crash.

---

## Worked example: trace one file

Open [`estufa_regras.ex`](../../../lib/tec0301_pon/examples/estufa_regras.ex). The module is `Tec0301Pon.Examples.Estufa.Regras`. Every `defrule X` expands to `Tec0301Pon.Examples.Estufa.Regras.X` because `caller.module` is the long parent. If you moved the same macros into a nested inner module without updating docs, `caller.module` would change—**by design**. That is why “extract rules to a submodule” is never a no-op in DSL-driven code: it renames every generated child.

---

## Advanced env (when Riverbank grows up)

`caller.aliases` matters if you resolve user-written names through import tables. `Macro.Env.var_version/2` appears in hygiene edge cases—rare in straightforward DSLs but relevant if you generate `use` macros that themselves expand other macros.

`caller.function` and `caller.context` differ between macro invocation at the module body versus inside function bodies—remember, **module-level** `defrule` is the supported story; nested invocation hits different errors first.

---

## Process / checklist: `__CALLER__` hygiene

1. **Thread `caller` through every `defp` that computes module names or raises.**  
2. **Never** use `__MODULE__` in those `defp`s for the author’s namespace.  
3. **Do** use `__MODULE__` inside `quote` when the generated code must refer to **itself** (the child module).  
4. **Log or raise with** `caller.file`/`line` on invalid options.  
5. **Code review grep** for `build_.*\(.*\)` without `caller` after refactors.

---

## `Macro.Env` field tour (practical, not exhaustive)

`caller.module` is the workhorse for DSLs that generate submodules. `caller.file` and `caller.line` anchor human-readable errors—especially when authors generate dozens of rules and the compiler points at generated code. `caller.macro_aliases` and `caller.aliases` matter if your macro accepts **module attributes** or struct names that must resolve through `import`/`alias` tables; most PON-style rules do not need them until you add typed fact schemas.

`caller.requires` and `caller.functions` show what the call site could legally invoke; advanced macros sometimes assert “this DSL file must `require Logger`” by checking `caller.requires`. `caller.context` distinguishes `:module` vs `:function` contexts—calling `defrule` inside a function body fails earlier than namespace bugs, but the error message is clearer if your docs forbid it explicitly.

Riverbank added a **dev-only** `defmacro __debug_caller__` that returned `inspect(caller, structs: false)` when `Mix.env() == :dev`, gated behind an application config flag. Maya used it once per sprint, not in production logs—`Macro.Env` structs are large and noisy, but they settle arguments in code review faster than philosophy.

---

## Compile-time-only debugging tricks

Because `__CALLER__` exists only during expansion, you cannot pass it to runtime `Logger.info/1` inside the generated module without **quoting** a capture or serializing fields you need. The usual pattern is to bake **static** metadata into module attributes at compile time:

```elixir
@rule_source {__CALLER__.file, __CALLER__.line}
```

…inside the **macro** that returns the `quote`, not inside the caller module literally—you would compute `file_line` in the macro body and `unquote` it into `@rule_source` in the child template. Riverbank never shipped this, but Jordan kept the snippet for incidents where two rules looked identical in logs.

---

## Relationship to `__DIR__` and `Macro.Env.location/1`

Authors sometimes reach for `__DIR__` when they want file context. In a macro, `__DIR__` refers to the **definition** file of the macro module, not the caller. For “where was `defrule` written?”, only `caller.file` is correct. `Macro.Env.location(env)` returns `{file, line}`—a handy helper when raising.

---

## Integration-style assertion Riverbank added (behavior, not AST)

Maya wrote a test that compiled a tiny rules module inside `test/` and asserted **`Module.split(ExpectedModule) |> List.take(-2)`** matched `["Rules", "Smoke"]`—a cheap guard that the prefix stayed `Riverbank.Irrigation.Rules` after refactors. The test broke once when someone moved the file without updating the parent module declaration; that was the point. Part 10 expands testing strategy; the idea here is **cheap canaries** that `caller.module` wiring still matches org conventions.

Another pattern: call `apply(Generated, :start_link, [])` in setup and assert `:ok` or `{:ok, pid}`—you are testing **expansion + linking**, not macro internals. If `caller` regresses, the generated atom may still start but live under the wrong semantic parent; combine with the module split assertion above.

---

## When `__CALLER__` is not enough (rare)

If authors `import` your macro module and call a **wrapped** macro that re-invokes helpers without threading the original env, you can lose the outer caller. Builder avoids this by passing `__CALLER__` only one hop—`defmacro` → `build_*`. If you build macro-on-macro towers, **thread the env** explicitly as the first argument to every helper, like passing `conn` in Plug tests.

---

## Story time: the Friday deploy that was not the BEAM’s fault

Jordan’s war story—edited for brevity—was a release where **only** the rules submodule names changed (bad `caller`), while `mix release` succeeded. Staging looked fine until `:observer` showed duplicate logical rules under two atoms. Rollback was clean because the supervision tree still started; observability was the casualty. They added the module split test Monday morning. The moral: **OTP tolerates many mistakes longer than humans do.**

---

## Minimal reproduction of `caller.module` in `iex`

Advanced readers can experiment in `iex` by defining a throwaway macro in a module and calling it from another module in the same session—`caller.module` will reflect the **caller** file’s module attribute. This is fiddly in `iex` because redefinition warnings accumulate; Riverbank kept a **`scratch/macro_caller_demo.ex`** checked out locally (git-ignored) for demos. The pedagogical point stands: **`__CALLER__` is not magical**—it is data threaded from the invocation site, like passing `conn` through plugs.

---

## Cross-package DSLs: caller when the rules live in an umbrella child app

In umbrellas, `caller.module` often includes the child app prefix (`Riverbank.Irrigation.Rules`). If the macro lives in a **core** package and authors use it from **multiple** apps, namespace collisions become organizational: two apps might both define `Rules.Alarm` under different parents—good—or accidentally use the same parent module if copy-paste spread—bad. Document **one module prefix per bounded context**, not per deployable, unless you enjoy ambiguous atoms.

---

## Doc generation and `caller.file`

Internally, Riverbank experimented with embedding **source links** in generated `@moduledoc false` modules—opting out because `@moduledoc false` is already noise-sensitive. Instead they logged `(caller.file, caller.line)` into **telemetry metadata** when rules fired in dev—cheap provenance without publishing paths in prod artifacts. Sam approved: fewer leaks, same debuggability for engineers.

---

## Glossary card for reviewers

**`__CALLER__`** — special form available in macro definitions; becomes `%Macro.Env{}` at the call site.  
**`caller.module`** — module atom of the file invoking the macro; use for `Module.concat` prefixes.  
**`__MODULE__` in helpers** — usually the macro definition module (`Builder`), **not** the author module—avoid for prefixes.  
**`__MODULE__` inside generated `quote`** — refers to the **generated** submodule—correct for `Regra.start_link(..., __MODULE__, ...)`.

Printing this card in `CONTRIBUTING.md` cut review latency when external consultants landed.

---

## `__CALLER__` in library vs application code

When the macro lives in a **library** package and authors call it from **multiple** apps, `caller.module` still reflects the **application module** doing the calling—good. Ensure your hex package docs show a fully qualified example (`MyApp.Rules` not `Rules`) so relative module confusion does not leak into support issues.

If docs show only `defmodule Rules do`, newcomers assume generated modules live under `Rules.*` inside the current app; that breaks when they move files into `MyApp.Irrigation.Rules` and forget to rename the parent—`caller.module` fixes the children, but **human** grep patterns still hurt until updated.

---

## A footnote for the curious (literature)

**Lexical context** is “where the call stood,” not where the macro was defined. `Macro.Env` is Elixir’s snapshot of that at expansion time ([`Macro.Env`](https://hexdocs.pm/elixir/Macro.Env.html)). Krishnamurthi (PLAI) and McCord (2015) connect macros, scope, and hygiene; Parr (2010) is a useful analogy to **symbol tables** in traditional compilers—`caller` is a structured symbol table row for the module scope.

Multi-stage programming (Taha, 1999; see Part 1 footnote) classifies `__CALLER__` as **stage-0** information consumed while building **stage-1** code. Treating it as runtime data is a category error that produces the wrong module atoms. [BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md) lists the full references.

---

## The mistake to grep for

If `caller` drops out of a refactor, **`__MODULE__` inside `defp`** becomes the Builder again. Symptoms: children under the wrong namespace, confusing `apply/3`, haunted code review. In **generated** code, `__MODULE__` correctly means the generated submodule—in **macro helpers**, it usually does not.

---

## Next: the compile error that made Maya swear softly

Conditions looked perfect in the source file. The expansion failed anyway—**hygiene** had renamed `memoria` out from under the spliced AST. [Part 6](06_hygiene_and_var_bang_injecting_memoria_safely.md) is the night `var!(memoria)` earned its place.

---

## References

- Elixir [`Macro.Env`](https://hexdocs.pm/elixir/Macro.Env.html); [`Macro`](https://hexdocs.pm/elixir/Macro.html) (`__CALLER__`).
- Krishnamurthi, S. *PLAI*. [Brown CS](https://cs.brown.edu/~sk/Publications/Books/ProgLangs/2007-04-26/).
- McCord, C. (2015). *Metaprogramming Elixir*.
- Parr, T. (2010). *Language Implementation Patterns*.
- [PON Part 3](../03_metaprogrammed_dsl_defrule_defpremissa.md).

[BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md) · [BIBLIOGRAPHY_PON_SERIES.md](../../BIBLIOGRAPHY_PON_SERIES.md).
