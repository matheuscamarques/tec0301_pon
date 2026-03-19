defmodule SimulacoesVisuais.SmartBrewery.OeeSnapshotWriter do
  @moduledoc """
  Persiste snapshots de OEE no banco para dashboards Power BI (artigo 14).
  Subscreve a `smart_brewery:oee` e grava cada {:oee_update, pct, components} em oee_snapshots.
  Só é iniciado quando :tsdb_enabled.
  """
  use GenServer

  require Logger

  @topic "smart_brewery:oee"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(SimulacoesVisuais.PubSub, @topic)
    {:ok, %{}}
  end

  @impl true
  def handle_info({:oee_update, pct, components}, state) when is_map(components) do
    now = DateTime.utc_now()
    av = to_pct(components[:availability])
    pf = to_pct(components[:performance])
    ql = to_pct(components[:quality])

    row = %{
      ts: now,
      oee_pct: pct,
      availability_pct: av,
      performance_pct: pf,
      quality_pct: ql,
      inserted_at: now,
      updated_at: now
    }

    try do
      SimulacoesVisuais.Repo.insert_all("oee_snapshots", [row],
        placeholders: false
      )
    rescue
      e -> Logger.warning("[OeeSnapshotWriter] insert failed: #{inspect(e)}")
    end

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp to_pct(nil), do: nil
  defp to_pct(x) when is_number(x) and x <= 1.0, do: x * 100
  defp to_pct(x) when is_number(x), do: x
  defp to_pct(_), do: nil
end
