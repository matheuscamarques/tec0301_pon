defmodule Mix.Tasks.SimulacoesVisuais.ExportMl do
  @shortdoc "Exporta CSVs do TSDB (telemetria, OEE, anomalias, regras, dimensões) para ML"
  @moduledoc """
  Gera arquivos CSV no diretório indicado para uso em pipelines de treino (Python, R, etc.).

  Uso (a partir de `apps/simulacoes_visuais`):

      mix simulacoes_visuais.export_ml --out /tmp/ml_export
      mix simulacoes_visuais.export_ml --out /tmp/ml_export --since-hours 72
      mix simulacoes_visuais.export_ml --out /tmp/ml_export --no-cagg
      mix simulacoes_visuais.export_ml --out /tmp/ml_export --no-cagg-1h-1day

  Requer `:tsdb_enabled` true e Postgres/TimescaleDB acessível. As CAGGs `telemetry_events_1min`,
  `telemetry_events_1h` e `telemetry_events_1day` devem existir (migrations), salvo com
  `--no-cagg` (apenas 1 min) ou `--no-cagg-1h-1day` (mantém 1 min, omite 1 h / 1 dia).

  Consultas SQL documentadas em `SimulacoesVisuais.MLDatasetExport`.
  """
  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    {opts, _} =
      OptionParser.parse!(argv,
        strict: [
          out: :string,
          since_hours: :integer,
          cagg: :boolean,
          cagg_1h_1day: :boolean
        ],
        aliases: [o: :out]
      )

    out = opts[:out]

    if is_nil(out) || out == "" do
      Mix.raise("missing --out DIR (ex.: --out /tmp/ml_export)")
    end

    since_hours = opts[:since_hours] || 168
    include_cagg = Keyword.get(opts, :cagg, true)
    include_cagg_1h_1day = Keyword.get(opts, :cagg_1h_1day, true)

    Mix.Task.run("app.config")

    if Application.get_env(:simulacoes_visuais, :tsdb_enabled, false) == false do
      Mix.raise(
        ":tsdb_enabled is false — enable TSDB in config (ex.: MIX_ENV=dev) or set :tsdb_enabled true"
      )
    end

    {:ok, _} = Application.ensure_all_started(:simulacoes_visuais)

    SimulacoesVisuais.MLDatasetExport.export_all(out,
      since_hours: since_hours,
      include_cagg_1min: include_cagg,
      include_cagg_1h_1day: include_cagg_1h_1day
    )

    Mix.shell().info("ML CSV export written to #{out}")
    :ok
  end
end
