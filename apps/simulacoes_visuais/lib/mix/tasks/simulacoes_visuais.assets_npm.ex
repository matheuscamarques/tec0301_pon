defmodule Mix.Tasks.SimulacoesVisuais.AssetsNpm do
  @moduledoc false
  use Mix.Task

  @shortdoc "Runs npm install in apps/simulacoes_visuais/assets"

  @impl Mix.Task
  def run(_args) do
    # lib/mix/tasks -> app root -> assets
    assets = Path.expand("../../../assets", __DIR__)

    unless File.exists?(Path.join(assets, "package.json")) do
      Mix.raise("package.json not found under #{assets}")
    end

    case System.cmd("npm", ["install"], cd: assets, stderr_to_stdout: true) do
      {out, 0} ->
        IO.puts(out)

      {out, code} ->
        Mix.raise("npm install failed (exit #{code}): #{out}")
    end
  end
end
