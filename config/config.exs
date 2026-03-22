# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Default para `Tec0301Pon.PON.Regra` (POC: sobrescrever com Application.put_env antes do arranque).
config :tec0301_pon, regra_drain_mailbox: true

config :simulacoes_visuais,
  generators: [timestamp_type: :utc_datetime],
  # Smart Brewery Telemetry Batcher (artigo 07 §2.3). Opções passadas a start_link do SmartBreweryTelemetryBatcher.
  # - flush_interval_ms: janela de throttle em ms (100–250 recomendado). Default 250.
  # - max_buffer_size: flush imediato ao atingir este tamanho (backpressure). Default 100.
  telemetry_batcher: [flush_interval_ms: 250, max_buffer_size: 100],
  # TelemetryProducer: tamanho máximo da fila (default 5000). Excedente descartado (evita OOM).
  # telemetry_producer_max_queue: 5_000,
  # TelemetryPipeline (Broadway): batch_size (default 200) e batch_timeout_ms (default 300).
  # telemetry_pipeline_batch_size: 250,
  # telemetry_pipeline_batch_timeout_ms: 350,
  # Concorrência dos processadores/batchers (default 1 cada). Subir só após medir — artigo 20 §6.
  # telemetry_pipeline_processor_concurrency: 2,
  # telemetry_pipeline_batcher_concurrency: 2,
  # monte_carlo_facts_per_tick_min / monte_carlo_facts_per_tick_max (dev: env MONTE_CARLO_FACTS_PER_TICK_*)
  # TelemetryAsyncWriter: max lotes em fila (default 50). Excedente descarta o mais antigo.
  # telemetry_async_writer_max_queue: 50,
  # push_liveview_telemetry: false com SIMULACOES_HEADLESS (dev) — sem push ao LiveViewEventBatcher.
  # rule_event_writer_max_pending / rule_event_writer_batch_size — fila de regras antes do insert_all.
  # anomaly_event_writer_max_pending / anomaly_event_writer_batch_size — idem anomalias.
  # oee_snapshot_writer_max_pending — fila curta de snapshots OEE.
  # LiveViewEventBatcher: janela de eventos para a LiveView (reduz sobrecarga; 1 mensagem por janela).
  # - window_ms: janela em ms. Valores maiores = menos mensagens à LiveView (UI um pouco menos “ao vivo”).
  # - max_buffer_size: flush imediato ao atingir este tamanho.
  live_view_batcher: [window_ms: 200, max_buffer_size: 100],
  # Debounce na SmartBreweryLive após receber {:batch, _} antes de assign do mapa @fatos inteiro.
  smart_brewery_live_flush_pending_ms: 280,
  # Mínimo entre broadcasts PubSub `smart_brewery:oee` (e gravações em oee_snapshots quando TSDB ativo). 0 = sem throttle.
  # dev.exs usa default 1500 ms via OEE_PUBSUB_MIN_INTERVAL_MS.
  oee_pubsub_min_interval_ms: 1_500,
  # Retenção inicial da hypertable `telemetry_events` vem da migration (7 dias). Para estender no cluster:
  #   mix retention.tsdb --days N   (em apps/simulacoes_visuais, com :tsdb_enabled true)
  telemetry_retention_default_days: 7,
  # Painel BI (aba BI da SmartBreweryLive): reconsulta `SmartBreweryBI.dashboard_data/1` a cada N ms (só com TSDB ativo). 0 = desliga.
  bi_dashboard_refresh_ms: 10_000

# Configures the endpoint
config :simulacoes_visuais, SimulacoesVisuaisWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: SimulacoesVisuaisWeb.ErrorHTML, json: SimulacoesVisuaisWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SimulacoesVisuais.PubSub,
  live_view: [signing_salt: "ls7gtrrh"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :simulacoes_visuais, SimulacoesVisuais.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  simulacoes_visuais: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../apps/simulacoes_visuais/assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  simulacoes_visuais: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../apps/simulacoes_visuais", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# TimescaleDB (artigo 07 §4.2). Repo e TelemetryWriter iniciam quando :tsdb_enabled é true (dev.exs ou DATABASE_URL).
config :simulacoes_visuais, ecto_repos: [SimulacoesVisuais.Repo]

# Push opcional para Power BI REST (docs/power-bi-realtime.md). Ative via POWERBI_PUSH_* em runtime.exs.
config :simulacoes_visuais, :power_bi_push,
  enabled: false,
  group_id: nil,
  dataset_id: nil,
  table_name: "Telemetry",
  access_token: nil,
  min_interval_ms: 5_000,
  max_rows_per_push: 500,
  max_buffer_rows: 10_000,
  include_labels: true

# Log em arquivo para severidade >= level (default :error). Caminho: CRITICAL_LOG_FILE ou priv/log/critical.log.
# Desligar: enabled: false (ex.: test.exs) ou CRITICAL_LOG_FILE="".
config :simulacoes_visuais, :critical_log_file,
  enabled: true,
  level: :error,
  max_no_bytes: 10_485_760,
  max_no_files: 5,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
