defmodule SimulacoesVisuais.SmartBrewery.FBE08Markov do
  @moduledoc """
  Cadeia de Markov em tempo discreto (DTMC) para a linha de envase (FBE_08), alinhada ao artigo 12.

  **Estados (ISO/artigo 12):**
  - `:operation` — Operação/Produtivo (Up): processamento nominal.
  - `:starvation` — Inanição: equipamento ocioso por atraso de material a montante.
  - `:blocking` — Bloqueio: estação a jusante ocupada, buffer cheio.
  - `:failure` — Falha (Down): jam, pane ou reparo.
  - `:setup` — Setup/Ajuste: reconfiguração de lote ou manutenção planejada.

  Atualiza fatos: fbe_08_capper_jam_sens (true em failure), liquid_lvl_detect, conveyor_speed,
  fill_head_status, stop_sensor. Tempo mínimo de permanência em failure e setup antes de transição
  (CTMC-like). Distribuição estacionária é calculada e publicada em `smart_brewery:markov_stationary`.
  """

  use GenServer

  alias Tec0301Pon.PON.Fato

  require Logger

  # Ordem dos estados para TPM e distribuição estacionária
  @states [:operation, :starvation, :blocking, :failure, :setup]
  @state_index %{operation: 0, starvation: 1, blocking: 2, failure: 3, setup: 4}

  @min_ticks_failure 2
  @min_ticks_setup 2

  # TPM (Transition Probability Matrix) 5x5 — linhas = estado atual, colunas = próximo estado
  # ordem: operation, starvation, blocking, failure, setup
  # Cada linha soma 1.0
  @tpm [
    # operation
    [0.92, 0.03, 0.02, 0.03, 0.00],
    # starvation
    [0.88, 0.08, 0.03, 0.00, 0.01],
    # blocking
    [0.82, 0.01, 0.12, 0.04, 0.01],
    # failure -> após reparo vai para setup
    [0.00, 0.00, 0.00, 0.05, 0.95],
    # setup
    [0.92, 0.00, 0.00, 0.00, 0.08]
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Avança um passo na cadeia de Markov e atualiza fatos FBE_08."
  def tick do
    GenServer.cast(__MODULE__, :tick)
  end

  @doc "Retorna a distribuição estacionária (mapa estado => probabilidade)."
  def stationary_distribution do
    GenServer.call(__MODULE__, :stationary_distribution)
  end

  @impl true
  def init(_opts) do
    stationary = compute_stationary()
    broadcast_stationary(stationary)
    {:ok, %{state: :operation, ticks_in_state: 0, stationary: stationary}}
  end

  @impl true
  def handle_cast(:tick, %{state: current, ticks_in_state: ticks, stationary: _old_stat} = state) do
    idx = Map.fetch!(@state_index, current)
    row = Enum.at(@tpm, idx)
    next = sample_next_state(row)

    # CTMC-like: tempo mínimo em failure e setup antes de sair
    next_state =
      cond do
        current == :failure and next != :failure and ticks < @min_ticks_failure ->
          :failure

        current == :setup and next != :setup and ticks < @min_ticks_setup ->
          :setup

        true ->
          next
      end

    new_ticks = if next_state == current, do: ticks + 1, else: 0

    # Fatos coerentes com o estado (artigo 12)
    capper_jam = next_state == :failure

    conveyor_speed =
      case next_state do
        :operation -> 70 + :rand.uniform(31) - 1
        :starvation -> 0
        :blocking -> 30 + :rand.uniform(20) - 1
        :failure -> 0
        :setup -> 0
      end

    fill_head =
      case next_state do
        :operation -> if(:rand.uniform(2) == 1, do: :filling, else: :idle)
        _ -> :idle
      end

    liquid_lvl = if next_state in [:failure, :blocking], do: :fail, else: :ok

    stop_sensor = next_state in [:failure, :setup]

    try do
      Fato.atualizar(:fbe_08_capper_jam_sens, capper_jam)
      Fato.atualizar(:fbe_08_conveyor_speed, conveyor_speed)
      Fato.atualizar(:fbe_08_fill_head_status, fill_head)
      Fato.atualizar(:fbe_08_liquid_lvl_detect, liquid_lvl)
      Fato.atualizar(:fbe_08_stop_sensor, stop_sensor)
    rescue
      e -> Logger.warning("[FBE08Markov] Falha ao atualizar fatos: #{inspect(e)}")
    end

    {:noreply, %{state | state: next_state, ticks_in_state: new_ticks}}
  end

  @impl true
  def handle_call(:stationary_distribution, _from, %{stationary: stat} = state) do
    {:reply, stat, state}
  end

  defp sample_next_state(probs) do
    r = :rand.uniform()

    result =
      @states
      |> Enum.zip(probs)
      |> Enum.reduce_while({0.0, nil}, fn {s, p}, {acc, _} ->
        new_acc = acc + p
        if r <= new_acc, do: {:halt, {new_acc, s}}, else: {:cont, {new_acc, s}}
      end)

    case result do
      {_, s} when is_atom(s) -> s
      _ -> List.last(@states)
    end
  end

  # Power iteration: π_{n+1} = π_n P; normalizar; repetir até convergir
  defp compute_stationary do
    n = length(@states)
    pi = List.duplicate(1.0 / n, n)

    pi_final =
      Enum.reduce(1..100, pi, fn _iter, prev ->
        next =
          Enum.map(0..(n - 1), fn j ->
            Enum.zip(prev, Enum.map(@tpm, fn row -> Enum.at(row, j) end))
            |> Enum.map(fn {a, b} -> a * b end)
            |> Enum.sum()
          end)

        s = Enum.sum(next)
        Enum.map(next, &(&1 / s))
      end)

    Map.new(Enum.zip(@states, pi_final))
  end

  defp broadcast_stationary(stat) do
    Phoenix.PubSub.broadcast(
      SimulacoesVisuais.PubSub,
      "smart_brewery:markov_stationary",
      {:markov_stationary, :fbe_08, stat}
    )
  end
end
