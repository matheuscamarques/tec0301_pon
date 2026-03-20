defmodule Mix.Tasks.SimulacoesVisuais.MlImportPredictions do
  @shortdoc "Importa predições ML (JSONL) para a tabela ml_predictions"
  @moduledoc """
  Cada linha do arquivo é um objeto JSON com pelo menos `"model_name"`.
  Opcional: `"ts"` (ISO8601), `"target_name"`, `"value_float"`, `"metadata"` (objeto).

      mix simulacoes_visuais.ml_import_predictions --file /path/to/preds.jsonl

  Requer `:tsdb_enabled` e migrations aplicadas.
  """
  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    {opts, _} = OptionParser.parse!(argv, strict: [file: :string], aliases: [f: :file])
    path = opts[:file]

    if is_nil(path) or path == "" do
      Mix.raise("missing --file PATH.jsonl")
    end

    unless File.exists?(path) do
      Mix.raise("file not found: #{path}")
    end

    Mix.Task.run("app.config")

    if Application.get_env(:simulacoes_visuais, :tsdb_enabled, false) == false do
      Mix.raise(":tsdb_enabled is false — enable TSDB in config")
    end

    {:ok, _} = Application.ensure_all_started(:simulacoes_visuais)

    maps =
      path
      |> File.stream!()
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&Jason.decode!/1)

    case SimulacoesVisuais.MlPredictions.insert_from_decoded_maps(maps) do
      {:ok, n} -> Mix.shell().info("Imported #{n} ml_prediction row(s).")
    end

    :ok
  end
end
