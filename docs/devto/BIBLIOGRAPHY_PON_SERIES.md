# Bibliography — PON + Smart Brewery dev.to series (EN drafts)

Normalized references used across [`docs/devto/en/`](en/). When publishing on dev.to, prefer stable URLs; verify DOIs and publisher pages periodically.

**DSL / metaprogramming series:** extended references for *Building DSLs in Elixir* live in [`docs/devto/en/elixir_dsl/BIBLIOGRAPHY_DSL_SERIES.md`](en/elixir_dsl/BIBLIOGRAPHY_DSL_SERIES.md) (Fowler, Voelter, Kohlbecker et al., PLAI, etc.).

## Paradigms and architecture

| Author(s) | Year | Title | Where |
|-----------|------|--------|--------|
| Simão, J. M.; Borges, M. R.; Ebina, R.; Tacla, C. A.; Stadzisz, P. C.; Banaszewski, R. F. | 2013 | *Notification Oriented Paradigm (NOP) and Imperative Paradigm: A Comparative Study* | [SCIRP / IJSEA](https://www.scirp.org/journal/paperinformation?paperid=19842) — academic treatment of NOP (closely related to “notification-oriented” rule structuring; this repo uses **PON** as shorthand). |
| Cockburn, A. | 2005 | *Hexagonal architecture* (ports and adapters) | [alistair.cockburn.us](https://alistair.cockburn.us/hexagonal-architecture/) |
| Fowler, M. | 2015 | *Ports and Adapters / Hexagonal architecture* (summary) | [martinfowler.com](https://martinfowler.com/bliki/HexagonalArchitecture.html) |

## Erlang, Elixir, OTP

| Author(s) | Year | Title | Where |
|-----------|------|--------|--------|
| Armstrong, J. | 2003 | *Making reliable distributed systems in the presence of software errors* (PhD thesis) | [erlang.org](https://www.erlang.org/download/armstrong_thesis_2003.pdf) |
| Cesarini, F.; Thompson, S. | 2016 | *Programming Erlang (2nd ed.)* | Pragmatic Bookshelf — OTP design, processes, supervision. |
| *Elixir documentation* | — | `GenServer`, `Registry`, `Supervisor`, `Macro`, `@behaviour` | [hexdocs.pm/elixir](https://hexdocs.pm/elixir/) |
| *Mix profiling tasks* | — | `mix profile.cprof`, `eprof`, `fprof`, `tprof` | [hexdocs.pm/mix/Mix.Tasks.Profile.Cprof.html](https://hexdocs.pm/mix/Mix.Tasks.Profile.Cprof.html) and sibling task modules |

## Phoenix ecosystem

| Author(s) | Year | Title | Where |
|-----------|------|--------|--------|
| *Phoenix LiveView* | — | Guides and API | [hexdocs.pm/phoenix_live_view](https://hexdocs.pm/phoenix_live_view/) |
| *Phoenix PubSub* | — | API | [hexdocs.pm/phoenix_pubsub](https://hexdocs.pm/phoenix_pubsub/) |

## Data pipelines and observability

| Author(s) | Year | Title | Where |
|-----------|------|--------|--------|
| *Broadway* | — | Documentation | [hexdocs.pm/broadway](https://hexdocs.pm/broadway/) |
| *GenStage* | — | Documentation | [hexdocs.pm/gen_stage](https://hexdocs.pm/gen_stage/) |
| *Telemetry* | — | `telemetry` for Erlang/Elixir | [hexdocs.pm/telemetry](https://hexdocs.pm/telemetry/) |
| Timescale, Inc. | — | TimescaleDB documentation | [docs.timescale.com](https://docs.timescale.com/) |

## Analytics and BI

| Author(s) | Year | Title | Where |
|-----------|------|--------|--------|
| Kimball, R.; Ross, M. | 2013 | *The Data Warehouse Toolkit (3rd ed.)* — dimensional modeling | Wiley — star schema, facts/dimensions. |
| Microsoft | — | Power BI REST APIs (push datasets, etc.) | [Microsoft Learn — Power BI REST](https://learn.microsoft.com/en-us/rest/api/power-bi/) |
| PostgreSQL Global Development Group | — | `GRANT`, roles, row security | [postgresql.org/docs](https://www.postgresql.org/docs/current/ddl-rowsecurity.html) |

## Digital twins and industrial context

| Author(s) | Year | Title | Where |
|-----------|------|--------|--------|
| Grieves, M. | 2014 | *Digital Twin: Manufacturing Excellence Through Virtual Factory Replication* | Often cited white paper on digital-twin vocabulary (search publisher copy; ISBN/institutional PDFs vary). |

## Machine learning lifecycle

| Author(s) | Year | Title | Where |
|-----------|------|--------|--------|
| Breck, E.; et al. | 2017 | *The ML Test Score: A Rubric for ML Production Readiness and Technical Debt Reduction* | [research.google](https://research.google/pubs/pub46555/) |
| *Elixir Numerics* | — | Axon, Scholar (Neural Network / traditional ML in Elixir) | [hexdocs.pm/axon](https://hexdocs.pm/axon/), [hexdocs.pm/scholar](https://hexdocs.pm/scholar/) |

## Queues, performance, back-pressure

| Author(s) | Year | Title | Where |
|-----------|------|--------|--------|
| Little, J. D. C. | 1961 | *A Proof for the Queuing Formula L = λW* | *Operations Research* — foundation for **Little’s Law** (relation of queue length, arrival rate, wait); [Wikipedia summary](https://en.wikipedia.org/wiki/Little%27s_law) with citation to original. |
| *Erlang docs* | — | `:erlang.process_info/2` (mailbox size, etc.) | [erlang.org/doc/man/erlang.html](https://www.erlang.org/doc/man/erlang.html) |

## This repository (deep dives in Portuguese or internal)

| Topic | Path |
|--------|------|
| Performance, profilers, env matrix | [`docs/performance-dev.md`](../performance-dev.md) — EN series walkthrough: [Part 11 on dev.to — Dev profiling…](https://dev.to/matheuscamarques/dev-profiling-cpu-memory-and-what-changed-after-optimizations-28hb) · [repo draft](en/11_dev_profiling_cpu_memory_optimizations.md) |
| Memory pressure heuristics | [`docs/memory-pressure-heuristics.md`](../memory-pressure-heuristics.md) |
| Message storm mitigation | PT: [`docs/artigos/19_mitigacao_message_storm_pon_elixir_smart_brewery.md`](../artigos/19_mitigacao_message_storm_pon_elixir_smart_brewery.md) — EN series: [Part 10 on dev.to — When notifications explode…](https://dev.to/matheuscamarques/when-notifications-explode-message-storms-deduplication-and-back-pressure-in-pon-34p4) · [repo draft](en/10_when_notifications_explode_message_storms_pon.md) |
| ML practical guide (PT) | [`docs/artigos/27_guia_pratico_treino_ml_smart_brewery.md`](../artigos/27_guia_pratico_treino_ml_smart_brewery.md) |
| Power BI / realtime notes | [`docs/power-bi-realtime.md`](../power-bi-realtime.md) |

---

**Published on dev.to:** [Bibliography — PON + Smart Brewery dev.to series (EN drafts)](https://dev.to/matheuscamarques/bibliography-pon-smart-brewery-devto-series-en-drafts-58a9) — tracked in [`docs/devto_serie_pon_smart_brewery.md`](../devto_serie_pon_smart_brewery.md). **Source of truth** for tables and repo paths remains this file in the repository.
