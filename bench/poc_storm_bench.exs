# Benchmarks (Benchee) para comparar dedup na fonte (`Fato`, `===`) vs coalescência no mailbox (`Regra`).
#
# Executar (a partir de apps/simulacoes_visuais):
#
#   mix bench.storm
#
# O alias usa `mix run --no-start` para não subir o Phoenix inteiro; só `:tec0301_pon` é iniciado no script.
#
# Opcional — incluir também `SmartBreweryMonteCarlo.run_tick_sync/0` (sobe `:simulacoes_visuais` no script):
#
#   BENCH_STORM_INCLUDE_MONTE_CARLO=1 mix run ../../bench/poc_storm_bench.exs
#
# (sem --no-start o Mix já arranca a app; prefira o comando acima com env.)
#
# Para contagens agregadas (noop vs dispatch, drained vs avaliacoes) no cenário completo, use:
#   mix run ../../scripts/poc_storm_measure.exs

defmodule PocStormBench.RegraNop do
  @moduledoc false
  def avaliar(_), do: false
  def executar(_), do: :ok
end

alias Tec0301Pon.PON.Fato
alias Tec0301Pon.PON.Regra

Application.ensure_all_started(:tec0301_pon)

uniq = System.unique_integer([:positive])

f_noop = :"poc_bench_noop_#{uniq}"
f_chg = :"poc_bench_chg_#{uniq}"
{:ok, _} = Fato.start_link(f_noop, 0)
{:ok, _} = Fato.start_link(f_chg, 0)

f_drain_on = :"poc_bench_drain_on_#{uniq}"
f_drain_off = :"poc_bench_drain_off_#{uniq}"
{:ok, _} = Fato.start_link(f_drain_on, 0)
{:ok, _} = Fato.start_link(f_drain_off, 0)

{:ok, pid_drain} = Regra.start_link([f_drain_on], PocStormBench.RegraNop, drain_mailbox: true)
{:ok, pid_no_drain} = Regra.start_link([f_drain_off], PocStormBench.RegraNop, drain_mailbox: false)

burst_n = 50

fato_noop = fn ->
  Enum.each(1..500, fn _ -> Fato.atualizar(f_noop, 0) end)
end

fato_dispatch = fn ->
  Enum.each(1..500, fn i -> Fato.atualizar(f_chg, i) end)
end

regra_burst_drain_on = fn ->
  for i <- 1..burst_n, do: send(pid_drain, {:notificacao, f_drain_on, i})
  Process.sleep(40)
end

regra_burst_drain_off = fn ->
  for i <- 1..burst_n, do: send(pid_no_drain, {:notificacao, f_drain_off, i})
  Process.sleep(40)
end

jobs = %{
  "fato_500x_noop_same_value" => fato_noop,
  "fato_500x_dispatch_changing" => fato_dispatch,
  "regra_#{burst_n}x_burst_drain_mailbox_true" => regra_burst_drain_on,
  "regra_#{burst_n}x_burst_drain_mailbox_false" => regra_burst_drain_off
}

jobs =
  if System.get_env("BENCH_STORM_INCLUDE_MONTE_CARLO") in ~w(1 true yes) do
    System.put_env("SIMULACOES_TSDB_ENABLED", "false")
    System.put_env("AUTO_START_MONTE_CARLO", "false")
    {:ok, _} = Application.ensure_all_started(:simulacoes_visuais)
    SimulacoesVisuais.SmartBreweryMonteCarlo.stop_loop()

    Map.put(jobs, "monte_carlo_run_tick_sync", fn ->
      :ok = SimulacoesVisuais.SmartBreweryMonteCarlo.run_tick_sync()
    end)
  else
    jobs
  end

IO.puts("")
IO.puts("=== Benchee: PON storm (dedup vs mailbox drain) ===")
IO.puts("Interpret: fato noop vs dispatch shows cost of skipping Registry.dispatch;")
IO.puts("regra drain true vs false shows coalescing vs one evaluation per message.")
IO.puts("")

Benchee.run(
  jobs,
  warmup: 1,
  time: 5,
  memory_time: 2,
  print: [comparison: true, unit_scaling: :best]
)

IO.puts("")
IO.puts("Tip: run `mix run ../../scripts/poc_storm_measure.exs` twice (TECO301_PON_REGRA_DRAIN_MAILBOX=true/false)")
IO.puts("     for JSON counters on the full Smart Brewery Monte Carlo pipeline.")
