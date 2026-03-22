# Série dev.to — TEC0301 / PON + Smart Brewery

Documento de apoio para publicação no [dev.to](https://dev.to): títulos em sequência, variantes e tags. O conteúdo técnico de fundo está alinhado ao [sumário interno](artigos/sumario.md).

**Perfil no dev.to:** [dev.to/matheuscamarques](https://dev.to/matheuscamarques) — use este URL em referências curtas (“siga no dev.to”, índice de posts).

---

## Spin-off (EN) — Smart Brewery domain logic

Série **ortogonal** à tabela principal deste ficheiro: texto em inglês centrado no **processo cervejeiro**, nos **onze FBEs**, nas **doze regras PON** e em **normas e KPIs** (ISO 10816-3, NR-13, ISA-88, ISO 23247, OEE, CIP, etc.), em vez de arquitetura PON/OTP/Phoenix.

| Recurso | Caminho no repositório |
|---------|-------------------------|
| Índice da série (10 partes + checklist dev.to) | [`docs/devto/en/smart_brewery_domain_logic/README.md`](devto/en/smart_brewery_domain_logic/README.md) |
| Bibliografia de domínio | [`docs/devto/en/smart_brewery_domain_logic/DOMAIN_BIBLIOGRAPHY.md`](devto/en/smart_brewery_domain_logic/DOMAIN_BIBLIOGRAPHY.md) |
| Mapeamento ISO 23247 (PT, prosa) | [`docs/artigos/12_mapeamento_iso_23247.md`](artigos/12_mapeamento_iso_23247.md) |

**Série sugerida no dev.to:** tag ou `series` coerente com o README (ex.: `smart-brewery-domain`).

---

## Ordem de publicação (12 posts técnicos + bibliografia) — português

Use subtítulo ou descrição do post com **Parte X de 12** nos artigos técnicos. No [dev.to](https://dev.to), a série **pon-smart-brewery** pode listar uma **13.ª entrada** com a [bibliografia consolidada (EN)](https://dev.to/matheuscamarques/bibliography-pon-smart-brewery-devto-series-en-drafts-58a9) — espelho de [`docs/devto/BIBLIOGRAPHY_PON_SERIES.md`](devto/BIBLIOGRAPHY_PON_SERIES.md).

A coluna **Post no dev.to** deve receber o link público de cada post assim que estiver publicado (substitua *a publicar*). Enquanto isso, use o **Rascunho (repo)** para o texto-fonte em inglês quando existir.

| Parte | Título | Post no dev.to | Rascunho (repo) |
|------:|--------|----------------|-----------------|
| 1 | **Paradigma Orientado a Notificações (PON) em Elixir: por que a BEAM é um bom lugar para regras reativas** | [Parte 1 (EN)](https://dev.to/matheuscamarques/notification-oriented-paradigm-pon-in-elixir-why-the-beam-fits-reactive-rules-2p9e) | [EN — parte 1](devto/en/01_pon_in_elixir_why_beam.md) |
| 2 | **Do papel ao código: mapeando Fatos, Regras e Premissas para processos OTP** | [Parte 2 (EN)](https://dev.to/matheuscamarques/from-whiteboard-to-code-mapping-facts-rules-and-premises-to-otp-processes-1blb) | [EN — parte 2](devto/en/02_from_whiteboard_to_code_otp.md) |
| 3 | **DSL com metaprogramação: `defrule` e `defpremissa` para escrever menos boilerplate PON** | [Parte 3 (EN)](https://dev.to/matheuscamarques/a-metaprogrammed-dsl-defrule-and-defpremissa-with-less-pon-boilerplate-3909) | [EN — parte 3](devto/en/03_metaprogrammed_dsl_defrule_defpremissa.md) |
| 4 | **Hexagonal + PON: Ports & Adapters para não acoplar o motor ao mundo real** | [Parte 4 (EN)](https://dev.to/matheuscamarques/hexagonal-architecture-pon-ports-adapters-to-decouple-the-engine-3l54) | [EN — parte 4](devto/en/04_hexagonal_pon_ports_adapters.md) |
| 5 | **Smart Brewery: um gêmeo digital cervejeiro como laboratório para o PON** | [Parte 5 (EN)](https://dev.to/matheuscamarques/smart-brewery-a-digital-twin-brewery-as-a-pon-lab-36mf) | [EN — parte 5](devto/en/05_smart_brewery_digital_twin_pon_lab.md) |
| 6 | **Phoenix LiveView e tempo real: painel operacional sobre um motor de regras** | [Parte 6 (EN)](https://dev.to/matheuscamarques/phoenix-liveview-in-real-time-an-operations-ui-on-top-of-a-rules-engine-17ci) | [EN — parte 6](devto/en/06_phoenix_liveview_operations_ui_rules_engine.md) |
| 7 | **Da simulação ao armazém: telemetria, Broadway/GenStage e TimescaleDB** | [Parte 7 (EN)](https://dev.to/matheuscamarques/from-simulation-to-storage-telemetry-broadwaygenstage-and-timescaledb-762) | [EN — parte 7](devto/en/07_from_simulation_to_storage_telemetry_broadway_timescaledb.md) |
| 8 | **BI sem mistério: dimensões, fatos e consumo dos dados (ex.: Power BI)** | [Parte 8 (EN)](https://dev.to/matheuscamarques/bi-without-mystery-dimensions-facts-and-consuming-the-data-eg-power-bi-54aj) | [EN — parte 8](devto/en/08_bi_without_mystery_dimensions_facts_power_bi.md) |
| 9 | **ML no gêmeo digital: exportar dados, treinar pilotos e importar predições de volta ao app** | [Parte 9 (EN)](https://dev.to/matheuscamarques/ml-on-the-digital-twin-export-train-pilots-and-import-predictions-back-into-the-app-207i) | [EN — parte 9](devto/en/09_ml_digital_twin_export_train_import_predictions.md) |
| 10 | **Quando as notificações explodem: message storm, deduplicação e padrões de back-pressure no PON** | [Parte 10 (EN)](https://dev.to/matheuscamarques/when-notifications-explode-message-storms-deduplication-and-back-pressure-in-pon-34p4) | [EN — parte 10](devto/en/10_when_notifications_explode_message_storms_pon.md) |
| 11 | **Profiling em produção dev: CPU, memória e o que mudou depois das otimizações** | [Parte 11 (EN)](https://dev.to/matheuscamarques/dev-profiling-cpu-memory-and-what-changed-after-optimizations-28hb) | [EN — parte 11](devto/en/11_dev_profiling_cpu_memory_optimizations.md) |
| 12 | **Retrospectiva: o que aprendi construindo um motor de regras reativo em Elixir** | *a publicar* | [EN — parte 12](devto/en/12_retrospective_reactive_rules_engine_elixir.md) |
| 13 | **Bibliografia normalizada da série (EN)** — livros, papers, HexDocs e mapa `docs/` do repositório | [Bibliografia (EN)](https://dev.to/matheuscamarques/bibliography-pon-smart-brewery-devto-series-en-drafts-58a9) | [`BIBLIOGRAPHY_PON_SERIES.md`](devto/BIBLIOGRAPHY_PON_SERIES.md) |

### Roteiro rápido por post (PT)

1. Eventos, fatos, regras; contraste com avaliação em loop; visão de arquitetura.
2. Registry, GenServer, fluxo de notificações; ainda sem aprofundar macros.
3. Builder, geração de módulos, exemplo mínimo executável.
4. Ações e sensores atrás de portas; testabilidade.
5. Domínio, simulação Monte Carlo; telemetria + regras no mesmo caso.
6. UI, streams, perspectiva do operador; ligação com o backend PON.
7. Pipeline de eventos, TSDB, retenção; runtime da Smart Brewery.
8. Modelo analítico, papéis read-only, integração com BI.
9. `mix export.ml`, treino Elixir/Python, `ml_predictions`, LiveView de predições — ver [guia prático](artigos/27_guia_pratico_treino_ml_smart_brewery.md).
10. Sintomas, ETS/coalescência; mitigação de message storm.
11. Antes/depois: CPU, memória; `persistent_term`, Rete, Broadway.
12. Trade-offs, o que faria diferente; links para os posts anteriores.

---

## Mesma ordem — títulos em inglês (opcional)

| Part | Title |
|-----:|--------|
| 1 | **Notification-Oriented Paradigm (PON) in Elixir: why the BEAM fits reactive rules** |
| 2 | **From whiteboard to code: mapping Facts, Rules, and Premises to OTP processes** |
| 3 | **A metaprogrammed DSL: `defrule` and `defpremissa` with less PON boilerplate** |
| 4 | **Hexagonal architecture + PON: Ports & Adapters to decouple the engine** |
| 5 | **Smart Brewery: a digital twin brewery as a PON lab** |
| 6 | **Phoenix LiveView in real time: an operations UI on top of a rules engine** |
| 7 | **From simulation to storage: telemetry, Broadway/GenStage, and TimescaleDB** |
| 8 | **BI without mystery: dimensions, facts, and consuming the data (e.g. Power BI)** |
| 9 | **ML on the digital twin: export, train pilots, import predictions back into the app** |
| 10 | **When notifications explode: message storms, deduplication, and back-pressure in PON** |
| 11 | **Dev profiling: CPU, memory, and what changed after optimizations** |
| 12 | **Retrospective: lessons from building a reactive rules engine in Elixir** |

---

## Série enxuta (6 posts)

Fundir conteúdo conforme abaixo; renumerar como **Parte X de 6**. O post de BI (antigo 8) pode ser publicado como **bônus** ou omitido.

| Post enxuto | Cobre (antigos) | Título sugerido (PT) |
|------------:|-----------------|----------------------|
| 1 | 1 + 2 | **PON na BEAM: conceitos e mapeamento OTP (Fatos, Regras, Premissas)** |
| 2 | 3 + 4 | **DSL e hexagonal: menos boilerplate e motor desacoplado** |
| 3 | 5 + 6 | **Smart Brewery: gêmeo digital + LiveView operacional** |
| 4 | 7 + (8 opcional) | **Telemetria, TimescaleDB e caminho para o BI** |
| 5 | 9 | **ML no gêmeo digital: exportar, treinar, importar predições** |
| 6 | 10 + 11 + 12 | **Performance, message storm e retrospectiva do projeto** |

---

## Tags recomendadas no dev.to

Repetir em todos os posts da série (ajuste conforme o foco de cada um):

- `elixir`
- `phoenix`
- `liveview`
- `otp`
- `machinelearning`
- `timescaledb`

Opcionais, quando couber: `iot`, `industry40`, `architecture`, `functional`.

---

## Publicação

1. Cole o título da tabela principal (ou EN / enxuta) no campo **Title** do dev.to.
2. No corpo ou no excerpt, indique **Parte X de N** e um link para o post anterior/próximo (perfil: [dev.to/matheuscamarques](https://dev.to/matheuscamarques)).
3. No final da série, um post índice (opcional) com links para as 12 (ou 6) partes melhora descoberta.
4. Depois de publicar cada parte, substitua *a publicar* na coluna **Post no dev.to** da tabela principal por `[título ou “Parte N”](https://dev.to/matheuscamarques/slug-do-post)`.
5. Rascunhos em inglês (front matter) para colar no dev.to: coluna **Rascunho (repo)** na tabela principal (partes 1–12 já linkadas).
6. Parte 3 (EN): [docs/devto/en/03_metaprogrammed_dsl_defrule_defpremissa.md](devto/en/03_metaprogrammed_dsl_defrule_defpremissa.md) — `defrule`, `defpremissa`, `defcondicao`, instigations, `edge_triggered`.
7. Parte 4 (EN): [docs/devto/en/04_hexagonal_pon_ports_adapters.md](devto/en/04_hexagonal_pon_ports_adapters.md) — Behaviours como portas, `Adapters.*`, exemplo Prédio Inteligente, facade/config e stubs de teste.
8. Parte 5 (EN): [docs/devto/en/05_smart_brewery_digital_twin_pon_lab.md](devto/en/05_smart_brewery_digital_twin_pon_lab.md) — Gêmeo Smart Brewery (57 fatos, 12 regras), `simular/0`, `SmartBreweryMonteCarlo`, ponte LiveView/TSDB.
9. Parte 6 (EN): [docs/devto/en/06_phoenix_liveview_operations_ui_rules_engine.md](devto/en/06_phoenix_liveview_operations_ui_rules_engine.md) — `SmartBreweryLive`, `LiveViewEventBatcher`, PubSub por tópico, throttle de fatos, stream de log, regras/OEE/anomalias na UI; ponte para Broadway/TSDB (Parte 7).
10. Parte 7 (EN): [docs/devto/en/07_from_simulation_to_storage_telemetry_broadway_timescaledb.md](devto/en/07_from_simulation_to_storage_telemetry_broadway_timescaledb.md) — `TelemetryProducer` + Broadway `TelemetryPipeline`, `TelemetryAsyncWriter`, hypertable `telemetry_events`, writers OEE/anomalias/regras, CAGGs e retenção TimescaleDB; ponte para BI (Parte 8).
11. Parte 8 (EN): [docs/devto/en/08_bi_without_mystery_dimensions_facts_power_bi.md](devto/en/08_bi_without_mystery_dimensions_facts_power_bi.md) — star schema (`dim_equipamento_fbe`, `dim_variaveis_mapeamento`, `dim_calendario`, `dim_regras`), views `fact_telemetria_agregada_*`, `SmartBreweryBI`, role `powerbi_analytics`, `PowerBIPushSink` opcional, `mix verify.bi`; ponte para ML (Parte 9).
12. Parte 9 (EN): [docs/devto/en/09_ml_digital_twin_export_train_import_predictions.md](devto/en/09_ml_digital_twin_export_train_import_predictions.md) — `mix export.ml` / `MLDatasetExport`, `mix simulacoes_visuais.ml_train` (pilotos Scholar/Axon), `ml_predictions` + `mix import.ml.predictions`, `MlPredictionsLive`; guia PT em `docs/artigos/27_…`; ponte para message storm (Parte 10).
13. Parte 10 (EN): [docs/devto/en/10_when_notifications_explode_message_storms_pon.md](devto/en/10_when_notifications_explode_message_storms_pon.md) — dedup em `Fato`, `Fanout` / `atualizar_lote`, `drain_notificacoes` em `Regra`, ETS em `obter`, ligação com batchers Phoenix/Broadway; `docs/artigos/19_…`, `performance-dev.md`; ponte para profiling (Parte 11).
14. Parte 11 (EN): [docs/devto/en/11_dev_profiling_cpu_memory_optimizations.md](devto/en/11_dev_profiling_cpu_memory_optimizations.md) — `PipelineWorkload`, `mix profile.cprof` / `eprof` / `fprof` / `tprof`, `PROFILE_PIPELINE_*`, snapshots de memória, baselines light/heavy, `run_profile_60s.sh`; `performance-dev.md`, `memory-pressure-heuristics.md`; ponte para retrospectiva (Parte 12).
15. Parte 12 (EN): [docs/devto/en/12_retrospective_reactive_rules_engine_elixir.md](devto/en/12_retrospective_reactive_rules_engine_elixir.md) — fim da série: o que funcionou, trade-offs, hipóteses para próxima iteração, **tabela-índice** com links para as partes 1–12 no repositório; diagrama Mermaid do fluxo motor ↔ app.
16. Bibliografia (EN): [docs/devto/BIBLIOGRAPHY_PON_SERIES.md](devto/BIBLIOGRAPHY_PON_SERIES.md) — tabelas por tema (NOP, OTP, Phoenix, pipelines, BI, ML, filas); secção **This repository** com `performance-dev.md`, artigos PT, Partes 10–11 no dev.to; [post espelho no dev.to](https://dev.to/matheuscamarques/bibliography-pon-smart-brewery-devto-series-en-drafts-58a9).
