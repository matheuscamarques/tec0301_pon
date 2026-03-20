defmodule Mix.Tasks.SimulacoesVisuais.VerifyBiQueries do
  @shortdoc "Valida as consultas SQL do BI nativo (Smart Brewery) contra o Repo"
  @moduledoc """
  Executa `SimulacoesVisuais.SmartBreweryBI.run_query_diagnostics/0` e imprime OK/FAIL por consulta.

  Requer Postgres acessível (mesmo `config` que o app) e extensão TimescaleDB para `time_bucket`.

  Uso (raiz do monorepo ou `apps/simulacoes_visuais`):

      mix verify.bi

  Equivale a:

      mix simulacoes_visuais.verify_bi_queries
  """
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.config")
    {:ok, _} = Application.ensure_all_started(:simulacoes_visuais)

    if Application.get_env(:simulacoes_visuais, :tsdb_enabled, false) == false do
      Mix.shell().error(
        ":tsdb_enabled is false — o Repo pode não estar iniciado. Ative TSDB (ex.: dev default) e tente de novo."
      )
    end

    results = SimulacoesVisuais.SmartBreweryBI.run_query_diagnostics()

    {oks, fails} =
      Enum.split_with(results, fn
        {_, :ok, _} -> true
        _ -> false
      end)

    Enum.each(oks, fn {name, :ok, n} ->
      Mix.shell().info("OK  #{name} (#{n} row(s) in sample)")
    end)

    Enum.each(fails, fn {name, {:error, e}} ->
      Mix.shell().error("FAIL #{name}: #{Exception.message(e)}")
    end)

    summary = "#{length(oks)}/#{length(results)} consultas OK"

    if fails == [] do
      Mix.shell().info(summary <> " — amostras com LIMIT; 0 linhas ainda indica sucesso se não há dados.")
    else
      Mix.shell().error(summary)
      Mix.raise("BI: #{length(fails)} consulta(s) falharam (ver erros acima).")
    end

    :ok
  end
end
