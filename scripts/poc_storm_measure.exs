# POC: medir dedup na fonte (Fato `===`) vs coalescência no mailbox (Regra `drain_notificacoes`).
#
# Executar a partir da app Phoenix (depende de `SimulacoesVisuais.Profile.PipelineWorkload`):
#
#   cd apps/simulacoes_visuais
#   mix run ../../scripts/poc_storm_measure.exs
#
# Variáveis úteis:
#   TECO301_PON_REGRA_DRAIN_MAILBOX — true|false (default true). Deve ser definida antes do arranque
#     das regras; cada invocação usa um VM novo (`mix run`), o que garante ordem correta.
#   PROFILE_PIPELINE_TICKS — ticks Monte Carlo (default 120).
#   SIMULACOES_TSDB_ENABLED — default false neste script (menos ruído).
#
# Saída: uma linha JSON com contagens agregadas (útil para append a um CSV).

drain? =
  case System.get_env("TECO301_PON_REGRA_DRAIN_MAILBOX", "true") |> String.downcase() do
    v when v in ~w(1 true yes) -> true
    _ -> false
  end

Application.put_env(:tec0301_pon, :regra_drain_mailbox, drain?)

# Medição mais limpa sem Postgres/Broadway writers (sobrescreve env do shell para esta execução).
System.put_env("SIMULACOES_TSDB_ENABLED", "false")
System.put_env("AUTO_START_MONTE_CARLO", "false")

{:ok, _} = Application.ensure_all_started(:simulacoes_visuais)

Tec0301Pon.PON.StormPoc.reset_smart_brewery_counters()

ticks =
  case System.get_env("PROFILE_PIPELINE_TICKS") do
    nil -> 120
    s -> String.to_integer(s)
  end

t0 = System.monotonic_time(:millisecond)

SimulacoesVisuais.Profile.PipelineWorkload.run(ticks: ticks, memory: false)

Process.sleep(150)

t1 = System.monotonic_time(:millisecond)

fatos = Tec0301Pon.PON.StormPoc.aggregate_fatos_smart_brewery()
regras = Tec0301Pon.PON.StormPoc.aggregate_regras_smart_brewery()

report = %{
  scenario: "monte_carlo_pipeline",
  regra_drain_mailbox: drain?,
  profile_pipeline_ticks: ticks,
  wall_clock_ms: t1 - t0,
  fatos: fatos,
  regras: regras
}

IO.puts(Jason.encode!(report))

# --- Draft reply (EN) for blog comments — fill in numbers from multiple runs ---
# We instrument the fact layer (`===` skips Registry.dispatch when the value is unchanged) and the
# rule GenServer (mailbox drain coalesces bursts before a single evaluation). This script prints JSON
# so you can compare `fatos.noop_updates` vs `fatos.dispatches` and `regras.drained_messages` vs
# `regras.avaliacoes` under `TECO301_PON_REGRA_DRAIN_MAILBOX=true` vs `false`. Monte Carlo noise may
# yield few no-ops; repeat with a synthetic burst of identical updates if you need to stress the first
# `===`. Which “dominates” depends on whether you count suppressed inter-process messages (facts) or
# collapsed mailbox deliveries (rules)—report both.
