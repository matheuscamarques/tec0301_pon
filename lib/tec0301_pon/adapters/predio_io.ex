defmodule Tec0301Pon.Adapters.PredioIO do
  @moduledoc """
  Adaptador de saída para prédio inteligente (iluminação, HVAC, porta) — simulação com IO.
  """
  @behaviour Tec0301Pon.Ports.PredioAtuadores

  @impl true
  def ligar_luz do
    IO.puts("[Prédio] Iluminação: Luz LIGADA.")
    :ok
  end

  @impl true
  def desligar_luz do
    IO.puts("[Prédio] Iluminação: Luz DESLIGADA.")
    :ok
  end

  @impl true
  def ligar_ar do
    IO.puts("[Prédio] HVAC: Ar condicionado LIGADO.")
    :ok
  end

  @impl true
  def ventilar do
    IO.puts("[Prédio] Ventilação: EXAUSTÃO ligada (CO2 alto).")
    :ok
  end

  @impl true
  def trancar_porta do
    IO.puts("[Prédio] Segurança: Porta TRANCADA.")
    :ok
  end
end
