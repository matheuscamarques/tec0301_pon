defmodule Tec0301Pon.Adapters.PortaoIO do
  @moduledoc """
  Adaptador de saída para portão eletrônico (simulação com IO).
  """
  @behaviour Tec0301Pon.Ports.AtuadorPortao

  @impl true
  def abrir do
    IO.puts("🚪 [Portão] Acionando motor: ABRINDO.")
    :ok
  end

  @impl true
  def fechar do
    IO.puts("🚪 [Portão] Acionando motor: FECHANDO.")
    :ok
  end
end
