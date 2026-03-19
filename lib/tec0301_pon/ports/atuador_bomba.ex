defmodule Tec0301Pon.Ports.AtuadorBomba do
  @moduledoc """
  Porta (Behaviour) para atuador de bomba de água.
  Implementações concretas ficam em Adapters (ex.: BombaDeAgua para hardware/IO).
  """
  @callback ligar() :: :ok
  @callback desligar() :: :ok
end
