defmodule SimulacoesVisuais.SmartBrewery.TelemetryProducer do
  @moduledoc """
  GenStage producer para Broadway: recebe eventos {:event, nome_fato, valor} via cast,
  armazena em fila e entrega sob demanda (backpressure). Registra-se com nome para
  o FactBroadcaster enviar eventos (artigo 06: ingestão com GenStage).
  """
  use GenStage

  def init(_opts) do
    # Não registramos este processo: Broadway já o nomeia (ex.: TelemetryPipeline.Broadway.Producer_0).
    # Um processo só pode ter um nome; FactBroadcaster resolve o producer via Broadway.producer_names/1.
    {:producer, %{queue: :queue.new(), pending_demand: 0}}
  end

  def handle_demand(demand, %{queue: queue, pending_demand: pending} = state) when demand > 0 do
    total = pending + demand
    {events, new_queue} = take_from_queue(queue, total)
    new_pending = total - length(events)
    {:noreply, events, %{state | queue: new_queue, pending_demand: new_pending}}
  end

  def handle_cast({:event, nome_fato, valor}, %{queue: queue} = state) do
    new_queue = :queue.in({nome_fato, valor}, queue)
    {:noreply, [], %{state | queue: new_queue}}
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
