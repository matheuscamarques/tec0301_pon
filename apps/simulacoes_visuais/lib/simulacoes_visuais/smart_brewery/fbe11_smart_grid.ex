defmodule SimulacoesVisuais.SmartBrewery.FBE11SmartGrid do
  @moduledoc """
  Relógio virtual 24h e tarifação horossazonal para FBE_11 (Smart Grid), alinhado ao artigo 12.

  **DSM e Smart Grid:** Tarifação dinâmica (fora de ponta, rampa, ponta 18h–21h), atualização de
  fbe_11_grid_power_cost e coordenação com fbe_09_cip_pump_state para cenários de teste (R_03).

  **V2G (Vehicle-to-Grid):** Recarga do buffer (fbe_11_v2g_battery_lvl) apenas fora de ponta;
  descarga pela ação PON FBE_11.discharge_v2g_buffer quando R_03 dispara (peak shaving).
  **Shallow cycling (artigo 12):** SoC mantido na faixa configurável (ex. 20–80%) para preservar
  SOH (State of Health): recarga limitada ao teto (soc_ceiling), descarga limitada ao piso (soc_floor)
  na ação em smart_brewery_fbe.ex.
  """

  use GenServer

  alias Tec0301Pon.PON.Fato

  require Logger

  # 1 tick = 6 minutos simulados → 24h em 240 ticks
  @minutes_per_tick 6
  @minutes_per_day 24 * 60

  # Recarga V2G: fora de ponta; madrugada (22h–06h) = taxa maior
  @recharge_off_peak 1
  @recharge_night 2
  # Shallow cycling (artigo 12): teto de SoC para preservar SOH
  @soc_ceiling 80

  # Faixas (hora do dia em float 0..24) => {min_cost, max_cost}
  @tariff_bands [
    # 00:00 - 17:00 fora de ponta
    {0, 17, 80, 110},
    # 17:00 - 18:00 rampa ascendente
    {17, 18, 120, 149},
    # 18:00 - 21:00 ponta (R_03 > 150)
    {18, 21, 180, 250},
    # 21:00 - 22:00 rampa descendente
    {21, 22, 120, 149},
    # 22:00 - 24:00 fora de ponta
    {22, 24, 80, 110}
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Avança o relógio virtual e atualiza fatos FBE_11 (e CIP durante ponta)."
  def tick do
    GenServer.cast(__MODULE__, :tick)
  end

  @impl true
  def init(_opts) do
    {:ok, %{sim_minutes: 0}}
  end

  @impl true
  def handle_cast(:tick, %{sim_minutes: sim_minutes} = state) do
    new_minutes = rem(sim_minutes + @minutes_per_tick, @minutes_per_day)
    hour = new_minutes / 60.0

    {cost_min, cost_max} = tariff_for_hour(hour)
    grid_cost = cost_min + :rand.uniform(max(1, cost_max - cost_min + 1)) - 1

    try do
      Fato.atualizar(:fbe_11_grid_power_cost, grid_cost)
    rescue
      e -> Logger.warning("[FBE11SmartGrid] Falha grid_power_cost: #{inspect(e)}")
    end

    # Recarga V2G apenas fora de ponta (nunca sobrescreve no mesmo tick que R_03 descarrega)
    in_peak = hour >= 18 and hour < 21
    in_off_peak = hour < 17 or hour >= 22
    in_night = hour >= 22 or hour < 6

    if in_off_peak do
      recharge = if in_night, do: @recharge_night, else: @recharge_off_peak
      current_v2g = safe_obter(:fbe_11_v2g_battery_lvl, 80)
      new_v2g = min(@soc_ceiling, current_v2g + recharge)

      try do
        Fato.atualizar(:fbe_11_v2g_battery_lvl, new_v2g)
      rescue
        _e -> :ok
      end
    end

    # Durante ponta, ligar CIP para criar cenário de teste R_03; fora de ponta, desligar
    try do
      Fato.atualizar(:fbe_09_cip_pump_state, if(in_peak, do: :on, else: :off))
    rescue
      _e -> :ok
    end

    {:noreply, %{state | sim_minutes: new_minutes}}
  end

  defp tariff_for_hour(hour) do
    Enum.find_value(@tariff_bands, fn {h_start, h_end, c_min, c_max} ->
      if hour >= h_start and hour < h_end, do: {c_min, c_max}, else: nil
    end) || {80, 110}
  end

  defp safe_obter(nome, default) do
    try do
      v = Fato.obter(nome)
      if is_number(v), do: round(v), else: default
    rescue
      _ -> default
    end
  end
end
