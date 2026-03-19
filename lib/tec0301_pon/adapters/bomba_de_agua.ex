defmodule Tec0301Pon.Adapters.BombaDeAgua do
  @moduledoc """
  Adaptador de saída que implementa a Porta AtuadorBomba.
  Simula acionamento de relé (em produção trocar por driver real).
  """
  @behaviour Tec0301Pon.Ports.AtuadorBomba

  @impl true
  def ligar do
    IO.puts("💧 [Hardware] Acionando relé: Bomba LIGADA.")
    :ok
  end

  @impl true
  def desligar do
    IO.puts("🛑 [Hardware] Cortando relé: Bomba DESLIGADA.")
    :ok
  end
end
