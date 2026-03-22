---
title: "Building DSLs in Elixir (Part 4): generating modules — names from macro arguments"
published: false
description: "Part 4 of 10 — Maya learns __aliases__ and Module.concat; Riverbank’s rules finally nest under the right parent. Mirrors Tec0301Pon.PON.Builder."
tags: elixir, metaprogramming, macros, dsl, modules
series: elixir-dsl-building
---

*If this helped you, you can [support the author with a coffee on dev.to](https://dev.to/matheuscamarques/support-with-a-coffee-2oa0).*

# Building DSLs in Elixir (Part 4): generating modules — names from macro arguments

**Part 4 of 10** — [Index](README.md) · [Part 3](03_use_pattern___using__.md) · Next: [Part 5 — The env that remembers where you stood](05___CALLER___and_lexical_module_context.md)

**Reading time:** long-form draft (~10 min). Target **2,000+ words** per part in this series.

---

Jordan grep’d the build output and groaned. The new rule module was nested under the **macro library**, not under `Riverbank.Irrigation.Rules`. Supervision trees in his head rearranged themselves wrong; hot upgrades would target the wrong atom. “We treated the rule *name* like a finished module,” he said, “but the parser hands you a **tree**.”

Maya opened the call site: `defrule RegraIrrigacao, watch: ...` The first argument was not yet `Riverbank.Irrigation.Rules.RegraIrrigacao`. It was AST—either `{:__aliases__, meta, parts}` or occasionally a bare atom. Her job was to normalize that shape, **prefix the author’s module**, and splice `defmodule unquote(modulo)` into the template.

That is the same path [`Tec0301Pon.PON.Builder`](../../../lib/tec0301_pon/pon/builder.ex) walks for every `defrule`, `defpremissa`, and `defcondicao`—see `build_defrule_ast/6`, `build_defpremissa/6`, and the `build_defcondicao_*` helpers: each extracts `name_atoms`, then calls `Module.concat([caller.module | name_atoms])` once `caller` is threaded from `__CALLER__` (Part 5).

---

## From the author’s identifier to `defmodule` (the honest sequence)

The parser passes the first argument as **AST**, not a ready atom. The macro matches `{:__aliases__, _, parts}` or an atom, builds **suffix** atoms, and—**with** `caller.module` from the invocation site—calls **`Module.concat/1`** on `[caller.module | parts]`. The outer `quote` emits `defmodule unquote(modulo) do ... end`. The parent file’s compile defines the child.

Skip the `__aliases__` case and multi-segment names fracture. Skip `Module.concat` and string hacks leak into atom hygiene. This is not cosmetic: supervisors, logging, telemetry tags, and `:observer` all read **module atoms** as the operational truth. When the PON series says each `defrule Name` becomes `MyApp.Rules.Name`, the **Name** half is exactly this suffix list; the **MyApp.Rules** half is `caller.module`.

---

## From the codebase: the `name_atoms` case you should copy by hand once

In [`builder.ex`](../../../lib/tec0301_pon/pon/builder.ex), the pattern repeats with small variations. For rules:

```elixir
name_atoms =
  case nome_da_regra do
    {:__aliases__, _, parts} -> parts
    other when is_atom(other) -> [other]
  end

modulo = Module.concat([caller.module | name_atoms])
```

`defpremissa` and `defcondicao` use the same `case` on their first argument. That duplication is acceptable in macro-heavy modules: the **behavior** is identical, and extracting a shared `defp rule_name_atoms(ast)` avoids drift when you add a third shape (for example, string names—usually a bad idea for modules).

Riverbank’s spike added logging: when `parts` has more than one segment, Maya printed a warning in dev builds—nested rule names read like namespaces, and authors sometimes forget they are appending to the parent module.

---

## What the PON series already said (nested modules)

[Part 3 of the Smart Brewery line](../03_metaprogrammed_dsl_defrule_defpremissa.md) states that each `defrule Name, ...` becomes a module under the caller’s namespace—for example `MyApp.Rules.Cooling` inside `MyApp.Rules`. The post’s conceptual expansion sketch shows `defmodule MyApp.Rules.Example` with callbacks and `start_link/0`. Part 4 of *this* series is the **mechanical** explanation: **`Module.concat`** is how Elixir spells `MyApp.Rules.Example` without hard-coding the parent.

[Part 2 of the PON repo draft](../02_from_whiteboard_to_code_otp.md) (whiteboard → OTP) matters here indirectly: every generated submodule is a **candidate child** in your supervision tree or application start. If names wander under the wrong parent, your `Application` children list and your mental model of “which app owns this rule” diverge. OTP does not care about your feelings; it cares about **which module** implements `child_spec/1` or which `start_link/0` you invoke.

---

## Two shapes the first argument wears

```elixir
defrule RegraIrrigacao, watch: [...], ...
```

The macro sees **`{:__aliases__, meta, parts}`** (e.g. `[:RegraIrrigacao]` or `[:Nested, :Name]`) or a **bare atom**. Builder normalizes to `name_atoms` as above, then:

```elixir
modulo = Module.concat([caller.module | name_atoms])
```

The **parent module** (where `use` and `defrule` live) is always the prefix; the argument supplies suffix segments. **`caller.module`** is the piece Maya almost forgot—[Part 5](05___CALLER___and_lexical_module_context.md) is where `__CALLER__` makes that prefix impossible to lose.

**Aliased calls** at the use site can produce longer `parts` lists. That is a feature: authors can group related rules under a virtual namespace in the source while still compiling to a single flat OTP supervision list—provided everyone agrees what `Module.concat` will produce.

---

## `Module.concat/1` and `defmodule unquote(modulo)`

`Module.concat([A, B, C])` yields the atom `A.B.C` without string surgery:

```elixir
quote do
  defmodule unquote(modulo) do
    # generated callbacks...
  end
end
```

Here `modulo` is bound at macro expansion time—e.g. `Tec0301Pon.Examples.Estufa.Regras.RegraIrrigacao` when the rule lives in [`estufa_regras.ex`](../../../lib/tec0301_pon/examples/estufa_regras.ex).

Prefer atoms from **parsed source**, not `String.to_atom/1` on runtime input—compile-time segments are safe; user-driven strings are not (atom table pressure and injection class issues). If you ever build module names from config, use **`String.to_existing_atom/1`** with a whitelist, or avoid dynamic modules entirely.

---

## Worked example: grep the examples tree

Run a mental exercise on [`lib/tec0301_pon/examples/`](../../../lib/tec0301_pon/examples/): pick `Estufa.Regras`, `AlarmeSimples.Regras`, or `SmartBrewery.Regras`. For each `defrule Foo`, the **Elixir module** is `Parent.Foo` where `Parent` is the module that contains the `defrule`. Open `:code.which/1` in `iex` after compilation if you want to see the beam file path reflect that nesting.

Maya used that drill in onboarding: new hires named a rule, predicted the module atom, then verified with `Module.safe_concat/1` in a script. Wrong predictions meant they still thought in “Ruby classes” instead of “prefix + suffix atoms.”

---

## Why Riverbank cared about OTP spelling

Each generated submodule is its own compilation unit. If rules live under `Riverbank.Irrigation.Rules.*`, grep and supervisors tell the same story. If names flatten to opaque atoms or land under the DSL implementation package, Tuesday’s incident comes back with a different stack trace every time.

Joe Armstrong’s thesis and later BEAM practice emphasize **named** replacement units for code change (see Part 1 footnote). Small generated modules align with that model: you can reload `Riverbank.Irrigation.Rules.PumpCutoff` without rewriting the entire rules corpus—**if** the atom you pass to `Regra.start_link/3` matches the module you think you are running.

---

## Process / checklist: naming before macros

1. **Pick the parent module deliberately** (`Riverbank.Irrigation.Rules`, not `Riverbank.RulesDSL`).  
2. **Document the naming rule** in `@moduledoc`—one sentence saves ten Slack threads.  
3. **Test** that `Module.concat([parent, :SmokeTest])` matches expectations in a tiny compile fixture.  
4. **Supervise** using the generated `start_link/0` or explicit child specs—never magic strings.  
5. **Hot upgrade drills**: confirm which module atoms `:code.load_file/1` replaces in staging.

---

## Supervision wires: why the atom must match your children

When Riverbank finally typed their `Application` child list, every tuple looked like `{Module, :start_link, args}` or a `Supervisor.child_spec/1` map pointing at a **module**. That module atom is the same one `Module.concat` produced when `defrule` expanded. If you hand-start processes with `spawn` and anonymous funs, you can pretend names do not matter; the moment you use `DynamicSupervisor`, `Registry`, or `Phoenix.PubSub`-style naming, **atoms become your address book**.

Maya drew two columns on the whiteboard. In the left column she listed **author-facing** names: `RegraIrrigacao`, `CorteBomba`. In the right column she wrote the **fully qualified** atoms the compiler would actually register. New hires copied the right column into their notebooks until the pattern was reflexive. Ops used the right column when filtering logs in Grafana. Security reviews used it when asking “which module owns this side effect?”—a question that is meaningless if generated code lives under the wrong parent.

The PON engine’s [`Regra.start_link/3`](../../../lib/tec0301_pon/pon/regra.ex) takes `fatos_monitorados` and a **`modulo` atom** in module mode. That atom must resolve to a module exporting `avaliar/1` and `executar/1`. If `Module.concat` drifted, you would still **start** a process—`Regra` is polite—but stack traces and hot upgrades would describe a module your mental model does not recognize. Jordan called that “the silent misconfiguration”: everything runs until the day you need to patch **one** rule under fire.

---

## Edge cases: `__MODULE__` inside generated code (this is correct)

Novices confuse two different appearances of `__MODULE__`. Inside the **quoted template** that defines a generated submodule, `__MODULE__` refers to **that child module** once compiled. Builder’s `start_link_impl` quotes `Tec0301Pon.PON.Regra.start_link(unquote(fatos), __MODULE__, ...)` **inside** `defmodule unquote(modulo) do`—so `__MODULE__` is **supposed** to be the generated rule module. That is distinct from `__MODULE__` inside `defp build_defrule_ast/6` sitting next to the macro definition, which would wrongly read `Tec0301Pon.PON.Builder`.

When reviewing macro PRs, Riverbank used a color highlighter metaphor: **green** `__MODULE__` lives only inside `quote` blocks that become author modules; **red** `__MODULE__` in helpers that compute `modulo` from arguments is almost always a bug. Part 5 generalizes the rule to **`caller.module`** for prefixes.

---

## Naming policy for large teams

If every engineer names rules after their first idea, you collide under a flat parent (`Rules.Alarm` twice in different files). Elixir will not compile duplicate modules—good—but the error can look like “module already defined” without pointing at the **other** file. Riverbank adopted a **prefix convention** in the rule atom itself (`Irrigation.PumpCutoff` as a multi-segment alias) or split parents (`Riverbank.Irrigation.Rules` vs `Riverbank.Safety.Rules`) so grep stays honest.

Document whether **nested aliases** in `defrule Nested.Name` are encouraged or banned. Builder supports multi-segment `parts`; policy belongs to your org. Fowler’s DSL book calls this the **notation governance** problem: without it, internal DSLs decay into dialects.

---

## Echoes from other Elixir “use” ecosystems

Phoenix `use MyAppWeb, :controller` and `use Ecto.Schema` also expand into imports and attributes. They rarely generate **sibling modules** the way PON’s Builder does; instead they configure **the current module**. The difference matters when teaching: Phoenix newcomers learn “`use` sets up this file,” while PON authors learn “`use` imports macros that **manufacture neighbors**.” If you mix mental models, you grep for the wrong module name when debugging.

When Riverbank compared notes with another team using `TypedStruct` or `NimbleOptions`, the shared truth was still **`Module.concat` discipline**: any macro that defines a nested module must decide prefix policy once and test it.

---

## Beam files, code paths, and “where did this module load from?”

During an incident drill, Ops asked which `.beam` belonged to `Riverbank.Irrigation.Rules.PumpCutoff`. The answer is discovered through `:code.which/1` or release overlays—not through the DSL source file alone. Teaching this early prevents superstition: **the module atom is the truth**; the file is how humans navigate. When `Module.concat` mis-parents a name, `:code.which/1` still returns *some* path, often the wrong app’s object dir, which is why Jordan paired **grep** for `defmodule Riverbank.Irrigation.Rules` with **runtime** checks in staging.

For releases, `mix release` and overlay configs may load different code paths than local `MIX_ENV=dev`. Always validate **module names** in staging with a one-liner script that prints `Application.spec(:your_app, :modules)` filtered by a prefix—cheap confidence before go-live.

If your app is not the canonical holder of `:modules` in older releases, fall back to `:code.all_loaded/0` filtered by prefix—noisier but sufficient for spot checks.

---

## A footnote for the curious (literature)

BEAM **modules** are compilation and code-loading units; hot code swap loves **named** units (Armstrong, 2003; Cesarini & Thompson, 2016). Generating many small modules matches that model—also why named functions in module mode beat stale closures in the PON story ([Part 3](../03_metaprogrammed_dsl_defrule_defpremissa.md), [`Regra`](../../../lib/tec0301_pon/pon/regra.ex) docs).

`__aliases__` is how Elixir embeds host-language qualified names in macro-friendly AST (Fowler’s internal DSL framing applies: the surface syntax is Elixir; the tree is your interoperability format). McCord’s *Metaprogramming Elixir* shows `__aliases__` unpacking in several macro examples. Full citation rows live in [BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md).

For a Portuguese deep dive on the motor PON and process layout—including why module references matter operationally—see [`docs/artigos/02_motor_pon_beam.md`](../../../docs/artigos/02_motor_pon_beam.md); this English series only summarizes that link.

---

## What still felt wrong until the next morning

Maya had fixed `Module.concat`, but one refactor briefly dropped **`caller`** from `build_defrule_ast/6`. `__MODULE__` inside the helper pointed at the **Builder**, not Riverbank. Jordan caught it in review. [Part 5](05___CALLER___and_lexical_module_context.md) names that bug so you never ship it.

---

## References

- Elixir [`Module.concat/1`](https://hexdocs.pm/elixir/Module.html#concat/1).
- Armstrong, J. (2003). *Making reliable distributed systems…* (PhD thesis).
- Cesarini, F.; Thompson, S. (2016). *Programming Erlang* (2nd ed.).
- Fowler, M. (2010). *Domain-Specific Languages*; McCord, C. (2015). *Metaprogramming Elixir*.
- [PON Part 2 — whiteboard to OTP](../02_from_whiteboard_to_code_otp.md); [Part 3 — DSL](../03_metaprogrammed_dsl_defrule_defpremissa.md).

[BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md) · [BIBLIOGRAPHY_PON_SERIES.md](../../BIBLIOGRAPHY_PON_SERIES.md).
