defmodule Mix.Tasks.SimulacoesVisuais.VerifyTsdb do
  @shortdoc "Verifica TimescaleDB, Repo e volume de telemetria (Smart Brewery TSDB)"
  @moduledoc """
  Confirma que a extensão `timescaledb` está instalada, que a hypertable `telemetry_events`
  existe e reporta contagens úteis para diagnóstico (inclui janela 24h, `rule_events`,
  `oee_snapshots` e processos dos writers).

  Uso (a partir de `apps/simulacoes_visuais`):

      mix simulacoes_visuais.verify_tsdb
      mix verify.tsdb

  Requer Postgres/TimescaleDB acessível conforme `config/*.exs` e `:tsdb_enabled` true
  em dev (default em `config/dev.exs`), para o `Repo` subir com a aplicação.
  """
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.config")

    if Application.get_env(:simulacoes_visuais, :tsdb_enabled, false) == false do
      Mix.shell().info(
        ":tsdb_enabled is false — start with MIX_ENV=dev or enable TSDB in config. Skipping DB checks."
      )

      :ok
    else
      {:ok, _} = Application.ensure_all_started(:simulacoes_visuais)

      case SimulacoesVisuais.Repo.query(
             "SELECT extname FROM pg_extension WHERE extname = 'timescaledb'"
           ) do
        {:ok, %{rows: [["timescaledb"]]}} ->
          Mix.shell().info("OK: TimescaleDB extension present")

        {:ok, %{rows: []}} ->
          Mix.shell().error("FAIL: timescaledb extension not found")

        {:error, e} ->
          Mix.shell().error("FAIL: #{inspect(e)}")
      end

      case SimulacoesVisuais.Repo.query(
             "SELECT COUNT(*)::bigint, MIN(ts), MAX(ts) FROM telemetry_events",
             []
           ) do
        {:ok, %{rows: [[count, min_ts, max_ts]]}} ->
          Mix.shell().info(
            "telemetry_events: count=#{count}, min(ts)=#{inspect(min_ts)}, max(ts)=#{inspect(max_ts)}"
          )

        {:error, e} ->
          Mix.shell().error("telemetry_events query failed: #{inspect(e)}")
      end

      report_count = fn label, sql ->
        case SimulacoesVisuais.Repo.query(sql, []) do
          {:ok, %{rows: [[n]]}} ->
            Mix.shell().info("#{label}: #{n}")

          {:ok, %{rows: rows}} ->
            Mix.shell().info("#{label}: #{inspect(rows)}")

          {:error, e} ->
            Mix.shell().error("#{label} failed: #{inspect(e)}")
        end
      end

      report_count.(
        "telemetry_events last 24h (all rows)",
        "SELECT COUNT(*)::bigint FROM telemetry_events WHERE ts >= NOW() - INTERVAL '24 hours'"
      )

      report_count.(
        "telemetry_events last 24h (value_float NOT NULL, same filter as many BI queries)",
        "SELECT COUNT(*)::bigint FROM telemetry_events WHERE ts >= NOW() - INTERVAL '24 hours' AND value_float IS NOT NULL"
      )

      case SimulacoesVisuais.Repo.query(
             """
             SELECT COUNT(*)::bigint, MIN(ts), MAX(ts) FROM rule_events
             WHERE ts >= NOW() - INTERVAL '24 hours'
             """,
             []
           ) do
        {:ok, %{rows: [[c, min_ts, max_ts]]}} ->
          Mix.shell().info(
            "rule_events last 24h: count=#{c}, min(ts)=#{inspect(min_ts)}, max(ts)=#{inspect(max_ts)}"
          )

        {:error, e} ->
          Mix.shell().error("rule_events last 24h failed: #{inspect(e)}")
      end

      case SimulacoesVisuais.Repo.query(
             "SELECT COUNT(*)::bigint, MAX(ts) FROM rule_events",
             []
           ) do
        {:ok, %{rows: [[c, max_ts]]}} ->
          Mix.shell().info("rule_events total: count=#{c}, max(ts)=#{inspect(max_ts)}")

        {:error, e} ->
          Mix.shell().error("rule_events total failed: #{inspect(e)}")
      end

      case SimulacoesVisuais.Repo.query(
             "SELECT COUNT(*)::bigint, MAX(ts) FROM oee_snapshots",
             []
           ) do
        {:ok, %{rows: [[c, max_ts]]}} ->
          Mix.shell().info("oee_snapshots: count=#{c}, max(ts)=#{inspect(max_ts)}")

        {:error, e} ->
          Mix.shell().error("oee_snapshots failed: #{inspect(e)}")
      end

      for {name, mod} <- [
            {"TelemetryAsyncWriter", SimulacoesVisuais.SmartBrewery.TelemetryAsyncWriter},
            {"OeeSnapshotWriter", SimulacoesVisuais.SmartBrewery.OeeSnapshotWriter},
            {"RuleEventWriter", SimulacoesVisuais.SmartBrewery.RuleEventWriter}
          ] do
        pid = Process.whereis(mod)
        Mix.shell().info("writer process #{name}: #{inspect(pid)}")
      end

      producers =
        try do
          Broadway.producer_names(SimulacoesVisuais.SmartBrewery.TelemetryPipeline)
        rescue
          _ -> []
        end

      Mix.shell().info("TelemetryPipeline Broadway producers: #{inspect(producers)}")

      Mix.shell().info(
        "Tip: if rule_events grows but telemetry_events does not, see README (FactBroadcaster → Broadway vs TelemetryBatcher, TelemetryAsyncWriter). Start Monte Carlo on /smart-brewery for live fact traffic."
      )

      :ok
    end
  end
end
