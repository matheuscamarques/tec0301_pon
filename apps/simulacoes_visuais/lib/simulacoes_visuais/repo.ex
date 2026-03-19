defmodule SimulacoesVisuais.Repo do
  @moduledoc """
  Ecto Repo para persistência de telemetria (TimescaleDB / PostgreSQL).
  Artigo 07 §4.2. Só é iniciado quando config :simulacoes_visuais, :tsdb_enabled é true
  e a URL do banco está configurada.
  """
  use Ecto.Repo,
    otp_app: :simulacoes_visuais,
    adapter: Ecto.Adapters.Postgres
end
