defmodule SimulacoesVisuais.SmartBrewery.FBE07Fermentation do
  @moduledoc """
  Modelo cinético de fermentação para FBE_07 (Fermentador B), espelho do FBE_06.
  Quatro fases: lag → growth → stationary → flocculation. Brix monotônico até FG,
  termodinâmica exotérmica, CO2 e glycol por setpoint (artigo 06).

  **Referências teóricas (artigo 12):** Simplificação fenomenológica; bases em Gee & Ramirez (consumo
  sequencial de açúcares) e De Andrés-Toro et al. (compartimentos de biomassa e subprodutos flavorizantes).
  """

  use GenServer

  alias Tec0301Pon.PON.Fato

  require Logger

  @temp_setpoint 20
  @temp_max_growth 23.0
  @brix_initial 13.5
  @fg 3.0
  @lag_hours 16
  @growth_brix_threshold 4.0
  @stationary_hours 24
  @brix_decay_rate 0.26
  @heat_coef 0.8

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc "Avança um tick de fermentação e atualiza fatos FBE_07."
  def tick do
    GenServer.cast(__MODULE__, :tick)
  end

  @impl true
  def init(_opts) do
    state = %{
      sim_hours: 0,
      phase: :lag,
      brix: @brix_initial,
      temp: 18.0,
      co2_flow: 0,
      stationary_hours: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_cast(:tick, state) do
    %{sim_hours: h, phase: phase, brix: brix, temp: temp, co2_flow: co2, stationary_hours: sh} =
      state

    {new_phase, new_brix, new_temp, new_co2} =
      case phase do
        :lag ->
          if h >= @lag_hours, do: step_growth(brix, temp, co2), else: {phase, brix, temp, 0}

        :growth ->
          step_growth(brix, temp, co2)

        :stationary ->
          if sh >= @stationary_hours,
            do: step_flocculation(temp),
            else: step_stationary(brix, temp, co2)

        :flocculation ->
          {:flocculation, max(@fg, brix - 0.01), max(0, temp - 0.5), 0}
      end

    new_stationary = if new_phase == :stationary, do: sh + 1, else: 0
    phase_for_rule = if new_phase == :flocculation, do: :flocculation, else: new_phase

    glycol =
      if new_phase == :flocculation,
        do: :on,
        else: if(new_temp > @temp_setpoint, do: :on, else: :off)

    try do
      Fato.atualizar(:fbe_07_ferm_phase, phase_for_rule)
      Fato.atualizar(:fbe_07_gravity_brix, round(new_brix * 10) / 10)
      Fato.atualizar(:fbe_07_internal_temp, round(new_temp * 10) / 10)
      Fato.atualizar(:fbe_07_co2_exhaust_flow, round(new_co2))
      Fato.atualizar(:fbe_07_glycol_jacket_st, glycol)
      Fato.atualizar(:fbe_07_pressure, if(new_co2 > 5, do: 1, else: 0))
    rescue
      e -> Logger.warning("[FBE07Fermentation] Falha ao atualizar fatos: #{inspect(e)}")
    end

    new_state = %{
      state
      | sim_hours: h + 1,
        phase: new_phase,
        brix: new_brix,
        temp: new_temp,
        co2_flow: new_co2,
        stationary_hours: new_stationary
    }

    {:noreply, new_state}
  end

  defp step_growth(brix, temp, _co2) do
    remaining = brix - @fg

    dbrix =
      if remaining > 0.01 do
        -min(@brix_decay_rate, remaining * 0.15)
      else
        0
      end

    new_brix = max(@fg, brix + dbrix)
    dtemp = -dbrix * @heat_coef
    new_temp = min(@temp_max_growth, temp + dtemp)
    co2 = if new_brix > @growth_brix_threshold, do: 25 + :rand.uniform(20) - 1, else: 15
    phase = if new_brix <= @growth_brix_threshold, do: :stationary, else: :growth
    {phase, new_brix, new_temp, co2}
  end

  defp step_stationary(brix, temp, co2) do
    drop = min(0.05, brix - @fg)
    new_brix = max(@fg, brix - drop)
    new_temp = max(18, temp - 0.1)
    new_co2 = max(0, co2 - 1)
    {:stationary, new_brix, new_temp, new_co2}
  end

  defp step_flocculation(_temp) do
    {:flocculation, @fg, 1.0, 0}
  end
end
