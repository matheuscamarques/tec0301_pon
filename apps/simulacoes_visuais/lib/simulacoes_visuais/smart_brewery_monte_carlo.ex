defmodule SimulacoesVisuais.SmartBreweryMonteCarlo do
  @moduledoc """
  Orquestrador do Gêmeo Digital Híbrido: a cada tick chama FBE03Darcy, FBE06Fermentation,
  FBE07Fermentation, FBE08Markov, FBE10Markov e FBE11SmartGrid; para os demais fatos usa Monte Carlo (faixas/enum/bool).
  """

  use GenServer

  alias SimulacoesVisuais.SmartBrewery.FBE03Darcy
  alias SimulacoesVisuais.SmartBrewery.FBE06Fermentation
  alias SimulacoesVisuais.SmartBrewery.FBE07Fermentation
  alias SimulacoesVisuais.SmartBrewery.FBE08Markov
  alias SimulacoesVisuais.SmartBrewery.FBE10Markov
  alias SimulacoesVisuais.SmartBrewery.FBE11SmartGrid
  alias SimulacoesVisuais.SmartBrewery.Noise
  alias SimulacoesVisuais.SmartBrewery.NxSim
  alias Tec0301Pon.Examples.SmartBrewery
  alias Tec0301Pon.PON.Fato

  require Logger

  @default_interval_ms 1_500
  @facts_per_tick_min 1
  @facts_per_tick_max 4

  # Variáveis contínuas "lentas" com random walk (Box-Muller) em vez de uniforme (artigo §3.1)
  @random_walk_facts [
    :fbe_01_motor_temp,
    :fbe_02_mash_temp,
    :fbe_04_boil_temp,
    :fbe_05_wort_in_temp,
    :fbe_05_wort_out_temp,
    :fbe_09_flow_velocity
  ]

  # Fatos atualizados pelos modelos dedicados (não sortear no Monte Carlo)
  @excluded_from_mc [
    :fbe_03_diff_pressure,
    :fbe_03_wort_clarity,
    :fbe_03_sparge_water_temp,
    :fbe_03_rake_height,
    :fbe_03_pump_speed,
    :fbe_06_internal_temp,
    :fbe_06_pressure,
    :fbe_06_gravity_brix,
    :fbe_06_glycol_jacket_st,
    :fbe_06_co2_exhaust_flow,
    :fbe_06_ferm_phase,
    :fbe_06_ph,
    :fbe_07_internal_temp,
    :fbe_07_pressure,
    :fbe_07_gravity_brix,
    :fbe_07_glycol_jacket_st,
    :fbe_07_co2_exhaust_flow,
    :fbe_07_ferm_phase,
    :fbe_08_capper_jam_sens,
    :fbe_08_conveyor_speed,
    :fbe_08_fill_head_status,
    :fbe_08_liquid_lvl_detect,
    :fbe_08_stop_sensor,
    :fbe_09_cip_pump_state,
    :fbe_10_collision_alert,
    :fbe_10_robot_1_status,
    :fbe_10_robot_1_battery,
    :fbe_11_grid_power_cost,
    :fbe_11_v2g_battery_lvl
  ]

  # Schema: nome_do_fato => {:range, min, max} | {:enum, [valores]} | :bool
  # Fatos com tupla (ex.: robot_1_location) são omitidos.
  @schema %{
    # FBE_01
    fbe_01_motor_rpm: {:range, 0, 3000},
    fbe_01_vibration_level: {:range, 0, 100},
    fbe_01_hopper_level: {:range, 0, 100},
    fbe_01_motor_temp: {:range, 20, 80},
    fbe_01_feed_valve_state: {:enum, [:open, :closed]},
    # FBE_02
    fbe_02_mash_temp: {:range, 60, 75},
    fbe_02_water_flow_rate: {:range, 0, 100},
    fbe_02_agitator_status: {:enum, [:on, :off]},
    fbe_02_ph_level: {:range, 45, 62},
    fbe_02_viscosity: {:range, 0, 50},
    fbe_02_liquid_level: {:range, 0, 100},
    # FBE_03 — R_01
    fbe_03_diff_pressure: {:range, 40, 200},
    fbe_03_wort_clarity: {:range, 5, 80},
    fbe_03_sparge_water_temp: {:range, 70, 80},
    fbe_03_rake_height: {:range, 30, 70},
    fbe_03_pump_speed: {:range, 20, 80},
    # FBE_04
    fbe_04_boil_temp: {:range, 0, 105},
    fbe_04_steam_pressure: {:range, 0, 5},
    fbe_04_evaporation_rate: {:range, 0, 20},
    fbe_04_hop_doser_state: {:enum, [:idle, :dosing]},
    fbe_04_foam_level: {:range, 0, 100},
    # FBE_05
    fbe_05_wort_in_temp: {:range, 0, 100},
    fbe_05_wort_out_temp: {:range, 0, 25},
    fbe_05_glycol_valve_pos: {:range, 0, 100},
    fbe_05_water_pressure: {:range, 0, 10},
    # FBE_06 — R_03
    fbe_06_internal_temp: {:range, 15, 23},
    fbe_06_pressure: {:range, 0, 2},
    fbe_06_gravity_brix: {:range, 0, 25},
    fbe_06_glycol_jacket_st: {:enum, [:on, :off]},
    fbe_06_co2_exhaust_flow: {:range, 0, 50},
    fbe_06_ferm_phase: {:enum, [:lag, :growth, :stationary, :flocculation]},
    fbe_06_ph: {:range, 42, 52},
    # FBE_07
    fbe_07_internal_temp: {:range, 15, 23},
    fbe_07_pressure: {:range, 0, 2},
    fbe_07_gravity_brix: {:range, 0, 25},
    fbe_07_glycol_jacket_st: {:enum, [:on, :off]},
    fbe_07_co2_exhaust_flow: {:range, 0, 50},
    fbe_07_ferm_phase: {:enum, [:lag, :growth, :stationary, :flocculation]},
    # FBE_08 — R_02
    fbe_08_ir_bottle_detect: :bool,
    fbe_08_conveyor_speed: {:range, 0, 100},
    fbe_08_fill_head_status: {:enum, [:idle, :filling]},
    fbe_08_liquid_lvl_detect: {:enum, [:ok, :fail]},
    fbe_08_capper_jam_sens: :bool,
    fbe_08_stop_sensor: :bool,
    # FBE_09 — R_03
    fbe_09_caustic_tank_lvl: {:range, 0, 100},
    fbe_09_acid_tank_lvl: {:range, 0, 100},
    fbe_09_return_conduct: {:range, 0, 100},
    fbe_09_cip_pump_state: {:enum, [:on, :off]},
    fbe_09_flow_velocity: {:range, 0, 10},
    # FBE_10 — R_02 (robot_1_location omitido)
    fbe_10_robot_1_battery: {:range, 0, 100},
    fbe_10_robot_1_status: {:enum, [:ocioso, :em_transito, :carregando, :falha]},
    fbe_10_collision_alert: :bool,
    fbe_10_payload_weight: {:range, 0, 500},
    # FBE_11 — R_03
    fbe_11_grid_power_cost: {:range, 80, 250},
    fbe_11_v2g_battery_lvl: {:range, 0, 100},
    fbe_11_main_load_draw: {:range, 0, 500},
    fbe_11_grid_fault_detec: :bool
  }

  def start_link(opts \\ []) do
    interval = Keyword.get(opts, :interval_ms, @default_interval_ms)
    GenServer.start_link(__MODULE__, %{interval_ms: interval}, name: __MODULE__)
  end

  @doc "Inicia o loop Monte Carlo."
  def start_loop do
    GenServer.cast(__MODULE__, :start_loop)
  end

  @doc "Para o loop Monte Carlo."
  def stop_loop do
    GenServer.cast(__MODULE__, :stop_loop)
  end

  @impl true
  def init(init_state) do
    seed = :erlang.phash2(:os.system_time(:millisecond))
    nx_key = Nx.Random.key(seed)

    state =
      init_state
      |> Map.put_new(:running, false)
      |> Map.put(:nx_key, nx_key)

    {:ok, state}
  end

  @impl true
  def handle_cast(:start_loop, %{running: true} = state), do: {:noreply, state}

  @impl true
  def handle_cast(:start_loop, state) do
    if Process.whereis(:fbe_01_motor_rpm) == nil do
      Logger.warning(
        "[SmartBreweryMonteCarlo] Malha PON ainda não iniciada (Fato não encontrado). Aguarde o Bridge ou rode uma simulação primeiro."
      )
    end

    interval = state.interval_ms
    # Primeiro tick logo para feedback imediato; depois a cada interval_ms
    Process.send_after(self(), :tick, 100)
    Logger.info("[SmartBreweryMonteCarlo] Loop iniciado (tick a cada #{interval} ms).")
    {:noreply, %{state | running: true}}
  end

  @impl true
  def handle_cast(:stop_loop, state) do
    {:noreply, %{state | running: false}}
  end

  @impl true
  def handle_info(:tick, %{running: false} = state), do: {:noreply, state}

  @impl true
  def handle_info(:tick, state) do
    new_state = tick(state)
    interval = state.interval_ms
    Process.send_after(self(), :tick, interval)
    {:noreply, new_state}
  end

  # Matriz de correlação FBE_03: pump_speed(0), diff_pressure(1), wort_clarity(2). Artigo §3.2.
  @fbe03_correlation [
    [1.0, 0.8, -0.5],
    [0.8, 1.0, -0.7],
    [-0.5, -0.7, 1.0]
  ]

  defp tick(state) do
    # Modelos físicos e estocásticos dedicados
    FBE03Darcy.tick()
    FBE06Fermentation.tick()
    FBE07Fermentation.tick()
    FBE08Markov.tick()
    FBE10Markov.tick()
    FBE11SmartGrid.tick()
    # Variáveis correlacionadas FBE_03 via Nx (Cholesky + normais, artigo §3.2 e §4.1)
    state = update_fbe03_cholesky(state)

    # Monte Carlo apenas para fatos não cobertos pelos modelos
    all_names = SmartBrewery.fatos_names()
    with_schema = Enum.filter(all_names, &Map.has_key?(@schema, &1))
    excluded = MapSet.new(@excluded_from_mc)
    mc_candidates = Enum.reject(with_schema, &MapSet.member?(excluded, &1))
    count = min(Enum.random(@facts_per_tick_min..@facts_per_tick_max), length(mc_candidates))
    chosen = Enum.take_random(mc_candidates, count)

    for nome <- chosen do
      valor = next_value(nome)

      if valor != nil do
        try do
          Fato.atualizar(nome, valor)
          Logger.debug("[SmartBreweryMonteCarlo] #{nome} = #{inspect(valor)}")
        rescue
          e ->
            Logger.warning("[SmartBreweryMonteCarlo] Falha ao atualizar #{nome}: #{inspect(e)}")
        end
      end
    end

    state
  end

  defp next_value(nome) do
    schema = Map.get(@schema, nome)

    if nome in @random_walk_facts and match?({:range, _, _}, schema) do
      random_walk_value(nome, schema)
    else
      random_value(schema)
    end
  end

  defp random_walk_value(nome, {:range, min, max}) do
    prev =
      try do
        Fato.obter(nome)
      rescue
        _ -> (min + max) / 2
      end

    prev_num = if is_number(prev), do: prev * 1.0, else: (min + max) / 2
    sigma = (max - min) * 0.02
    step = Noise.normal(0, sigma)
    new_val = prev_num + step
    clamped = max(min, min(max, new_val))
    round(clamped * 100) / 100
  end

  defp random_value({:range, min, max}), do: Enum.random(min..max)
  defp random_value({:enum, list}), do: Enum.random(list)
  defp random_value(:bool), do: Enum.random([true, false])
  defp random_value(_), do: nil

  defp update_fbe03_cholesky(state) do
    {[pump_speed, diff_pressure, wort_clarity], new_key} =
      NxSim.fbe03_correlated(state.nx_key, @fbe03_correlation)

    Fato.atualizar(:fbe_03_pump_speed, pump_speed)
    Fato.atualizar(:fbe_03_diff_pressure, diff_pressure)
    Fato.atualizar(:fbe_03_wort_clarity, wort_clarity)
    %{state | nx_key: new_key}
  end
end
