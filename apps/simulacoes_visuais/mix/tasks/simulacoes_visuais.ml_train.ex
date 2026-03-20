defmodule Mix.Tasks.SimulacoesVisuais.MlTrain do
  @shortdoc "Executa pilotos ML em Elixir (Scholar/Axon) sobre CSV exportado"
  @moduledoc """
  Requer diretório com CSVs de `mix export.ml`.

      mix simulacoes_visuais.ml_train --dir /tmp/ml_export --pilot oee
      mix simulacoes_visuais.ml_train --dir /tmp/ml_export --pilot fermentation
      mix simulacoes_visuais.ml_train --dir /tmp/ml_export --pilot anomaly

  Pilotos: `oee` (Scholar regressão linear), `fermentation` (Axon MLP), `anomaly` (Axon autoencoder FBE_01).
  """
  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    {opts, _} =
      OptionParser.parse!(argv,
        strict: [dir: :string, pilot: :string, epochs: :integer],
        aliases: [d: :dir, p: :pilot]
      )

    dir = opts[:dir]
    pilot = opts[:pilot] || "oee"
    epochs = opts[:epochs] || 40

    if is_nil(dir) or dir == "" do
      Mix.raise("missing --dir EXPORT_DIR")
    end

    Mix.Task.run("app.config")
    {:ok, _} = Application.ensure_all_started(:simulacoes_visuais)

    result =
      case pilot do
        "oee" -> SimulacoesVisuais.ML.Pilots.OeeLinear.run(dir)
        "fermentation" -> SimulacoesVisuais.ML.Pilots.FermentationMlp.run(dir, epochs: epochs)
        "anomaly" -> SimulacoesVisuais.ML.Pilots.AnomalyAutoencoder.run(dir, epochs: epochs)
        other -> {:error, {:unknown_pilot, other}}
      end

    case result do
      {:ok, metrics} ->
        Mix.shell().info(inspect(metrics, pretty: true))

      {:error, reason} ->
        Mix.raise("ML pilot failed: #{inspect(reason)}")
    end
  end
end
