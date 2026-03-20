defmodule SimulacoesVisuais.SmartBrewery.CaseContext do
  @moduledoc """
  Identificador de caso (`case_id`) para process mining em `rule_events` (artigo 15).

  Um novo UUID é emitido ao montar a página Smart Brewery ou ao iniciar o loop Monte Carlo,
  agrupando disparos de regras na mesma sessão operacional.
  """
  use Agent

  @doc false
  def start_link(_opts) do
    Agent.start_link(fn -> Ecto.UUID.generate() end, name: __MODULE__)
  end

  @doc "Gera um novo `case_id` e passa a usá-lo para inserts subsequentes em `rule_events`."
  def new_session do
    id = Ecto.UUID.generate()
    Agent.update(__MODULE__, fn _ -> id end)
    id
  end

  @doc false
  def current_case_id do
    Agent.get(__MODULE__, & &1)
  end
end
