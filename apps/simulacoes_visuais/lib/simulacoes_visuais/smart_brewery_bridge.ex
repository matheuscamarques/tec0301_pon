defmodule SimulacoesVisuais.SmartBreweryBridge do
  @moduledoc """
  Worker que inicia a malha PON do Smart Brewery quando a aplicação Phoenix sobe.

  Este módulo garante que os 57 fatos e as 12 regras (artigo 05 e 11) existam no mesmo nó
  onde o LiveView consome o estado via PubSub.
  """

  use GenServer

  require Logger

  @fato_check :fbe_01_motor_rpm

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    # Garante que a aplicação OTP do tec0301_pon está disponível.
    Application.ensure_all_started(:tec0301_pon)

    # Evita duplicar o start dos processos Fato/Regra caso haja reinício do worker.
    if Process.whereis(@fato_check) == nil do
      Logger.info("[SmartBreweryBridge] Iniciando malha PON (57 fatos, 12 regras).")
      Tec0301Pon.Examples.SmartBrewery.start_link()
    else
      Logger.info("[SmartBreweryBridge] Malha PON já iniciada; skip.")
    end

    {:ok, %{}}
  end
end
