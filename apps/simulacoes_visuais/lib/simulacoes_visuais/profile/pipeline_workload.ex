defmodule SimulacoesVisuais.Profile.PipelineWorkload do
  @moduledoc """
  Carga reproduzível para `mix profile.cprof` / `eprof` / `fprof` e sanity checks.

  Documentação: `docs/performance-dev.md` (raiz do monorepo).
  """

  alias SimulacoesVisuais.SmartBreweryMonteCarlo, as: MonteCarlo

  @registered_for_memory [
    SimulacoesVisuais.SmartBreweryMonteCarlo,
    SimulacoesVisuais.SmartBrewery.TelemetryPipeline,
    SimulacoesVisuais.SmartBrewery.TelemetryAsyncWriter,
    SimulacoesVisuais.SmartBrewery.RuleEventWriter,
    SimulacoesVisuais.SmartBrewery.OeeSnapshotWriter,
    SimulacoesVisuais.SmartBrewery.AnomalyEventWriter
  ]

  @doc """
  Executa N ticks do Monte Carlo (pipeline + fatos + telemetria).

  Opções:
  - `:ticks` — default `PROFILE_PIPELINE_TICKS` ou 30 (ignorado se `:duration_ms` ou env `PROFILE_PIPELINE_DURATION_MS` estiver definido)
  - `:duration_ms` — duração mínima em ms (wall-clock); repete ticks até passar esse tempo (ver `PROFILE_PIPELINE_MAX_TICKS`)
  - `:mode` — `:via_genserver` (default) ou `:in_process` (recomendado para `mix profile.fprof`)
  - `:memory` — se true, imprime `:erlang.memory/0` e processos chave antes/depois

  Modo `:in_process` corre `MonteCarlo.run_tick_pure/1` no processo atual (melhor para fprof).
  O estado interno do GenServer (`fbe03_prng`, etc.) **não** é atualizado nesse modo — só use para profiling.
  """
  def run(opts \\ []) when is_list(opts) do
    duration_ms = Keyword.get(opts, :duration_ms) || env_duration_ms()
    ticks = Keyword.get(opts, :ticks, env_int("PROFILE_PIPELINE_TICKS", 30))
    max_ticks = Keyword.get(opts, :max_ticks, env_int("PROFILE_PIPELINE_MAX_TICKS", 5_000_000))
    mode = Keyword.get(opts, :mode, mode_from_env())
    memory? = Keyword.get(opts, :memory, env_bool("PROFILE_PIPELINE_MEMORY", false))

    {:ok, _} = Application.ensure_all_started(:simulacoes_visuais)
    MonteCarlo.stop_loop()

    if memory?, do: print_memory_section("before")

    case duration_ms do
      ms when is_integer(ms) and ms > 0 ->
        deadline = System.monotonic_time(:millisecond) + ms

        IO.puts(
          "[PipelineWorkload] duration=#{ms}ms max_ticks=#{max_ticks} mode=#{mode} (until monotonic deadline)"
        )

        case mode do
          :in_process ->
            state = MonteCarlo.capture_tick_state()
            run_until_deadline_in_process(state, deadline, max_ticks, 0)

          :via_genserver ->
            run_until_deadline_genserver(deadline, max_ticks, 0)
        end

      _ ->
        IO.puts("[PipelineWorkload] ticks=#{ticks} mode=#{mode}")

        case mode do
          :in_process ->
            state = MonteCarlo.capture_tick_state()

            Enum.reduce(1..ticks, state, fn _, st ->
              MonteCarlo.run_tick_pure(st)
            end)

          :via_genserver ->
            Enum.each(1..ticks, fn _ ->
              :ok = MonteCarlo.run_tick_sync()
            end)
        end
    end

    if memory?, do: print_memory_section("after")
    :ok
  end

  defp run_until_deadline_in_process(state, deadline, max_ticks, count) do
    cond do
      count >= max_ticks ->
        IO.puts("[PipelineWorkload] stopped: max_ticks=#{max_ticks} reached")
        state

      System.monotonic_time(:millisecond) >= deadline ->
        IO.puts("[PipelineWorkload] done: #{count} ticks (duration window elapsed)")
        state

      true ->
        state
        |> MonteCarlo.run_tick_pure()
        |> run_until_deadline_in_process(deadline, max_ticks, count + 1)
    end
  end

  defp run_until_deadline_genserver(deadline, max_ticks, count) do
    cond do
      count >= max_ticks ->
        IO.puts("[PipelineWorkload] stopped: max_ticks=#{max_ticks} reached")

      System.monotonic_time(:millisecond) >= deadline ->
        IO.puts("[PipelineWorkload] done: #{count} ticks (duration window elapsed)")

      true ->
        :ok = MonteCarlo.run_tick_sync()
        run_until_deadline_genserver(deadline, max_ticks, count + 1)
    end
  end

  @doc """
  Apenas snapshot de memória (útil antes/depois de um perfil manual ou `remsh`).
  """
  def print_memory_section(label) when is_binary(label) do
    IO.puts("")
    IO.puts("--- Memory snapshot: #{label} ---")
    print_erlang_memory()
    print_registered_processes()
    IO.puts("--- end #{label} ---")
    IO.puts("")
  end

  defp print_erlang_memory do
    :erlang.memory()
    |> Enum.sort_by(fn {_, v} -> -v end)
    |> Enum.each(fn {k, v} ->
      IO.puts("  #{inspect(k)}: #{div(v, 1024)} KB")
    end)
  end

  defp print_registered_processes do
    Enum.each(@registered_for_memory, fn name ->
      case Process.whereis(name) do
        nil ->
          IO.puts("  #{inspect(name)}: not running")

        pid ->
          info = Process.info(pid, [:memory, :message_queue_len])

          if info do
            m = Keyword.fetch!(info, :memory)
            q = Keyword.fetch!(info, :message_queue_len)
            IO.puts("  #{inspect(name)}: heap ~#{div(m, 1024)} KB, mailbox #{q}")
          end
      end
    end)
  end

  defp mode_from_env do
    case System.get_env("PROFILE_PIPELINE_MODE", "via_genserver") do
      "in_process" -> :in_process
      _ -> :via_genserver
    end
  end

  defp env_int(var, default) do
    case System.get_env(var) do
      nil ->
        default

      s ->
        case Integer.parse(String.trim(s)) do
          {n, _} when n > 0 -> n
          _ -> default
        end
    end
  end

  defp env_duration_ms do
    case System.get_env("PROFILE_PIPELINE_DURATION_MS") do
      nil ->
        nil

      s ->
        case Integer.parse(String.trim(s)) do
          {n, _} when n > 0 -> n
          _ -> nil
        end
    end
  end

  defp env_bool(var, default) do
    case System.get_env(var) do
      nil -> default
      v -> v in ["1", "true", "yes", "TRUE"]
    end
  end
end
