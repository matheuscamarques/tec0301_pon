defmodule Tec0301Pon.Adapters.AlarmeIO do
  @moduledoc """
  Adaptador de saída que implementa a Porta Alarme.
  Simula envio de SMS/Push (em produção trocar por API real).
  """
  @behaviour Tec0301Pon.Ports.Alarme

  @impl true
  def disparar(motivo) do
    IO.puts("🚨 [API Externa] Enviando SMS/Push: ALARME CRÍTICO - #{motivo}")
    :ok
  end
end
