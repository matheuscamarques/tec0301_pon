import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :simulacoes_visuais, SimulacoesVisuaisWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "HkVJiDl//xTD++hofX4aC7ADVeVPFqH+YU375BBeRTSF/b3xiH3h1lbFRYRSD7Ua",
  server: false

# In test we don't send emails
config :simulacoes_visuais, SimulacoesVisuais.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# TSDB desligado em teste (evita depender de Postgres nos testes que não usam Repo).
config :simulacoes_visuais, :tsdb_enabled, false
# Evita timers de refresh do painel BI nos testes de LiveView.
config :simulacoes_visuais, :bi_dashboard_refresh_ms, 0

# Não escrever log crítico em arquivo durante os testes.
config :simulacoes_visuais, :critical_log_file, enabled: false

# Configure your database (usado apenas se algum teste usar Repo)
config :simulacoes_visuais, SimulacoesVisuais.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "simulacoes_visuais_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :simulacoes_visuais, SimulacoesVisuaisWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "l9DpMRlhuv9KZQ8bg1UWmTo54pgZGNznuDahfmK2MMzdVkBOEJh79Z5NnmwY+VII",
  server: false

# In test we don't send emails
config :simulacoes_visuais, SimulacoesVisuais.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
