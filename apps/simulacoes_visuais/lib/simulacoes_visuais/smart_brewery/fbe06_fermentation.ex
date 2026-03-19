defmodule SimulacoesVisuais.SmartBrewery.FBE06Fermentation do
  @moduledoc """
  Modelo cinético de fermentação (FBE_06): quatro fases biológicas (lag → growth → stationary → flocculation).
  Brix monotônico até FG (Final Gravity); termodinâmica exotérmica na growth; CO2 pico na growth;
  glycol on/off por setpoint. Acoplamento coerente com RegraSmartGridLoadBalancing (R_03).

  **Referências teóricas (artigo 12):** O modelo atual é uma simplificação fenomenológica (fases + Brix + CO2 + pH).
  As bases teóricas são a cinética de Gee & Ramirez (1994) — consumo hierárquico de glicose, maltose e maltotriose
  com inibição catabólica — e a formulação de De Andrés-Toro et al. (1998) para controle preditivo, com
  compartimentos de biomassa (células latentes, ativas, mortas/floculantes) e subprodutos (diacetil, ésteres).
  Extensões futuras podem incluir Arrhenius para constantes cinéticas dependentes da temperatura.

  Constantes (artigo 06):
  - Lag: Brix estático no knock-out (12–18 Brix), co2_exhaust_flow nulo; duração 12–24 h simuladas.
  - Growth: consumo de açúcar (taxa tipo Gompertz em direção a FG), calor ∝ derivada da queda de Brix; pH reduz por subprodutos (pirúvico, succínico).
  - Stationary: Brix tende a FG; exotérmia e CO2 reduzem; pH tende a valor final.
  - Flocculation: crash cooling; temperatura forçada para ~0 °C, Brix estável em FG.
  """

  use GenServer

  alias Tec0301Pon.PON.Fato

  require Logger

  # Setpoint de temperatura para atuação do glycol (evitar ésteres acima disso)
  @temp_setpoint 20
  @temp_max_growth 23.0
  # Knock-out: 12–18 Brix típico; FG = gravidade final
  @brix_initial 14.0
  @fg 3.0
  # Lag: 12–24 h simuladas (1 tick = 1 h)
  @lag_hours 14
  # Transição growth → stationary quando Brix atinge este limiar acima de FG
  @growth_brix_threshold 4.0
  @stationary_hours 24
  # Gompertz-like: taxa máxima de queda de Brix por hora na growth
  @brix_decay_rate 0.28
  # Constante de calor exotérmico (dtemp ∝ -dbrix * heat_coef)
  @heat_coef 0.8
  # pH: mosto ~5.2; redução por ácidos (pirúvico, succínico) até ~4.2
  @ph_initial 5.2
  @ph_final 4.2
  @ph_decay_per_tick 0.02

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc "Avança um tick de fermentação e atualiza fatos FBE_06."
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
      stationary_hours: 0,
      ph: @ph_initial
    }

    {:ok, state}
  end

  @impl true
  def handle_cast(:tick, state) do
    %{
      sim_hours: h,
      phase: phase,
      brix: brix,
      temp: temp,
      co2_flow: co2,
      stationary_hours: sh,
      ph: ph
    } =
      state

    {new_phase, new_brix, new_temp, new_co2, new_ph} =
      case phase do
        :lag ->
          if h >= @lag_hours do
            {p, br, t, c} = step_growth(brix, temp, co2)
            {p, br, t, c, ph - @ph_decay_per_tick}
          else
            {phase, brix, temp, 0, ph}
          end

        :growth ->
          {p, br, t, c} = step_growth(brix, temp, co2)
          {p, br, t, c, max(@ph_final, ph - @ph_decay_per_tick)}

        :stationary ->
          if sh >= @stationary_hours do
            {p, br, t, c} = step_flocculation(temp)
            {p, br, t, c, max(@ph_final, ph - 0.01)}
          else
            {p, br, t, c} = step_stationary(brix, temp, co2)
            {p, br, t, c, max(@ph_final, ph - 0.01)}
          end

        :flocculation ->
          {:flocculation, max(@fg, brix - 0.01), max(0, temp - 0.5), 0,
           max(@ph_final, ph - 0.005)}
      end

    new_ph_rounded = round(new_ph * 10) / 10
    new_stationary = if new_phase == :stationary, do: sh + 1, else: 0
    phase_for_rule = if new_phase == :flocculation, do: :flocculation, else: new_phase

    # Glycol: ligar se temp > setpoint (evitar ésteres); flocculation = crash cooling sempre :on
    glycol =
      if new_phase == :flocculation,
        do: :on,
        else: if(new_temp > @temp_setpoint, do: :on, else: :off)

    try do
      Fato.atualizar(:fbe_06_ferm_phase, phase_for_rule)
      Fato.atualizar(:fbe_06_gravity_brix, round(new_brix * 10) / 10)
      Fato.atualizar(:fbe_06_internal_temp, round(new_temp * 10) / 10)
      Fato.atualizar(:fbe_06_co2_exhaust_flow, round(new_co2))
      Fato.atualizar(:fbe_06_glycol_jacket_st, glycol)
      Fato.atualizar(:fbe_06_pressure, if(new_co2 > 5, do: 1, else: 0))
      Fato.atualizar(:fbe_06_ph, new_ph_rounded)
    rescue
      e -> Logger.warning("[FBE06Fermentation] Falha ao atualizar fatos: #{inspect(e)}")
    end

    new_state = %{
      state
      | sim_hours: h + 1,
        phase: new_phase,
        brix: new_brix,
        temp: new_temp,
        co2_flow: new_co2,
        stationary_hours: new_stationary,
        ph: new_ph
    }

    {:noreply, new_state}
  end

  # Gompertz-like: taxa de queda proporcional a (brix - FG), limitada por @brix_decay_rate
  defp step_growth(brix, temp, _co2) do
    remaining = brix - @fg

    dbrix =
      if remaining > 0.01 do
        -min(@brix_decay_rate, remaining * 0.15)
      else
        0
      end

    new_brix = max(@fg, brix + dbrix)
    # Exotérmico: calor proporcional à derivada da queda de Brix
    dtemp = -dbrix * @heat_coef
    new_temp = min(@temp_max_growth, temp + dtemp)
    co2 = if new_brix > @growth_brix_threshold, do: 25 + :rand.uniform(20) - 1, else: 15
    phase = if new_brix <= @growth_brix_threshold, do: :stationary, else: :growth
    {phase, new_brix, new_temp, co2}
  end

  defp step_stationary(brix, temp, co2) do
    # Brix tende suavemente a FG; exotérmia e CO2 reduzem
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
