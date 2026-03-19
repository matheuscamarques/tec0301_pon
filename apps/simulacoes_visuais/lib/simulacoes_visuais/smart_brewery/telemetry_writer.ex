defmodule SimulacoesVisuais.SmartBrewery.TelemetryWriter do
  @moduledoc """
  Escreve batches de telemetria no TSDB de forma assíncrona (artigo 07 §4.2).

  Quando a aplicação usa persistência no pipeline (artigo 14), o
  TelemetryPipeline.handle_batch já persiste os lotes e este módulo não é
  iniciado. Este GenServer permanece disponível para cenários em que se queira
  um consumidor alternativo do tópico smart_brewery:fatos (ex.: outro store).
  Subscreve ao tópico e, ao receber {:batch, updates}, faz insert_all no Repo.
  """
  use GenServer

  require Logger

  @topic "smart_brewery:fatos"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(SimulacoesVisuais.PubSub, @topic)
    {:ok, %{}}
  end

  @impl true
  def handle_info({:batch, updates}, state) when is_list(updates) do
    Task.start(fn ->
      try do
        rows = SimulacoesVisuais.TelemetryEvent.changesets_from_batch(updates)

        if rows != [] do
          SimulacoesVisuais.Repo.insert_all(SimulacoesVisuais.TelemetryEvent, rows)
        end
      rescue
        e ->
          Logger.warning("[TelemetryWriter] insert_all failed: #{inspect(e)}")
      end
    end)

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
