defmodule Tec0301Pon.Ports.AtuadorPortao do
  @moduledoc """
  Porta (Behaviour) para atuador de portão eletrônico (abrir/fechar).
  """
  @callback abrir() :: :ok
  @callback fechar() :: :ok
end
