defmodule SimulacoesVisuais.SmartBrewery.TelemetryAsyncWriter do
  @moduledoc """
  Persistência assíncrona de telemetria no TSDB.

  Recebe lotes via `cast/1` e persiste em background, desacoplando o Broadway
  da escrita no banco. Evita bloqueio do pipeline quando o DB está lento.

  - Fila limitada por `:telemetry_async_writer_max_queue` (default 50 lotes).
  - Quando a fila enche, descarta o lote mais antigo (mantém os mais recentes).
  - Um lote por vez é persistido; após cada insert agenda o próximo.
  """
  use GenServer

  require Logger

  @default_max_queue 50

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Envia um lote para persistência assíncrona. Não bloqueia."
  def cast_batch(list) when is_list(list) do
    GenServer.cast(__MODULE__, {:batch, list})
  end

  @impl true
  def init(_opts) do
    max_queue =
      Application.get_env(
        :simulacoes_visuais,
        :telemetry_async_writer_max_queue,
        @default_max_queue
      )
      |> max(5)

    {:ok, %{queue: [], max_queue: max_queue, processing: false}}
  end

  @impl true
  def handle_cast(
        {:batch, list},
        %{queue: queue, max_queue: max_queue, processing: processing} = state
      ) do
    if list == [] do
      {:noreply, state}
    else
      new_queue =
        if length(queue) >= max_queue do
          # Descarta o mais antigo (primeiro da fila), adiciona o novo ao final
          [_dropped | rest] = queue
          rest ++ [list]
        else
          queue ++ [list]
        end

      state_after = %{state | queue: new_queue}

      if processing do
        {:noreply, state_after}
      else
        Process.send_after(self(), :flush, 0)
        {:noreply, %{state_after | processing: true}}
      end
    end
  end

  @impl true
  def handle_info(:flush, %{queue: []} = state) do
    {:noreply, %{state | processing: false}}
  end

  def handle_info(:flush, %{queue: [batch | rest]} = state) do
    persist(batch)
    Process.send_after(self(), :flush, 0)
    {:noreply, %{state | queue: rest}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp persist(list) do
    try do
      rows = SimulacoesVisuais.TelemetryEvent.changesets_from_batch(list)

      if rows != [] do
        SimulacoesVisuais.Repo.insert_all(SimulacoesVisuais.TelemetryEvent, rows)
        SimulacoesVisuais.SmartBrewery.PowerBIPushSink.cast_rows(rows)
      end
    rescue
      e -> Logger.warning("[TelemetryAsyncWriter] insert_all failed: #{inspect(e)}")
    end
  end
end
