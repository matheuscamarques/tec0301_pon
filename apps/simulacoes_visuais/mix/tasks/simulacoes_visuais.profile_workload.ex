defmodule Mix.Tasks.SimulacoesVisuais.ProfileWorkload do
  @shortdoc "Executa N ticks do pipeline (sanity + snapshot de memória para cruzar com profile)"
  @moduledoc """
  Roda a mesma carga usada em `mix profile.*` (ver `docs/performance-dev.md`).

  Variáveis de ambiente:

  - `PROFILE_PIPELINE_TICKS` — número de ticks (default 30; ignorado se `PROFILE_PIPELINE_DURATION_MS` > 0)
  - `PROFILE_PIPELINE_DURATION_MS` — corre até passar este tempo (wall-clock), ex.: 600_000 = 10 min
  - `PROFILE_PIPELINE_MAX_TICKS` — tecto de segurança com duração (default 5_000_000)
  - `PROFILE_PIPELINE_MODE` — `via_genserver` ou `in_process`
  - `PROFILE_PIPELINE_MEMORY` — `1` para imprimir memória antes/depois

  Uso (a partir de `apps/simulacoes_visuais`):

      mix simulacoes_visuais.profile_workload
      PROFILE_PIPELINE_TICKS=50 PROFILE_PIPELINE_MEMORY=1 mix simulacoes_visuais.profile_workload
      PROFILE_PIPELINE_DURATION_MS=600000 mix simulacoes_visuais.profile_workload
  """
  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("app.config")
    {:ok, _} = Application.ensure_all_started(:simulacoes_visuais)
    SimulacoesVisuais.Profile.PipelineWorkload.run()
  end
end
