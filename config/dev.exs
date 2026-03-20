import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# For CPU/memory tuning, see docs/performance-dev.md (env vars below).

config :simulacoes_visuais, SimulacoesVisuaisWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "tcUoMck2HJwgn3Rs3/10ofPo+Irx1rBX1oLt9MC4j6DW3AzspK/ZAonbm0vVjj+U",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:simulacoes_visuais, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:simulacoes_visuais, ~w(--watch)]}
  ]

config :simulacoes_visuais, SimulacoesVisuaisWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/simulacoes_visuais_web/(?:controllers|live|components|router)/?.*\.(ex|heex)$"
    ]
  ]

config :simulacoes_visuais, dev_routes: true

config :logger, :default_formatter, format: "[$level] $message\n"

logger_level =
  case String.downcase(System.get_env("LOGGER_LEVEL", "info")) do
    "debug" -> :debug
    "info" -> :info
    "warn" -> :warning
    "warning" -> :warning
    "error" -> :error
    _ -> :warning
  end

config :logger, level: logger_level

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

# LiveView HEEx debug: very costly for CPU/memory. Enable only when debugging templates:
#   PHX_LV_DEBUG=1 mix phx.server
# Requires mix clean && recompile after changing.
phx_lv_debug? =
  System.get_env("PHX_LV_DEBUG", "") |> String.downcase() |> then(&(&1 in ~w(1 true yes)))

config :phoenix_live_view,
  debug_heex_annotations: phx_lv_debug?,
  debug_attributes: phx_lv_debug?,
  enable_expensive_runtime_checks: phx_lv_debug?

config :swoosh, :api_client, false

# TSDB: Repo, telemetria em `telemetry_events`, writers OEE/anomalias/regras. Desligar: SIMULACOES_TSDB_ENABLED=false
tsdb_enabled? =
  System.get_env("SIMULACOES_TSDB_ENABLED", "true")
  |> String.downcase()
  |> then(&(&1 not in ~w(0 false no off)))

config :simulacoes_visuais, :tsdb_enabled, tsdb_enabled?

# Mínimo 1 ms: com valores baixos o loop corre ao ritmo do `run_tick_pure/1` (sem pausa artificial).
# Para carga moderada use 200–1500; stress extremo: 1 (cuidado com CPU, TSDB e disco).
monte_carlo_ms =
  case Integer.parse(System.get_env("MONTE_CARLO_INTERVAL_MS", "1500")) do
    {n, _} when n >= 1 -> n
    _ -> 1500
  end

config :simulacoes_visuais, :monte_carlo_interval_ms, monte_carlo_ms

facts_tick_min =
  case Integer.parse(System.get_env("MONTE_CARLO_FACTS_PER_TICK_MIN", "1")) do
    {n, _} when n >= 1 -> n
    _ -> 1
  end

facts_tick_max =
  case Integer.parse(System.get_env("MONTE_CARLO_FACTS_PER_TICK_MAX", "4")) do
    {n, _} when n >= 1 -> n
    _ -> 4
  end

config :simulacoes_visuais, :monte_carlo_facts_per_tick_min, facts_tick_min
config :simulacoes_visuais, :monte_carlo_facts_per_tick_max, facts_tick_max

auto_mc? =
  System.get_env("AUTO_START_MONTE_CARLO", "false")
  |> String.downcase()
  |> then(&(&1 in ~w(1 true yes)))

config :simulacoes_visuais, :auto_start_monte_carlo, auto_mc?

# Memória: limite da fila do producer (evita OOM em carga alta). Env: TELEMETRY_PRODUCER_MAX_QUEUE
telemetry_producer_max_queue =
  case Integer.parse(System.get_env("TELEMETRY_PRODUCER_MAX_QUEUE", "5000")) do
    {n, _} when n >= 100 -> n
    _ -> 5_000
  end

config :simulacoes_visuais, :telemetry_producer_max_queue, telemetry_producer_max_queue

# OEE: intervalo entre broadcasts e gravações em oee_snapshots. Maior = menos I/O e memória.
oee_pubsub_ms =
  case Integer.parse(System.get_env("OEE_PUBSUB_MIN_INTERVAL_MS", "1500")) do
    {n, _} when n >= 0 -> n
    _ -> 1_500
  end

config :simulacoes_visuais, :oee_pubsub_min_interval_ms, oee_pubsub_ms

# BI: intervalo de atualização automática da aba BI (env BI_DASHBOARD_REFRESH_MS). 0 = só ao mudar filtro/aba.
bi_dashboard_refresh_ms =
  case Integer.parse(System.get_env("BI_DASHBOARD_REFRESH_MS", "10000")) do
    {n, _} when n >= 0 -> n
    _ -> 10_000
  end

config :simulacoes_visuais, :bi_dashboard_refresh_ms, bi_dashboard_refresh_ms

# Pipeline: batch maior e timeout maior = menos batches/segundo (menos overhead).
telemetry_batch_size =
  case Integer.parse(System.get_env("TELEMETRY_PIPELINE_BATCH_SIZE", "250")) do
    {n, _} when n >= 50 -> n
    _ -> 250
  end

telemetry_batch_timeout =
  case Integer.parse(System.get_env("TELEMETRY_PIPELINE_BATCH_TIMEOUT_MS", "350")) do
    {n, _} when n >= 100 -> n
    _ -> 350
  end

config :simulacoes_visuais, :telemetry_pipeline_batch_size, telemetry_batch_size
config :simulacoes_visuais, :telemetry_pipeline_batch_timeout_ms, telemetry_batch_timeout

# Async writer: fila menor = descarta mais cedo se DB lento.
telemetry_async_queue =
  case Integer.parse(System.get_env("TELEMETRY_ASYNC_WRITER_MAX_QUEUE", "50")) do
    {n, _} when n >= 5 -> n
    _ -> 50
  end

config :simulacoes_visuais, :telemetry_async_writer_max_queue, telemetry_async_queue

# Headless: não envia fatos ao LiveViewEventBatcher (poupa ~57 casts/tick sem browser). Env: SIMULACOES_HEADLESS
simulacoes_headless? =
  System.get_env("SIMULACOES_HEADLESS", "")
  |> String.downcase()
  |> then(&(&1 in ~w(1 true yes)))

config :simulacoes_visuais, :push_liveview_telemetry, not simulacoes_headless?

# Optional overrides (see docs/performance-dev.md). Para reduzir memória em simulação pesada:
# config :simulacoes_visuais, :telemetry_producer_max_queue, 2_000
# config :simulacoes_visuais, :telemetry_pipeline_batch_size, 300
# config :simulacoes_visuais, :telemetry_pipeline_batch_timeout_ms, 250

config :simulacoes_visuais, SimulacoesVisuais.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: System.get_env("POSTGRES_DB", "simulacoes_visuais_dev"),
  port: String.to_integer(System.get_env("POSTGRES_PORT", "5432")),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  # SELECT/INSERT/UPDATE etc. em :info (visíveis com LOGGER_LEVEL default info; use log: false para silenciar)
  log: :info
