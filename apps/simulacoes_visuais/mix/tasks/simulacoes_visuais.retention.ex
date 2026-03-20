defmodule Mix.Tasks.SimulacoesVisuais.Retention do
  @shortdoc "Redefine a retenção TimescaleDB de telemetry_events (remove + add policy)"
  @moduledoc """
  Remove a política de retenção atual da hypertable `telemetry_events` e cria outra com o
  intervalo indicado. Útil para manter histórico mais longo antes de exportar dados para ML.

  Uso (a partir de `apps/simulacoes_visuais`, com TSDB habilitado):

      mix simulacoes_visuais.retention --days 30

  Requer permissões DDL no banco. A migration inicial define 7 dias; este comando não altera
  migrations, apenas o estado do cluster TimescaleDB.
  """
  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    {opts, _} = OptionParser.parse!(argv, strict: [days: :integer])

    days = opts[:days]

    if is_nil(days) or days < 1 do
      Mix.raise("missing or invalid --days N (positive integer)")
    end

    Mix.Task.run("app.config")

    if Application.get_env(:simulacoes_visuais, :tsdb_enabled, false) == false do
      Mix.raise(
        ":tsdb_enabled is false — enable TSDB in config (ex.: MIX_ENV=dev) before running this task"
      )
    end

    {:ok, _} = Application.ensure_all_started(:simulacoes_visuais)

    repo = SimulacoesVisuais.Repo

    case repo.query("SELECT remove_retention_policy('telemetry_events')", []) do
      {:ok, _} ->
        Mix.shell().info("Removed existing retention policy on telemetry_events (if any).")

      {:error, %Postgrex.Error{} = e} ->
        Mix.shell().info(
          "remove_retention_policy note: #{Exception.message(e)} (continuing if no policy existed)"
        )
    end

    sql = "SELECT add_retention_policy('telemetry_events', INTERVAL '#{days} days')"

    case repo.query(sql, []) do
      {:ok, _} ->
        Mix.shell().info("OK: retention policy set to #{days} day(s) on telemetry_events")

      {:error, e} ->
        Mix.raise("add_retention_policy failed: #{inspect(e)}")
    end

    :ok
  end
end
