defmodule SimulacoesVisuais.SmartBrewery.TelemetryProducer do
  @moduledoc """
  GenStage producer para Broadway: recebe eventos {:event, nome_fato, valor} via cast,
  armazena em fila e entrega sob demanda (backpressure). Registra-se com nome para
  o FactBroadcaster enviar eventos (artigo 06: ingestão com GenStage).

  A fila é limitada por `:telemetry_producer_max_queue` em config (default 5000).
  Quando a fila atinge o limite, o evento mais antigo é descartado para evitar
  crescimento ilimitado de memória.

  Em `handle_cast/2`, se `pending_demand > 0` (Broadway pediu eventos com fila vazia),
  os itens recém-enfileirados são emitidos de imediato; caso contrário o producer
  ficaria sem drenar até novo `handle_demand`, sintoma: `rule_events` ativos mas
  `telemetry_events` parado.
  """
  use GenStage

  @default_max_queue 5_000

  def init(_opts) do
    # Não registramos este processo: Broadway já o nomeia (ex.: TelemetryPipeline.Broadway.Producer_0).
    # Um processo só pode ter um nome; FactBroadcaster resolve o producer via Broadway.producer_names/1.
    max_queue =
      Application.get_env(:simulacoes_visuais, :telemetry_producer_max_queue, @default_max_queue)
      |> max(100)

    state = %{queue: :queue.new(), pending_demand: 0, max_queue: max_queue}
    {:producer, state}
  end

  def handle_demand(demand, %{queue: queue, pending_demand: pending} = state) when demand > 0 do
    total = pending + demand
    {events, new_queue} = take_from_queue(queue, total)
    new_pending = total - length(events)
    {:noreply, events, %{state | queue: new_queue, pending_demand: new_pending}}
  end

  def handle_cast(
        {:event, nome_fato, valor},
        %{queue: queue, max_queue: max_queue, pending_demand: pending} = state
      ) do
    new_queue =
      if :queue.len(queue) >= max_queue do
        {{:value, _dropped}, tail} = :queue.out(queue)
        :queue.in({nome_fato, valor}, tail)
      else
        :queue.in({nome_fato, valor}, queue)
      end

    # Broadway já pode ter pedido demanda com fila vazia (pending_demand > 0). Se não
    # emitirmos aqui, o evento fica preso na fila até um novo handle_demand — em
    # cenários comuns fica sem drenar e o TSDB deixa de receber telemetria.
    if pending > 0 do
      {events, drained_queue} = take_from_queue(new_queue, pending)
      new_pending = pending - length(events)
      {:noreply, events, %{state | queue: drained_queue, pending_demand: new_pending}}
    else
      {:noreply, [], %{state | queue: new_queue}}
    end
  end

  defp take_from_queue(queue, n) when n <= 0, do: {[], queue}

  defp take_from_queue(queue, n) do
    case :queue.out(queue) do
      {{:value, head}, tail} ->
        {rest, final_tail} = take_from_queue(tail, n - 1)
        {[head | rest], final_tail}

      {:empty, _} ->
        {[], queue}
    end
  end
end
