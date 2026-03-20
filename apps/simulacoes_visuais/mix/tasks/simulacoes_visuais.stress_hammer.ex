defmodule Mix.Tasks.SimulacoesVisuais.StressHammer do
  @shortdoc "Dispara N ticks Monte Carlo em sequência tão rápida quanto o GenServer aguentar (stress de laboratório)"
  @moduledoc """
  Ignora o temporizador do loop (`send_after`): cada iteração é `SmartBreweryMonteCarlo.run_tick_sync/0`.
  Útil quando `MONTE_CARLO_INTERVAL_MS=200` ainda parece “leve” — aqui a cadência é só o tempo de um tick.

  Variáveis de ambiente:

  - `STRESS_HAMMER_TICKS` — número de ticks (default 5000)
  - `STRESS_HAMMER_PROGRESS_EVERY` — imprime progresso a cada N ticks (default 0 = silencioso)

  Uso (a partir de `apps/simulacoes_visuais`):

      mix simulacoes_visuais.stress_hammer
      STRESS_HAMMER_TICKS=20000 mix simulacoes_visuais.stress_hammer

  Requer a app compilada; sobe `:simulacoes_visuais` (malha PON + Broadway como no `mix phx.server` sem HTTP).
  Para stress contínuo com TSDB, prefira `MONTE_CARLO_INTERVAL_MS=1` no `mix phx.server` (ver `config/dev.exs` e `docs/performance-dev.md`).
  """
  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("app.config")
    {:ok, _} = Application.ensure_all_started(:simulacoes_visuais)

    ticks = env_int("STRESS_HAMMER_TICKS", 5000)
    every = env_int("STRESS_HAMMER_PROGRESS_EVERY", 0)

    t0 = System.monotonic_time(:millisecond)

    Enum.each(1..ticks, fn i ->
      :ok = SimulacoesVisuais.SmartBreweryMonteCarlo.run_tick_sync()

      if every > 0 and rem(i, every) == 0 do
        IO.puts("[stress_hammer] #{i}/#{ticks}")
      end
    end)

    dt = System.monotonic_time(:millisecond) - t0
    rate = if dt > 0, do: Float.round(ticks / dt * 1000, 2), else: 0.0
    IO.puts("[stress_hammer] done #{ticks} ticks in #{dt} ms (~#{rate} ticks/s)")
  end

  defp env_int(var, default) do
    case System.get_env(var) do
      nil -> default
      s -> case Integer.parse(String.trim(s)) do
        {n, _} when n > 0 -> n
        _ -> default
      end
    end
  end
end
