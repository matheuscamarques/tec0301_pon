defmodule SimulacoesVisuais.SmartBreweryRegraNotifier do
  @moduledoc """
  Recebe eventos de regra disparada (send from Tec0301Pon RegraNotifier) e faz broadcast
  no tópico smart_brewery:regras para o painel (artigo 07 §2.2).
  """
  use GenServer

  @topic "smart_brewery:regras"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: :smart_brewery_regra_notifier)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_info({:regra_disparada, regra_id}, state) do
    Phoenix.PubSub.broadcast(SimulacoesVisuais.PubSub, @topic, {:regra, regra_id})
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}
end
