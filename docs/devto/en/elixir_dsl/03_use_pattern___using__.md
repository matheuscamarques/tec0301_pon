---
title: "Building DSLs in Elixir (Part 3): the use pattern — __using__ as your DSL’s front door"
published: false
description: "Part 3 of 10 — New hire opens Riverbank.Rules; Maya adds use RulesDSL. __using__, import, and the author contract behind Tec0301Pon.PON.Builder."
tags: elixir, metaprogramming, macros, dsl, __using__
series: elixir-dsl-building
---

*If this helped you, you can [support the author with a coffee on dev.to](https://dev.to/matheuscamarques/support-with-a-coffee-2oa0).*

# Building DSLs in Elixir (Part 3): the `use` pattern — `__using__` as your DSL’s front door

**Part 3 of 10** — [Index](README.md) · [Part 2](02_ast_essentials_quote_unquote_bind_quoted.md) · Next: [Part 4 — The rule that landed in the wrong neighbourhood](04_generating_modules_names_from_macro_arguments.md)

**Reading time:** long-form draft (~10 min). These posts target about **2,000+ words** each so the Riverbank narrative and the Elixir mechanics both have room to breathe.

---

The new irrigation file opened with three `import` lines and a comment that said “TODO: ask Maya which of these we still need.” Maya winced—she had promised Riverbank a **language**, not a scavenger hunt. Jordan shrugged: “We document `import Riverbank.RulesDSL`,” he offered. Maya shook her head. “We want one line that means *this file speaks greenhouse rules*.”

She added `use Riverbank.RulesDSL` and taught the module what that meant.

In Elixir, `use SomeModule, opt: :value` expands to `SomeModule.__using__([opt: :value])`. Whatever **quoted** block `__using__/1` returns is **injected** at the call site—usually `import`, `alias`, `@before_compile`, or attributes. For a DSL, that line is the **front door**: readers know the file joined a code-generation story before they read the first `defrule`.

The production twin they kept comparing to was [`Tec0301Pon.PON.Builder`](../../../lib/tec0301_pon/pon/builder.ex)—minimal `__using__`, heavy lifting in `defp build_*`.

---

## From the codebase: what `Builder` injects and what it documents

The [`@moduledoc`](../../../lib/tec0301_pon/pon/builder.ex) on `Tec0301Pon.PON.Builder` is worth reading as **product copy** for your own DSL: it lists `defrule` (with `watch`, `when` as AST or string, `do` as block or `instigations`), optional `edge_triggered`, `defpremissa` for derived facts that update when a boolean flips, and `defcondicao` for aggregating boolean premises with `merge: :all | :any` or a custom `when:`. It explicitly says generated modules expose `start_link/0` and belong in the graph bootstrap. That paragraph is the **elevator pitch** Maya wished every internal framework had before anyone wrote a macro.

The `__using__` implementation is deliberately tiny:

```elixir
defmacro __using__(_opts) do
  quote do
    import Tec0301Pon.PON.Builder
  end
end
```

Intentionally tiny: consumer modules get **`defrule` / `defpremissa` / `defcondicao`** in scope without importing all of `Tec0301Pon`. Semantics stay in ordinary `defp` functions the macros call—compilation stays fast, stack traces stay legible.

`_opts` is a promise to tomorrow: `only: [:defrule]`, `strict: true`, `otp_app: :riverbank`—without breaking every file that already said `use`. Riverbank’s fork might later branch on options: strict mode could warn when `watch` lists empty, or attach `@after_compile` hooks for diagnostics. The Elixir community convention is to **keep `__using__` thin** and push complexity into explicit macro calls or support modules so consumers can reason about what happened when they read one line.

---

## Why Maya did not stop at `import`

`import Tec0301Pon.PON.Builder` would have worked technically. `use` buys **room for options**, **convention** in code review, and **one place** to add aliases or hooks. When the team changes how authors enter the DSL, they edit **`__using__`**, not an email template.

Voelter et al. (*DSL Engineering*) stress **scoping DSL surface area**: every extra import is a **commitment** to name resolution and to the mental model of new hires. Fowler’s fluent-builder discussion in *Domain-Specific Languages* fits too: `use MyDSL` is the Elixir-flavored signal that a module opted into a **notation**—reviewers should expect macro-generated submodules and compile-time behavior.

---

## What the PON series already said about `use`

[Part 3 of the Smart Brewery line](../03_metaprogrammed_dsl_defrule_defpremissa.md) shows:

```elixir
defmodule MyApp.Rules do
  use Tec0301Pon.PON.Builder
  # defpremissa ... and defrule ... live here
end
```

and states plainly that `use Tec0301Pon.PON.Builder` **only imports** the macro definitions; the heavy lifting is in `defrule`, `defpremissa`, and friends. This series Part 3 is the **mirror** of that sentence: now you know *how* `use` becomes `import`, and *why* the team keeps the hook small.

The same post walks through conceptual expansion of `defrule` and mentions `edge_triggered`, `instigations`, and the discouraged string form of `when:`. You do not need to reread the whole article here—only remember that **`use` is the gate**, not the engine.

---

## The contract on the sticky note (now `@moduledoc`)

Once a module `use`s the DSL, authors accept that macro calls like `defrule Name, watch: ..., when: ..., do: ...` live at the **module top level**—not inside random `def`s. Each macro expands to **submodules** under the current namespace (Part 4). When someone pastes `defrule` into a function, the error is confusing unless docs say: **expansion is compile-time**.

**If you see a cryptic error about `defmodule` inside a function:** assume someone nested a macro that generates modules. Move the `defrule` to the module body. **If you see “undefined function defrule/2”:** the file forgot `use Tec0301Pon.PON.Builder` (or your wrapper) or the macro module is not compiled yet. **If generated modules land under the wrong namespace:** you are about to read Part 4—`Module.concat` and `__CALLER__.module` are the fix.

The [Smart Brewery metaprogramming post](../03_metaprogrammed_dsl_defrule_defpremissa.md) explains **what** `defrule` means for PON; this chapter is only the **door**: `use` → `import` → macros.

---

## “If you see this error” — learning from `defcondicao`

Not every DSL macro fails with a generic syntax error. [`defcondicao`](../../../lib/tec0301_pon/pon/builder.ex) validates options and **raises** with a clear message when authors combine incompatible keys:

```elixir
cond do
  Keyword.has_key?(opts, :when) and Keyword.has_key?(opts, :merge) ->
    raise ArgumentError, "defcondicao: use either :merge or :when, not both"
  # ...
end
```

Riverbank copied that pattern for their own macros: **fail at expansion time** with a sentence a human can act on. Optional: link to docs or to a single example file in the error message (`Exception.message/1` allows multiline strings—use sparingly). The payoff is fewer Slack threads that start with “it compiled yesterday.”

---

## Worked example: one module, one `use`, many entry points

Open [`Tec0301Pon.Examples.SmartBrewery.Regras`](../../../lib/tec0301_pon/examples/smart_brewery_regras.ex) (or another example under `lib/tec0301_pon/examples/`). The file typically begins with `use Tec0301Pon.PON.Builder` and then stacks `defpremissa`, `defcondicao`, and `defrule` forms that read like an operations spec. Trace **one** `defpremissa`: note `watch`, `when`, `derive`, and `criar_fato`. Without `use`, none of those macros resolve. With `use`, the compiler expands each form into a submodule with `start_link/0` you register beside your other OTP children.

Spend two minutes listing **how many** submodules one example file generates. That count is the social cost of the DSL: more modules, clearer boundaries, more lines in your supervision tree bootstrap. The tradeoff is explicit—better than ten copy-paste modules with drifting `watch` lists.

---

## Process / checklist: designing your own `__using__/1`

1. **Start with zero options.** Match Builder: `import` only. Ship.  
2. **Document the contract** in `@moduledoc` on the DSL module—what macros exist, where they may appear, what they generate.  
3. **Add options only with a migration story.** If `strict: true` will break CI, gate it behind feature flags or codemods.  
4. **Keep heavy logic in `defp` helpers** invoked by macros, not inside `__using__`, so testing and refactoring stay tractable.  
5. **Pair every new option with a test module** that `use`s the DSL under that configuration (Part 10).

Jordan added a sixth item for Riverbank: **code search**. If `use Riverbank.RulesDSL` is the grep anchor for “this file participates in the rule language,” onboarding gets cheaper than hunting three imports.

---

## Lifecycle of a `use` line (compile order in plain language)

When the compiler processes a module body, it expands forms **top to bottom**. A `use Tec0301Pon.PON.Builder` line typically appears **before** the first `defrule`, because the macros must be **in scope** when those calls are expanded. If a new hire pastes `defrule` above `use`, the error is immediate and slightly embarrassing—good—but the fix teaches compile order better than any diagram.

`__using__/1` itself returns a `quote` block that gets **spliced** into the caller. In Builder’s case, that block is only `import Tec0301Pon.PON.Builder`, so the effective result is as if the author had written the import by hand—plus the indirection that lets you evolve the hook. Phoenix contexts often add `alias`, `@derive`, or `import` combinations; Ecto schemas inject `@schema_prefix` patterns. The **weight** of `__using__` signals framework maturity: heavy hooks are not wrong, but they demand documentation.

Riverbank considered `@before_compile` to attach a static analysis pass that counted `watch` list duplicates. They postponed it: `@before_compile` runs late in compilation and surprises newcomers. The lesson for internal DSLs: **earn** advanced hooks by pain, not anticipation.

---

## `@moduledoc` as the author-facing contract (expanded)

The Builder module’s documentation is bilingual in the source (Portuguese) but structurally what you want in any language: bullet list of macros, options, cautions about strings, pointers to `start_link`. When Maya drafted Riverbank’s English `RulesDSL` moduledoc, she copied that shape: **what you may write**, **what you must not write**, **what gets generated**, **how to start children**.

She added a **FAQ** subsection after the first intern pasted `defrule` into a `test` block inside a function. The FAQ entry is one sentence: “Macros that define modules belong at module scope.” Linking to Part 4–5 of this series from internal docs reduced repeat questions.

---

## Comparison: raw `import` vs `use` in cross-team politics

Platform teams love **`import`** because it is explicit. Product teams love **`use`** because it reads like opting into a language. The compromise that usually survives politics: **`use MyApp.DSL`** that only `import`s a **small** surface (`defrule`, `defpremissa`) and **re-exports nothing else**. Builder follows that compromise. If your `use` drags in half of `Kernel`, you will hear about it in review—and you should.

---

## Versioning `__using__/1` when the DSL grows teeth

Riverbank’s second DSL revision wanted `use Riverbank.RulesDSL, otp_app: :riverbank` so generated modules could read compile-time configuration—think maximum `watch` list sizes or feature flags. They kept the default `_opts = []` path identical so **existing files** compiled untouched. New options were **keyword-only** and documented beside `__using__` in the same commit that read them.

Maya’s rule: **never** remove an option without a deprecation cycle in internal apps; macro options are API. Voelter et al. call this **language evolution**: if your notation is code, semver applies to the macros too.

When Riverbank shipped `strict: true`, it warned on empty `watch` lists at compile time—implemented as a `__using__` option stored in a module attribute consumed by a later `@after_compile` hook (they borrowed the idea from Ecto’s schema warnings). The implementation detail matters less than the product lesson: **`use` options are how DSLs evolve without breaking every call site at once**.

If you never ship options, document that explicitly: “`use MyApp.DSL` accepts no options today; prefer explicit imports only when forking internally.” Future you will thank present you when grep finds a single expansion path.

---

## A footnote for the curious (literature)

`use` is a **compile-time hook**, not runtime delegation. Elixir expands it while compiling the module; nothing at runtime “calls `use` again” unless you dynamically compile code—a different story. McCord’s *Metaprogramming Elixir* walks through `__using__`, `@before_compile`, and `__after_compile__` with examples that mirror how Phoenix and Ecto expose extension points.

Voelter et al. describe DSL modules as **layers**: notation, semantics, IDE support, evolution. Your `__using__` line is part of the **notation layer**—it signals human readers and tooling alike. Fowler’s work on internal DSLs reminds us that **fluency** is not free; if `use` imports too much magic, the file becomes harder to read than the golden modules it replaces. The bibliography tables in [BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md) collect the full citations for this footnote and for Part 1’s theory-heavy notes.

---

## The bug waiting in the next compile

The first `use` worked. The first `defrule` compiled. Then Jordan noticed the generated module’s name: it looked like it lived under the **DSL library**, not under `Riverbank.Irrigation.Rules`. Maya’s stomach dropped—the namespace story was wrong. [Part 4](04_generating_modules_names_from_macro_arguments.md) is the walk home through `__aliases__` and `Module.concat`, and [Part 5](05___CALLER___and_lexical_module_context.md) hands her `__CALLER__` so the rules finally go home.

---

## References

- Elixir [`Kernel.use/2`](https://hexdocs.pm/elixir/Kernel.html#use/2).
- McCord, C. (2015). *Metaprogramming Elixir*. Pragmatic Bookshelf.
- Voelter, M.; et al. (2013). *DSL Engineering*. [dslbook.org](http://dslbook.org/).
- Fowler, M. (2010). *Domain-Specific Languages*. Addison-Wesley.
- [`Tec0301Pon.PON.Builder`](../../../lib/tec0301_pon/pon/builder.ex) source.
- [PON Part 3 — metaprogrammed DSL](../03_metaprogrammed_dsl_defrule_defpremissa.md).

[BIBLIOGRAPHY_DSL_SERIES.md](BIBLIOGRAPHY_DSL_SERIES.md) · [BIBLIOGRAPHY_PON_SERIES.md](../../BIBLIOGRAPHY_PON_SERIES.md).
