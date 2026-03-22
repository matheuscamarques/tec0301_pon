---
title: "A metaprogrammed DSL: defrule and defpremissa with less PON boilerplate"
published: true
description: "Part 3 of 12 — How Tec0301Pon.PON.Builder turns declarative rules and premises into OTP-ready submodules: macros, instigations, edge_triggered, and bootstrap order."
tags: elixir, otp, metaprogramming, architecture
series: pon-smart-brewery
---

*If this helped you, you can [support the author with a coffee on dev.to](https://dev.to/matheuscamarques/support-with-a-coffee-2oa0).*

# A metaprogrammed DSL: `defrule` and `defpremissa` with less PON boilerplate

**Part 3 of 12** — [Part 1 on dev.to — PON in Elixir: why the BEAM fits reactive rules](https://dev.to/matheuscamarques/notification-oriented-paradigm-pon-in-elixir-why-the-beam-fits-reactive-rules-2p9e) · [repo draft](01_pon_in_elixir_why_beam.md) introduced PON and the raw `Fato` / `Regra` API. [Part 2 on dev.to — From whiteboard to code: mapping Facts, Rules, and Premises to OTP processes](https://dev.to/matheuscamarques/from-whiteboard-to-code-mapping-facts-rules-and-premises-to-otp-processes-1blb) · [repo draft](02_from_whiteboard_to_code_otp.md) traced notifications through `Registry` and `GenServer` processes. This post adds the **ergonomic layer**: macros in `Tec0301Pon.PON.Builder` that generate small modules so you write **`watch` / `when` / `do`** instead of hand-rolling `avaliar/1`, `executar/1`, and `start_link/0` every time.

---

## Why macros here?

In Elixir, a rule backed by `Tec0301Pon.PON.Regra` in **module mode** needs:

- A function that implements **when** the rule should fire (`avaliar/1` over a `memoria` map).
- A function that performs the **action** (`executar/1`).
- A `start_link/0` that calls `Regra.start_link(watched_facts, __MODULE__, ...)`.

A premise backed by `Tec0301Pon.PON.Premissa` needs a **condition** and a `start_link/0` that wires `Premissa.start_link/4`.

That is repetitive and easy to get subtly wrong. The Builder macros **expand at compile time** into **nested modules** under your namespace (e.g. `MyApp.Rules.Cooling` inside `MyApp.Rules`), each with the right callbacks and `start_link/0`. At runtime you only start processes—no macro cost on the hot path. That split—compile-time code generation vs runtime message handling—is standard Elixir metaprogramming (`quote` / `unquote`, `__CALLER__`); see the official [`Macro`](https://hexdocs.pm/elixir/Macro.html) module and McCord’s *Metaprogramming Elixir* (Pragmatic) for the wider pattern language.

```elixir
defmodule MyApp.Rules do
  use Tec0301Pon.PON.Builder
  # defpremissa ... and defrule ... live here
end
```

`use Tec0301Pon.PON.Builder` only **imports** the macro definitions; the heavy lifting is in `defrule`, `defpremissa`, and friends.

## What `defrule` expands to (conceptually)

Each `defrule Name, watch: [...], when: ..., do: ...` becomes a module `MyApp.Rules.Name` (name parts are taken from the macro’s identifier and concatenated with the **caller module**).

Roughly, the generated module contains:

- **`avaliar(memoria)`** — body of your `when:` clause (injected AST).
- **`executar(memoria)`** — your `do:` block, **or** a loop of `Task.start(mod, fun, args)` when you use **instigations**.
- **`start_link/0`** — `Tec0301Pon.PON.Regra.start_link(watched_facts, __MODULE__, opts)` so the rule process uses **this** module’s `avaliar/1` and `executar/1`.

That last point matters: because `Regra` holds an atom referring to **your** generated module, you can **upgrade the module** in a release and change rule logic while facts keep running—hot code swapping is a BEAM feature the DSL is aligned with (operational details stay out of this post).

### Expansion sketch (not the real quoted AST)

If you wrote `defrule Example, watch: [:a], when: memoria[:a] == 1, do: :ok` inside `MyApp.Rules`, compile-time expansion conceptually yields something like:

```elixir
# Conceptual — actual code is built with Macro.quote in Builder
defmodule MyApp.Rules.Example do
  def avaliar(memoria), do: memoria[:a] == 1
  def executar(memoria), do: :ok

  def start_link do
    Tec0301Pon.PON.Regra.start_link([:a], __MODULE__, edge_triggered: false)
  end
end
```

`defpremissa` is analogous: a nested module with `condicao/1` and `start_link/0` calling `Premissa.start_link/4`. Inspect expanded code in a scratch module with `Macro.expand` if you enjoy reading `quote` output.

### Options worth knowing

- **`edge_triggered: true`** — passed through to `Regra.start_link/3`; the action runs only on **false → true** transitions of the condition (see Part 2 / `Regra` docs).
- **`do: [instigations: [{Mod, :fun, [args]}, ...]]`** — instead of an arbitrary block, spawn **Tasks** to call MFA tuples when the rule fires. Useful to fan out work or call adapters without blocking the rule process.
- **`when:` as a string** — a separate macro clause compiles to `Code.eval_string/2` over `memoria: memoria`. That exists for flexibility (e.g. config-driven rules), but **prefer the normal AST `when:`** in application code: eval’d strings are harder to test, refactor, and secure.

Example with a normal `when:` and `do:` block (brewery-flavored, same spirit as the project README):

```elixir
defmodule MyApp.Rules do
  use Tec0301Pon.PON.Builder

  defpremissa HighAmbient,
    watch: [:ambient_temp],
    when: (memoria[:ambient_temp] || 0) > 30,
    derive: :high_temp,
    criar_fato: true

  defrule StartCooling,
    watch: [:high_temp, :compressor_state],
    when: memoria[:high_temp] == true and memoria[:compressor_state] == :off,
    do: MyApp.Actuators.start_compressor()
end
```

### Instigations

Pattern borrowed from the test suite (`Tec0301Pon.PON.BuilderTest.RegrasInstigations`):

```elixir
defmodule MyApp.Rules do
  use Tec0301Pon.PON.Builder

  defrule NotifyOps,
    watch: [:alarm_level],
    when: memoria[:alarm_level] == :critical,
    do: [instigations: [{MyApp.Notifications, :page_on_call, []}]]
end
```

When the condition holds, the generated `executar/1` starts a `Task` per `{mod, fun, args}`.

### String `when:` (discouraged for most apps)

```elixir
defrule ThresholdFromConfig,
  watch: [:sensor_x],
  when: "memoria[:sensor_x] > 10",
  do: :ok
```

This generates `avaliar/1` that evaluates the string at runtime. Use sparingly; never feed untrusted input into that string.

## What `defpremissa` expands to

`defpremissa Name, watch: [...], when: ..., derive: :fact [, criar_fato: true]` generates a submodule whose **`start_link/0`** calls:

`Premissa.start_link(derive_fact, watch_list, &condicao/1, criar_fato_derivado: ...)`

with **`condicao/1`** equal to your `when:` body.

- **`watch`** — source fact atoms (one or two in the underlying `Premissa` API).
- **`derive`** — the **derived** fact name that other rules can watch.
- **`criar_fato: true`** — if the derived fact process does not exist yet, start it with initial value `false` before subscribing.

Behavior matches Part 2: the premise process **registers** on the Registry keys for source facts and only calls `Fato.atualizar/2` on the derived fact when the **boolean result changes**, avoiding notification spam.

## Bonus: `defcondicao` — aggregate premises

When several boolean facts must be combined (AND/OR) before a single downstream rule fires, **`defcondicao`** generates a submodule whose `start_link/0` delegates to `Tec0301Pon.PON.Condicao` with either:

- **`merge: :all`** — every watched value must be strictly `true` (AND).
- **`merge: :any`** — at least one `true` (OR).
- **`when: expr`** — custom combination over `memoria`.

```elixir
defmodule MyApp.Rules do
  use Tec0301Pon.PON.Builder

  defcondicao AlarmArmed,
    watch: [:high_temp, :low_pressure],
    merge: :all,
    derive: :alarm_ready,
    criar_fato: true

  defrule SoundAlarm,
    watch: [:alarm_ready],
    when: memoria[:alarm_ready] == true,
    do: MyApp.Actuators.sound_alarm()
end
```

You cannot pass **both** `merge:` and `when:`; the macro raises at compile time.

## Bootstrap order (still your responsibility)

The DSL does **not** start your supervision tree for you. A reliable order is:

1. **`Application.ensure_all_started(:tec0301_pon)`** (or include the app in your release) so ETS and `Tec0301Pon.PON.PubSub` exist.
2. **Start every raw fact** the graph needs with `Fato.start_link(name, initial_value)` (source sensors and any derived facts **unless** `criar_fato: true` creates them).
3. **Start premises and conditions** (`MyApp.Rules.HighAmbient.start_link/0`, `MyApp.Rules.AlarmArmed.start_link/0`, …).
4. **Start rules** (`MyApp.Rules.StartCooling.start_link/0`, …).

Integration tests in the repo follow this pattern under `Tec0301Pon.PonCase` with optional `Tec0301Pon.PON.Service` registration for global statistics.

### Minimal end-to-end sketch

```elixir
Application.ensure_all_started(:tec0301_pon)

alias Tec0301Pon.PON.Fato
alias MyApp.Rules

{:ok, _} = Fato.start_link(:ambient_temp, 22)
{:ok, _} = Fato.start_link(:compressor_state, :off)

{:ok, _} = Rules.HighAmbient.start_link()
{:ok, _} = Rules.StartCooling.start_link()

Fato.atualizar(:ambient_temp, 35)
# HighAmbient may set :high_temp; StartCooling may run if compressor is :off
```

Adjust module names to match your `defrule` / `defpremissa` identifiers.

## Side effects and Part 4

Examples above call `MyApp.Actuators` or `MyApp.Notifications` directly inside `do:` or instigations. That is clear for a blog post, but in a larger system you will want **ports and adapters** so the PON core stays testable and swappable. [**Part 4 on dev.to**](https://dev.to/matheuscamarques/hexagonal-architecture-pon-ports-adapters-to-decouple-the-engine-3l54) covers hexagonal boundaries around the engine; the macros stay the same—you only change **what** `executar/1` and instigations call.

## Summary

| Macro           | Generates                         | Runtime process        |
|-----------------|-----------------------------------|-------------------------|
| `defrule`       | `avaliar/1`, `executar/1`, `start_link/0` | `Regra` (module mode)   |
| `defpremissa`   | `condicao/1`, `start_link/0`      | `Premissa`              |
| `defcondicao`   | `start_link/0` (+ optional `combine/1`)     | `Condicao`              |

`Tec0301Pon.PON.Builder` is the compile-time bridge between **declarative** PON graphs and the **OTP** mechanics from Part 2. Prefer AST `when:` clauses, understand `edge_triggered` and instigations, and start facts before premises and rules.

## References and further reading

- **Elixir `Macro`** — `quote`, `unquote`, hygiene — [HexDocs](https://hexdocs.pm/elixir/Macro.html).
- **McCord, C.** — *Metaprogramming Elixir* (Pragmatic Bookshelf) — DSLs and `use`/`__using__` patterns.
- **Elixir `Kernel.SpecialForms`** — `defmacro` — [HexDocs](https://hexdocs.pm/elixir/Kernel.SpecialForms.html).
- **In this repo** — `lib/tec0301_pon/pon/builder.ex`; `mix docs` for `Tec0301Pon.PON.Builder`, `Regra`, `Premissa`, `Condicao`. Expanded list: [Bibliography on dev.to — PON + Smart Brewery series (EN drafts)](https://dev.to/matheuscamarques/bibliography-pon-smart-brewery-devto-series-en-drafts-58a9) · [repo draft](../BIBLIOGRAPHY_PON_SERIES.md).

---

**Published on dev.to:** [A metaprogrammed DSL: `defrule` and `defpremissa` with less PON boilerplate](https://dev.to/matheuscamarques/a-metaprogrammed-dsl-defrule-and-defpremissa-with-less-pon-boilerplate-3909) — tracked in [`docs/devto_serie_pon_smart_brewery.md`](../../devto_serie_pon_smart_brewery.md).

**Previous:** [Part 2 on dev.to — From whiteboard to code: mapping Facts, Rules, and Premises to OTP processes](https://dev.to/matheuscamarques/from-whiteboard-to-code-mapping-facts-rules-and-premises-to-otp-processes-1blb) · [repo draft](02_from_whiteboard_to_code_otp.md)  
**Next:** [Part 4 on dev.to — Hexagonal architecture + PON: Ports & Adapters to decouple the engine](https://dev.to/matheuscamarques/hexagonal-architecture-pon-ports-adapters-to-decouple-the-engine-3l54) · [repo draft](04_hexagonal_pon_ports_adapters.md).
