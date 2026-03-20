defmodule SimulacoesVisuais.SmartBrewery.TelemetryPipeline do
  @moduledoc """
  Pipeline Broadway para telemetria PON: produtor GenStage recebe eventos, batcher
  agrupa e envia lotes ao PubSub (backpressure e batching — artigo 06).
  Em cada flush de lote, se `:tsdb_enabled` (via `Application.get_env/3`) estiver ativo, a
  persistência é delegada ao TelemetryAsyncWriter (não bloqueia).
  """
  use Broadway

  require Logger
  alias Broadway.Message
  alias SimulacoesVisuais.SmartBrewery.TelemetryProducer

  @topic "smart_brewery:fatos"

  def start_link(_opts) do
    batch_size =
      Application.get_env(:simulacoes_visuais, :telemetry_pipeline_batch_size, 200)
      |> max(50)

    batch_timeout =
      Application.get_env(:simulacoes_visuais, :telemetry_pipeline_batch_timeout_ms, 300)
      |> max(100)

    tsdb_enabled = Application.get_env(:simulacoes_visuais, :tsdb_enabled, false)

    processor_concurrency =
      Application.get_env(:simulacoes_visuais, :telemetry_pipeline_processor_concurrency, 1)
      |> max(1)

    batcher_concurrency =
      Application.get_env(:simulacoes_visuais, :telemetry_pipeline_batcher_concurrency, 1)
      |> max(1)

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      context: %{tsdb_enabled: tsdb_enabled},
      producer: [
        module: {TelemetryProducer, [name: :smart_brewery_telemetry_producer]},
        transformer: {__MODULE__, :transform, []}
      ],
      processors: [
        default: [concurrency: processor_concurrency]
      ],
      batchers: [
        default: [
          concurrency: batcher_concurrency,
          batch_size: batch_size,
          batch_timeout: batch_timeout
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
        |> merge_message_data(%{})

      list = Map.to_list(merged)
      count = length(list)

      :telemetry.execute(
        [:simulacoes_visuais, :smart_brewery_telemetry_batcher, :flush],
        %{updates_count: count, buffer_size_before: count},
        %{}
      )

      Phoenix.PubSub.broadcast(SimulacoesVisuais.PubSub, @topic, {:batch, list})

      push_ema_numeric_loop(list)

      # Lê env em cada flush (alinhado ao SmartBreweryTelemetryBatcher), não só o context do arranque.
      if Application.get_env(:simulacoes_visuais, :tsdb_enabled, false) do
        SimulacoesVisuais.SmartBrewery.TelemetryAsyncWriter.cast_batch(list)
      end
    end

    messages
  end

  defp merge_message_data([], acc), do: acc

  defp merge_message_data([%Message{data: {k, v}} | rest], acc) do
    merge_message_data(rest, Map.put(acc, k, v))
  end

  defp push_ema_numeric_loop([]), do: :ok

  defp push_ema_numeric_loop([{nome, valor} | rest]) do
    if is_number(valor) do
      try do
        SimulacoesVisuais.SmartBrewery.EMA.push(nome, valor)
      rescue
        _ -> :ok
      end
    end

    push_ema_numeric_loop(rest)
  end
end
