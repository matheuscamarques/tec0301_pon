defmodule SimulacoesVisuais.LiveViewEventBatcher do
  @moduledoc """
  GenServer que acumula eventos de fatos numa janela (tempo e/ou tamanho) e envia
  um único lote à LiveView via PubSub. Reduz a sobrecarga: em vez de N mensagens
  por onda de atualização, a LiveView recebe 1 mensagem `{:batch, list}` por janela.

  Configurável por Application config:
  - `:live_view_batcher` -> `window_ms` (default 120), `max_buffer_size` (default 80)
  """
  use GenServer

  require Logger

  @topic "smart_brewery:liveview_batch"
  @window_ms 120
  @max_buffer_size 80

  @doc "Envia uma atualização de fato para ser incluída no próximo batch enviado à LiveView."
  def push(nome_do_fato, novo_valor) do
    GenServer.cast(__MODULE__, {:fato, nome_do_fato, novo_valor})
  end

  def start_link(opts \\ []) do
    window_ms = Keyword.get(opts, :window_ms, @window_ms)
    max_size = Keyword.get(opts, :max_buffer_size, @max_buffer_size)

    GenServer.start_link(__MODULE__, %{window_ms: window_ms, max_buffer_size: max_size},
      name: __MODULE__
    )
  end

  @impl true
  def init(state) do
    {:ok,
     state
     |> Map.put(:buffer, %{})
     |> Map.put(:timer_ref, nil)}
  end

  @impl true
  def handle_cast(
        {:fato, nome_do_fato, novo_valor},
        %{buffer: buffer, timer_ref: timer_ref, window_ms: window_ms, max_buffer_size: max_size} =
          state
      ) do
    new_buffer = Map.put(buffer, nome_do_fato, novo_valor)
    size = map_size(new_buffer)

    {new_timer_ref, state_after} =
      if timer_ref do
        # Janela já agendada
        {timer_ref, %{state | buffer: new_buffer}}
      else
        ref = Process.send_after(self(), :flush, window_ms)
        {ref, %{state | buffer: new_buffer, timer_ref: ref}}
      end

    # Flush imediato se atingir o tamanho máximo (backpressure em picos)
    if size >= max_size do
      if new_timer_ref, do: Process.cancel_timer(new_timer_ref)
      send(self(), :flush)
      {:noreply, %{state_after | buffer: new_buffer, timer_ref: nil}}
    else
      {:noreply, %{state_after | timer_ref: new_timer_ref}}
    end
  end

  @impl true
  def handle_info(:flush, %{buffer: buffer, timer_ref: _} = state) do
    if buffer != %{} do
      list = Map.to_list(buffer)
      count = length(list)

      Phoenix.PubSub.broadcast(SimulacoesVisuais.PubSub, @topic, {:batch, list})

      Logger.debug("[LiveViewEventBatcher] Flush #{count} atualizações para a LiveView.")
    end

    {:noreply, %{state | buffer: %{}, timer_ref: nil}}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
