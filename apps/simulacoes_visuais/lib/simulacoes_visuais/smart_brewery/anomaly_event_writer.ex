defmodule SimulacoesVisuais.SmartBrewery.AnomalyEventWriter do
  @moduledoc """
  Persiste eventos de anomalia (EMA/3-Sigma) no banco para dashboards Power BI (artigo 14).
  Subscreve a `smart_brewery:anomalias` e grava cada {:anomalia, fact_name, value, ema, sigma} em anomaly_events.
  Só é iniciado quando :tsdb_enabled.
  """
  use GenServer

  require Logger

  @topic "smart_brewery:anomalias"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(SimulacoesVisuais.PubSub, @topic)
    {:ok, %{}}
  end

  @impl true
  def handle_info({:anomalia, fact_name, value, ema, sigma}, state)
      when is_atom(fact_name) and is_number(value) and is_number(ema) and is_number(sigma) do
    now = DateTime.utc_now()

    row = %{
      ts: now,
      fact_name: Atom.to_string(fact_name),
      value: value * 1.0,
      ema: ema * 1.0,
      sigma: sigma * 1.0,
      inserted_at: now,
      updated_at: now
    }

    try do
      SimulacoesVisuais.Repo.insert_all("anomaly_events", [row],
        placeholders: false
      )
    rescue
      e -> Logger.warning("[AnomalyEventWriter] insert failed: #{inspect(e)}")
    end

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
