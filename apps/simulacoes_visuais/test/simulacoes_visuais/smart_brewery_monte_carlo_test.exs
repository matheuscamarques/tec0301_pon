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

    _ = MonteCarlo.stop_loop()
    :ok
  end

  test "run_tick_sync applies one Monte Carlo tick and FBE_03 facts stay numeric" do
    # Regras podem zerar a bomba (R_09); não fixamos [20,80] para o pump.
    Fato.atualizar(:fbe_03_pump_speed, 45)
    assert :ok == MonteCarlo.run_tick_sync()
    Process.sleep(250)

    pump_speed = Fato.obter(:fbe_03_pump_speed)
    diff_pressure = Fato.obter(:fbe_03_diff_pressure)
    wort_clarity = Fato.obter(:fbe_03_wort_clarity)

    assert is_number(pump_speed)
    assert is_number(diff_pressure)
    assert is_number(wort_clarity)
    assert diff_pressure >= 40 and diff_pressure <= 200
    assert wort_clarity >= 5 and wort_clarity <= 80
  end
end
