# SimulacoesVisuais

Aplicação Phoenix do Gêmeo Digital Smart Brewery (simulação, telemetria, OEE, regras PON). O alinhamento ao **artigo 12** (Modelo de Atores, OTP, ISO 23247) está descrito na documentação interna do projeto (não versionada neste repositório).

## Início rápido

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* **Com TimescaleDB + Monte Carlo ligados por omissão** (persistência `telemetry_events` / regras / OEE, desde que o Postgres esteja acessível): `mix dev.tsdb` ou `iex -S mix dev.tsdb` (comando exato — evite typo `dev.tsdbdb`). O arranque lê `SIMULACOES_TSDB_ENABLED` e `AUTO_START_MONTE_CARLO` do ambiente no `Application.start/2`, para funcionar mesmo quando o IEx carrega a config antes do alias Mix.
* Caso contrário: `mix phx.server` / `iex -S mix phx.server` (em `MIX_ENV=dev`, `SIMULACOES_TSDB_ENABLED` já default `true` em `config/dev.exs`; o Monte Carlo continua a precisar de ser iniciado na UI ou `AUTO_START_MONTE_CARLO=true`)

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Simulação sem frontend (dados para treino ML)

A telemetria e o Monte Carlo **não dependem** do navegador. Para popular o TimescaleDB e depois exportar CSVs:

1. Na raiz do repositório: `docker compose up -d`
2. (Opcional) `mix ecto.migrate` nesta pasta
3. Subir a app com Monte Carlo automático:

```bash
SIMULACOES_TSDB_ENABLED=true AUTO_START_MONTE_CARLO=true mix phx.server
```

4. Exportar: `mix export.ml --out /tmp/ml_export --since-hours 168` — flags úteis: `--no-cagg`, `--no-cagg-1h-1day` (ver `mix help simulacoes_visuais.export_ml`).

**Atalho** na raiz do repositório: `./scripts/run_simulation_headless_ml.sh` (equivalente prático às variáveis acima).

**Variáveis úteis em dev:** `MONTE_CARLO_INTERVAL_MS=500` para mais pontos por unidade de tempo (mínimo ~200 ms; ver `config/dev.exs`); `LOGGER_LEVEL=warning` para menos ruído; para correr em background, algo como `nohup env SIMULACOES_TSDB_ENABLED=true AUTO_START_MONTE_CARLO=true mix phx.server > sim.log 2>&1 &` a partir desta pasta.

**Ficheiros típicos do export** (entre outros): `telemetry_events.csv` (bruto, inclui `value_str` / `value_int`), `telemetry_events_1min.csv`, `telemetry_events_1h.csv`, `telemetry_events_1day.csv`, `oee_snapshots.csv`, `anomaly_events.csv`, `rule_events.csv`, CSVs de dimensões (`dim_*`).

O script `mix run examples/smart_brewery_simulacao.exs` na raiz do monorepo **não** alimenta estes dados — só esta app com TSDB; ver também **Quem persiste no TSDB** abaixo.

## `mix verify.bi` vs. volume no TSDB

- **`mix verify.bi`** (nesta pasta) valida as SQL do BI com **janela fixa de 24h** no Postgres e **`LIMIT` pequeno** nas amostras — o output não reflete o volume total da hypertable; **0 linhas** numa linha do relatório só indica ausência de dados **nessa janela** (ou filtros como `value_float IS NOT NULL`), não falha de query.
- **`mix verify.tsdb`** reporta extensão TimescaleDB, `telemetry_events` (total + min/max `ts`), contagens **últimas 24h** (todas as linhas vs só `value_float IS NOT NULL`, alinhado ao BI), `rule_events` (24h + total), `oee_snapshots`, e se os processos `TelemetryAsyncWriter` / `OeeSnapshotWriter` / `RuleEventWriter` e o producer do Broadway estão registados. Se o último `ts` de telemetria for anterior a 24h, gráficos com `WHERE ts >= NOW() - 24h` ficam vazios mesmo havendo milhares de linhas antigas.
- **Checagem 24h + OEE** (com `SIMULACOES_TSDB_ENABLED=true`):

  ```bash
  mix run -e 'Application.ensure_all_started(:simulacoes_visuais); {:ok,r}=SimulacoesVisuais.Repo.query("SELECT COUNT(*)::bigint, MAX(ts) FROM telemetry_events WHERE ts >= NOW() - INTERVAL '\''24 hours'\'' AND value_float IS NOT NULL", []); IO.inspect(r.rows); {:ok,r2}=SimulacoesVisuais.Repo.query("SELECT COUNT(*)::bigint, MAX(ts) FROM oee_snapshots", []); IO.inspect(r2.rows)'
  ```

- **Quem persiste no TSDB:** só esta app com `:tsdb_enabled` (pipeline Broadway → `TelemetryAsyncWriter`, writers OEE/regras/anomalias). O script `mix run examples/smart_brewery_simulacao.exs` na raiz do monorepo sobe só `:tec0301_pon` e **não** grava em `telemetry_events` / `oee_snapshots`.
- **Regras a disparar mas telemetria parada:** (1) O producer GenStage (`TelemetryProducer`) precisa emitir no `handle_cast` quando já há `pending_demand` do Broadway; sem isso, eventos ficavam na fila sem drenar — `rule_events` crescia, `telemetry_events` e `oee_snapshots` não. (2) Se o `SmartBreweryFactBroadcaster` cair no fallback `SmartBreweryTelemetryBatcher`, o batcher publica `smart_brewery:fatos` mas historicamente podia não chamar `TelemetryAsyncWriter` (corrigido: `cast_batch` no flush). Reinicie o servidor após atualizar e confira `mix verify.tsdb`.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
