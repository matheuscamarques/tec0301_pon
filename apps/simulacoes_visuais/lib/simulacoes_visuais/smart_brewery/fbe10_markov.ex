defmodule SimulacoesVisuais.SmartBrewery.FBE10Markov do
  @moduledoc """
  Cadeia de Markov em tempo discreto para a frota AMR (FBE_10). Estados: nominal,
  carregando, collision, recovery. Atualiza fbe_10_collision_alert e fbe_10_robot_1_status
  de forma coerente (artigo 06: DES para robótica logística).
  """

  use GenServer

  alias Tec0301Pon.PON.Fato

  require Logger

  @min_ticks_collision 2
  @min_ticks_recovery 2

  # Alta disponibilidade; transição para collision rara
  @transition_nominal [{:nominal, 9920}, {:carregando, 9980}, {:collision, 10000}]
  @transition_carregando [{:nominal, 8500}, {:carregando, 9950}, {:collision, 10000}]
  @transition_collision [{:collision, 500}, {:recovery, 10000}]
  @transition_recovery [{:recovery, 200}, {:nominal, 10000}]

  @transitions %{
    nominal: @transition_nominal,
    carregando: @transition_carregando,
    collision: @transition_collision,
    recovery: @transition_recovery
  }

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc "Avança um passo na cadeia de Markov e atualiza fatos FBE_10."
  def tick do
    GenServer.cast(__MODULE__, :tick)
  end

  @impl true
  def init(_opts) do
    {:ok, %{state: :nominal, ticks_in_state: 0}}
  end

  @impl true
  def handle_cast(:tick, %{state: current, ticks_in_state: ticks} = state) do
    row = Map.fetch!(@transitions, current)
    r = :rand.uniform(10000)
    candidate = Enum.find_value(row, fn {s, cum} -> r <= cum and s end)

    next =
      cond do
        current == :collision and candidate == :recovery and ticks < @min_ticks_collision ->
          :collision

        current == :recovery and candidate == :nominal and ticks < @min_ticks_recovery ->
          :recovery

        true ->
          candidate
      end

    new_ticks = if next == current, do: ticks + 1, else: 0

    collision_alert = next == :collision
    robot_status = status_for_state(next)

    battery =
      if next == :nominal or next == :carregando,
        do: 95 + :rand.uniform(5) - 1,
        else: safe_obter(:fbe_10_robot_1_battery, 80)

    try do
      Fato.atualizar(:fbe_10_collision_alert, collision_alert)
      Fato.atualizar(:fbe_10_robot_1_status, robot_status)
      Fato.atualizar(:fbe_10_robot_1_battery, battery)
    rescue
      e -> Logger.warning("[FBE10Markov] Falha ao atualizar fatos: #{inspect(e)}")
    end

    {:noreply, %{state | state: next, ticks_in_state: new_ticks}}
  end

  defp status_for_state(:nominal), do: if(:rand.uniform(2) == 1, do: :ocioso, else: :em_transito)
  defp status_for_state(:carregando), do: :carregando
  defp status_for_state(:collision), do: :falha
  defp status_for_state(:recovery), do: :ocioso

  defp safe_obter(nome, default) do
    try do
      v = Fato.obter(nome)
      if is_integer(v), do: v, else: default
    rescue
      _ -> default
    end
  end
end
