defmodule SimulacoesVisuais.SmartBreweryFactBroadcaster do
  @moduledoc """
  Faz a ponte entre as notificações do PON (Registry do `tec0301_pon`) e o PubSub
  da aplicação Phoenix (`SimulacoesVisuais.PubSub`), para consumo pela LiveView.

  Prática artigo 06: hot path usa apenas handle_info e GenStage.cast ou Batcher.push
  (assíncronos); nenhum handle_call no fluxo de telemetria.
  """

  use GenServer

  require Logger

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Application.ensure_all_started(:tec0301_pon)

    fatos = Tec0301Pon.Examples.SmartBrewery.fatos_names()

    Enum.each(fatos, fn nome_do_fato ->
      Registry.register(Tec0301Pon.PON.PubSub, nome_do_fato, [])
    end)

    Logger.info(
      "[SmartBreweryFactBroadcaster] Inscrito em #{length(fatos)} fatos via Tec0301Pon.PON.PubSub."
    )

    {:ok, %{fatos: fatos}}
  end

  @impl true
  def handle_info({:notificacao, nome_do_fato, novo_valor}, state) do
    producer_pid =
      try do
        names = Broadway.producer_names(SimulacoesVisuais.SmartBrewery.TelemetryPipeline)

        case names do
          [first_name | _] -> Process.whereis(first_name)
          [] -> nil
        end
      rescue
        _ -> nil
      end

    if producer_pid do
      GenStage.cast(producer_pid, {:event, nome_do_fato, novo_valor})
    else
      SimulacoesVisuais.SmartBreweryTelemetryBatcher.push(nome_do_fato, novo_valor)
    end

    # LiveView recebe apenas lotes via LiveViewEventBatcher (janela de eventos); reduz sobrecarga.
    SimulacoesVisuais.LiveViewEventBatcher.push(nome_do_fato, novo_valor)

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
