defmodule SimulacoesVisuais.SmartBreweryMonteCarloIntegrationTest do
  @moduledoc """
  Integration: one Monte Carlo tick updates FBE_03 facts (Nx path) and values stay in ranges.
  """
  use ExUnit.Case, async: false

  alias SimulacoesVisuais.SmartBreweryMonteCarlo, as: MonteCarlo
  alias Tec0301Pon.Examples.SmartBrewery, as: SmartBrewery
  alias Tec0301Pon.PON.Fato

  setup do
    # Registry is started by tec0301_pon (test_helper). Start malha so Fato processes exist.
    if Process.whereis(:fbe_01_motor_rpm) == nil do
      SmartBrewery.start_link()
    end

    # Start Monte Carlo only if not already running (e.g. app may have started it).
    case Process.whereis(SimulacoesVisuais.SmartBreweryMonteCarlo) do
      nil ->
        {:ok, pid} = MonteCarlo.start_link([])
        on_exit(fn -> Process.exit(pid, :normal) end)

      _ ->
        :ok
    end

    :ok
  end

  test "one tick updates FBE_03 pump_speed, diff_pressure, wort_clarity within ranges" do
    Process.send(Process.whereis(SimulacoesVisuais.SmartBreweryMonteCarlo), :tick, [])
    Process.sleep(150)

    pump_speed = Fato.obter(:fbe_03_pump_speed)
    diff_pressure = Fato.obter(:fbe_03_diff_pressure)
    wort_clarity = Fato.obter(:fbe_03_wort_clarity)

    assert is_number(pump_speed), "pump_speed should be a number"
    assert is_number(diff_pressure), "diff_pressure should be a number"
    assert is_number(wort_clarity), "wort_clarity should be a number"

    assert pump_speed >= 20 and pump_speed <= 80,
           "pump_speed #{pump_speed} outside [20, 80]"

    assert diff_pressure >= 40 and diff_pressure <= 200,
           "diff_pressure #{diff_pressure} outside [40, 200]"

    assert wort_clarity >= 5 and wort_clarity <= 80,
           "wort_clarity #{wort_clarity} outside [5, 80]"
  end
end
