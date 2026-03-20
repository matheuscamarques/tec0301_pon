defmodule SimulacoesVisuais.SmartBreweryTelemetryBatcher do
  @moduledoc """
  Acumula notificações de fatos do PON e envia em lotes (batch) ao PubSub a cada
  intervalo ou quando o buffer atinge o tamanho máximo (backpressure em picos).
  """

  use GenServer

  require Logger

  @topic "smart_brewery:fatos"
  @flush_interval_ms 250
  @max_buffer_size 100

  def start_link(opts \\ []) do
    interval = Keyword.get(opts, :flush_interval_ms, @flush_interval_ms)
    max_size = Keyword.get(opts, :max_buffer_size, @max_buffer_size)

    GenServer.start_link(__MODULE__, %{flush_interval_ms: interval, max_buffer_size: max_size},
      name: __MODULE__
    )
  end

  @doc "Envia uma atualização de fato para ser incluída no próximo batch."
  def push(nome_do_fato, novo_valor) do
    GenServer.cast(__MODULE__, {:fato, nome_do_fato, novo_valor})
  end

  @impl true
  def init(state) do
    {:ok,
     state
     |> Map.put(:buffer, [])
     |> Map.put(:timer_ref, nil)}
  end

  @impl true
  def handle_cast(
        {:fato, nome_do_fato, novo_valor},
        %{
          buffer: buffer,
          timer_ref: timer_ref,
          flush_interval_ms: interval,
          max_buffer_size: max_size
        } = state
      ) do
    if timer_ref, do: Process.cancel_timer(timer_ref)

    new_buffer = [{nome_do_fato, novo_valor} | buffer]

    # Flush imediato se buffer atingir o limite (contrapressão)
    if length(new_buffer) >= max_size do
      send(self(), :flush)
      {:noreply, %{state | buffer: new_buffer, timer_ref: nil}}
    else
      ref = Process.send_after(self(), :flush, interval)
      {:noreply, %{state | buffer: new_buffer, timer_ref: ref}}
    end
  end

  @impl true
  def handle_info(:flush, %{buffer: buffer} = state) do
    if buffer != [] do
      buffer_count = length(buffer)
      # Última atualização vence quando o mesmo fato aparece várias vezes no batch
      merged = Enum.into(buffer, %{}, fn {k, v} -> {k, v} end)
      list = Map.to_list(merged)
      updates_count = length(list)

      :telemetry.execute(
        [:simulacoes_visuais, :smart_brewery_telemetry_batcher, :flush],
        %{updates_count: updates_count, buffer_size_before: buffer_count},
        %{}
      )

      Phoenix.PubSub.broadcast(SimulacoesVisuais.PubSub, @topic, {:batch, list})

      for {nome, valor} <- list, is_number(valor) do
        try do
          SimulacoesVisuais.SmartBrewery.EMA.push(nome, valor)
        rescue
          _ -> :ok
        end
      end

      # Paridade com `TelemetryPipeline.handle_batch/4`: sem isto, quando o FactBroadcaster
      # faz fallback para este batcher (producer Broadway indisponível), OEE/LiveView recebem
      # `smart_brewery:fatos` mas `telemetry_events` deixa de ser persistido.
      if Application.get_env(:simulacoes_visuais, :tsdb_enabled, false) do
        SimulacoesVisuais.SmartBrewery.TelemetryAsyncWriter.cast_batch(list)
      end

      Logger.debug("[SmartBreweryTelemetryBatcher] Flush #{updates_count} atualizações.")
    end

    {:noreply, %{state | buffer: [], timer_ref: nil}}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
