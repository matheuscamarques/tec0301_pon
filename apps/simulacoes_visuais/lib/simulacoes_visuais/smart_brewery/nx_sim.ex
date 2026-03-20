defmodule SimulacoesVisuais.SmartBrewery.NxSim do
  @moduledoc """
  Facade sobre `Fbe03Pure` — sem tensores Nx no tick da simulação (menos CPU/alocação).

  O nome do módulo mantém-se para imports e documentação cruzada (artigo 07).
  """
  defdelegate default_correlation, to: SimulacoesVisuais.SmartBrewery.Fbe03Pure
  defdelegate fbe03_correlated(state), to: SimulacoesVisuais.SmartBrewery.Fbe03Pure
  defdelegate fbe03_correlated(state, correlation), to: SimulacoesVisuais.SmartBrewery.Fbe03Pure
end
