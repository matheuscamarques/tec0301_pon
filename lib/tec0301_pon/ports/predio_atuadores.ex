defmodule Tec0301Pon.Ports.PredioAtuadores do
  @moduledoc """
  Porta (Behaviour) para atuadores do prédio inteligente: iluminação, HVAC, porta de segurança.
  """
  @callback ligar_luz() :: :ok
  @callback desligar_luz() :: :ok
  @callback ligar_ar() :: :ok
  @callback ventilar() :: :ok
  @callback trancar_porta() :: :ok
end
