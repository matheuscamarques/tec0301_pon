defmodule SimulacoesVisuais.SmartBrewery.TelemetryPipeline do
  @moduledoc """
  Pipeline Broadway para telemetria PON: produtor GenStage recebe eventos, batcher
  agrupa e envia lotes ao PubSub (backpressure e batching — artigo 06).
  Quando :tsdb_enabled, a persistência é feita neste handle_batch (uma transação
  por lote), alinhado ao artigo 14; caso contrário apenas broadcast e EMA.
  """
  use Broadway

  require Logger
  alias Broadway.Message
  alias SimulacoesVisuais.SmartBrewery.TelemetryProducer

  @topic "smart_brewery:fatos"

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {TelemetryProducer, [name: :smart_brewery_telemetry_producer]},
        transformer: {__MODULE__, :transform, []}
      ],
      processors: [
        default: [concurrency: 1]
      ],
      batchers: [
        default: [
          concurrency: 1,
          batch_size: 100,
          batch_timeout: 250
        ]
      ]
    )
  end

  def transform({nome_fato, valor}, _opts) do
    %Message{
      data: {nome_fato, valor},
      acknowledger: Broadway.NoopAcknowledger.init()
    }
  end

  @impl true
  def handle_message(_processor, message, _context) do
    message
    |> Message.put_batcher(:default)
    |> Message.put_batch_key(:telemetry)
  end

  @impl true
  def handle_batch(:default, messages, _batch_info, _context) do
    if messages != [] do
      merged =
        messages
        |> Enum.map(fn %Message{data: {k, v}} -> {k, v} end)
        |> Enum.into(%{}, fn {k, v} -> {k, v} end)

      list = Map.to_list(merged)
      count = length(list)

      :telemetry.execute(
        [:simulacoes_visuais, :smart_brewery_telemetry_batcher, :flush],
        %{updates_count: count, buffer_size_before: count},
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

      persist_batch(list)
    end

    messages
  end

  defp persist_batch(list) do
    if Application.get_env(:simulacoes_visuais, :tsdb_enabled, false) do
      rows = SimulacoesVisuais.TelemetryEvent.changesets_from_batch(list)
      if rows != [] do
        try do
          SimulacoesVisuais.Repo.insert_all(SimulacoesVisuais.TelemetryEvent, rows)
        rescue
          e -> Logger.warning("[TelemetryPipeline] insert_all failed: #{inspect(e)}")
        end
      end
    end
  end
end
