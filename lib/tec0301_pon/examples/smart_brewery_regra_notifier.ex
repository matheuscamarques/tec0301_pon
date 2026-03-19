defmodule Tec0301Pon.Examples.SmartBrewery.RegraNotifier do
  @moduledoc """
  Envia evento de regra disparada para o processo registrado :smart_brewery_regra_notifier
  (iniciado pela app simulacoes_visuais). Permite separar fatos de ações PON no painel (artigo 07 §2.2).
  """
  @doc "Notifica que a regra foi disparada. Só envia se o processo estiver registrado."
  def notify(regra_id) when is_atom(regra_id) do
    case Process.whereis(:smart_brewery_regra_notifier) do
      nil -> :ok
      pid -> send(pid, {:regra_disparada, regra_id})
    end
  end
end
