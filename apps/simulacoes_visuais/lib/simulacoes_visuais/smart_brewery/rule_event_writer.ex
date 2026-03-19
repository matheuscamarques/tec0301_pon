defmodule SimulacoesVisuais.SmartBrewery.RuleEventWriter do
  @moduledoc """
  Persiste eventos de regras PON disparadas no banco para dashboards Power BI (artigo 14).
  Subscreve a `smart_brewery:regras` e grava cada {:regra, regra_id} em rule_events.
  Só é iniciado quando :tsdb_enabled.
  """
  use GenServer

  require Logger

  @topic "smart_brewery:regras"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(SimulacoesVisuais.PubSub, @topic)
    {:ok, %{}}
  end

  @impl true
  def handle_info({:regra, regra_id}, state) do
    now = DateTime.utc_now()
    regra_str = to_string(regra_id)

    row = %{
      ts: now,
      regra_id: regra_str,
      inserted_at: now,
      updated_at: now
    }

    try do
      SimulacoesVisuais.Repo.insert_all("rule_events", [row],
        placeholders: false
      )
    rescue
      e -> Logger.warning("[RuleEventWriter] insert failed: #{inspect(e)}")
    end

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
