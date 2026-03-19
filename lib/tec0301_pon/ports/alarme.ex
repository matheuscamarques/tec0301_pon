defmodule Tec0301Pon.Ports.Alarme do
  @moduledoc """
  Porta (Behaviour) para disparo de alarme (SMS, Push, etc.).
  Implementações concretas ficam em Adapters (ex.: AlarmeIO para simulação/API).
  """
  @callback disparar(motivo :: String.t()) :: :ok
end
