defmodule SimulacoesVisuais.SmartBrewery.OEE do
  @moduledoc """
  Eficiência Global do Equipamento (Overall Equipment Effectiveness) — artigo 07 §5.2 e artigo 12 (Nakajima).

  OEE = Availability × Performance × Quality.

  - **Modo fatos (padrão):** calculado a partir dos fatos PON (disponibilidade por falhas,
    performance por motor_rpm/conveyor vs nominal, qualidade por wort_clarity/liquid_lvl).
  - **Modo Nakajima (opcional):** métricas baseadas em tempo e contagem (artigo 12):
    - Disponibilidade = Tempo Real Operacional / Tempo Planejado
    - Performance = (Ideal Cycle Time × Total Peças) / Tempo Real Operacional
    - Qualidade = Peças Boas / Total Peças

  Configure `:oee_nakajima_enabled` e parâmetros em config para ativar o modo Nakajima.
  Publica OEE em `smart_brewery:oee` com throttle configurável (`:oee_pubsub_min_interval_ms`, default 1s)
  para reduzir broadcasts e gravações em `oee_snapshots` quando o TSDB está ativo.
  """

  use GenServer

  @topic "smart_brewery:fatos"
  @topic_oee "smart_brewery:oee"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Retorna o último OEE calculado (0-100) ou nil se ainda não calculado."
  def get do
    GenServer.call(__MODULE__, :get)
  end

  @doc "Retorna os componentes A/P/Q e OEE: %{availability: a, performance: p, quality: q, oee: oee} ou nil."
  def get_components do
    GenServer.call(__MODULE__, :get_components)
  end

  @impl true
  def init(opts) do
    Phoenix.PubSub.subscribe(SimulacoesVisuais.PubSub, @topic)

    nakajima =
      Keyword.get(opts, :nakajima_enabled) ||
        Application.get_env(:simulacoes_visuais, :oee_nakajima_enabled, false)

    seconds_per_batch =
      Keyword.get(opts, :seconds_per_batch) ||
        Application.get_env(:simulacoes_visuais, :oee_seconds_per_batch, 6)

    ideal_cycle_sec =
      Keyword.get(opts, :ideal_cycle_time_sec) ||
        Application.get_env(:simulacoes_visuais, :oee_ideal_cycle_time_sec, 3.0)

    planned_shift_sec =
      Keyword.get(opts, :planned_shift_sec) ||
        Application.get_env(:simulacoes_visuais, :oee_planned_shift_sec, 8 * 3600)

    oee_pubsub_min_interval_ms =
      Keyword.get(opts, :oee_pubsub_min_interval_ms) ||
        Application.get_env(:simulacoes_visuais, :oee_pubsub_min_interval_ms, 1_000)

    state = %{
      oee_percent: nil,
      oee_components: nil,
      nakajima_enabled: nakajima,
      seconds_per_batch: seconds_per_batch,
      ideal_cycle_time_sec: ideal_cycle_sec,
      planned_shift_sec: planned_shift_sec,
      planned_time_sec: 0.0,
      run_time_sec: 0.0,
      total_pieces: 0,
      good_pieces: 0,
      oee_pubsub_min_interval_ms: oee_pubsub_min_interval_ms,
      last_oee_broadcast_ms: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:batch, updates}, state) when is_list(updates) do
    fatos = Map.new(updates)

    {oee, components, nakajima_updates} =
      if state.nakajima_enabled do
        compute_oee_nakajima(fatos, state)
      else
        oee_pct = compute_oee_facts(fatos)

        comp = %{
          availability: availability_facts(fatos),
          performance: performance_facts(fatos),
          quality: quality_facts(fatos),
          oee: oee_pct
        }

        {oee_pct, comp, %{}}
      end

    new_state =
      state
      |> Map.put(:oee_percent, oee)
      |> Map.put(:oee_components, components)
      |> Map.merge(nakajima_updates)
      |> maybe_broadcast_oee_throttled(oee, components)

    {:noreply, new_state}
  end

  def handle_info(_, state), do: {:noreply, state}

  @impl true
  def handle_call(:get, _from, state) do
    {:reply, state.oee_percent, state}
  end

  def handle_call(:get_components, _from, state) do
    {:reply, state.oee_components, state}
  end

  defp compute_oee_facts(fatos) do
    a = availability_facts(fatos)
    p = performance_facts(fatos)
    q = quality_facts(fatos)
    round(a * p * q * 100) / 100
  end

  defp compute_oee_nakajima(fatos, state) do
    dt = state.seconds_per_batch
    ideal = state.ideal_cycle_time_sec
    planned_cap = state.planned_shift_sec

    fault =
      Map.get(fatos, :fbe_11_grid_fault_detec) == true or
        Map.get(fatos, :fbe_08_capper_jam_sens) == true or
        Map.get(fatos, :fbe_10_collision_alert) == true

    planned_new = min(state.planned_time_sec + dt, planned_cap)
    run_new = if fault, do: state.run_time_sec, else: state.run_time_sec + dt

    pieces_this_slice = if fault, do: 0, else: max(0, Float.floor(dt / ideal))
    total_new = state.total_pieces + pieces_this_slice

    q_factor = quality_factor_facts(fatos)
    good_new = state.good_pieces + Float.round(pieces_this_slice * q_factor)

    availability = if planned_new > 0, do: run_new / planned_new, else: 0.0
    availability = min(1.0, availability)

    performance =
      if run_new > 0 and total_new > 0,
        do: min(1.0, ideal * total_new / run_new),
        else: 0.0

    quality = if total_new > 0, do: good_new / total_new, else: 1.0
    quality = min(1.0, quality)

    oee = availability * performance * quality
    oee_pct = round(oee * 100) / 100

    components = %{
      availability: round(availability * 100) / 100,
      performance: round(performance * 100) / 100,
      quality: round(quality * 100) / 100,
      oee: oee_pct
    }

    nakajima_updates = %{
      planned_time_sec: planned_new,
      run_time_sec: run_new,
      total_pieces: total_new,
      good_pieces: good_new
    }

    {oee_pct, components, nakajima_updates}
  end

  defp maybe_broadcast_oee_throttled(state, pct, components) do
    interval = state.oee_pubsub_min_interval_ms
    now = :erlang.monotonic_time(:millisecond)

    allow? =
      interval <= 0 or state.last_oee_broadcast_ms == nil or
        now - state.last_oee_broadcast_ms >= interval

    if allow? do
      broadcast_oee(pct, components)
      %{state | last_oee_broadcast_ms: now}
    else
      state
    end
  end

  defp broadcast_oee(pct, components) do
    Phoenix.PubSub.broadcast(SimulacoesVisuais.PubSub, @topic_oee, {:oee_update, pct, components})
  end

  defp availability_facts(fatos) do
    fault =
      Map.get(fatos, :fbe_11_grid_fault_detec) == true or
        Map.get(fatos, :fbe_08_capper_jam_sens) == true or
        Map.get(fatos, :fbe_10_collision_alert) == true

    if fault, do: 0.85, else: 1.0
  end

  defp performance_facts(fatos) do
    rpm = to_float(Map.get(fatos, :fbe_01_motor_rpm))
    conveyor = to_float(Map.get(fatos, :fbe_08_conveyor_speed))
    p_rpm = if rpm != nil, do: min(1.0, rpm / 3000), else: 0.7
    p_conv = if conveyor != nil, do: min(1.0, conveyor / 100), else: 0.7
    (p_rpm + p_conv) / 2
  end

  defp quality_facts(fatos) do
    clarity = to_float(Map.get(fatos, :fbe_03_wort_clarity))
    lvl = Map.get(fatos, :fbe_08_liquid_lvl_detect)
    q_clarity = if clarity != nil, do: min(1.0, clarity / 80), else: 0.8
    q_lvl = if lvl == :ok, do: 1.0, else: 0.9
    (q_clarity + q_lvl) / 2
  end

  defp quality_factor_facts(fatos) do
    quality_facts(fatos)
  end

  defp to_float(n) when is_number(n), do: n * 1.0
  defp to_float(_), do: nil
end
