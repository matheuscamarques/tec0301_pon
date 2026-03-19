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

config :simulacoes_visuais,
  generators: [timestamp_type: :utc_datetime],
  # Smart Brewery Telemetry Batcher (artigo 07 §2.3). Opções passadas a start_link do SmartBreweryTelemetryBatcher.
  # - flush_interval_ms: janela de throttle em ms (100–250 recomendado). Default 250.
  # - max_buffer_size: flush imediato ao atingir este tamanho (backpressure). Default 100.
  telemetry_batcher: [flush_interval_ms: 250, max_buffer_size: 100],
  # LiveViewEventBatcher: janela de eventos para a LiveView (reduz sobrecarga; 1 mensagem por janela).
  # - window_ms: janela em ms (80–150 recomendado). Default 120.
  # - max_buffer_size: flush imediato ao atingir este tamanho. Default 80.
  live_view_batcher: [window_ms: 120, max_buffer_size: 80],
  # Power BI: URL do relatório para embed na aba "Power BI" do Smart Brewery LiveView (opcional).
  # Ex.: "https://app.powerbi.com/..." (embed do Power BI Service ou Publish to web). Se nil, a aba exibe instruções.
  power_bi_report_url: nil

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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
