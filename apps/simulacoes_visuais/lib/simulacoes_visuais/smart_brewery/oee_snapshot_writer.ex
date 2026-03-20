defmodule SimulacoesVisuais.SmartBrewery.OeeSnapshotWriter do
  @moduledoc """
  Persiste snapshots de OEE no banco para dashboards Power BI (artigo 14).
  Subscreve a `smart_brewery:oee` e grava em `oee_snapshots`.

  Fila curta + descarte do mais antigo se o DB atrasar (evita crescimento de mailbox).
  """
  use GenServer

  require Logger

  @topic "smart_brewery:oee"
  @default_max_pending 20

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(SimulacoesVisuais.PubSub, @topic)

    max_pending =
      Application.get_env(
        :simulacoes_visuais,
        :oee_snapshot_writer_max_pending,
        @default_max_pending
      )
      |> max(1)

    {:ok, %{pending: [], draining: false, max_pending: max_pending}}
  end

  @impl true
  def handle_info({:oee_update, pct, components}, state) when is_map(components) do
    pending = state.pending ++ [{pct, components}]

    pending =
      if length(pending) > state.max_pending do
        Enum.drop(pending, length(pending) - state.max_pending)
      else
        pending
      end

    if state.draining do
      {:noreply, %{state | pending: pending}}
    else
      Process.send_after(self(), :drain, 0)
      {:noreply, %{state | pending: pending, draining: true}}
    end
  end

  def handle_info(:drain, %{pending: []} = state) do
    {:noreply, %{state | draining: false}}
  end

  def handle_info(:drain, %{pending: [{pct, components} | rest]} = state) do
    insert_one(pct, components)
    if rest != [], do: Process.send_after(self(), :drain, 0)
    {:noreply, %{state | pending: rest, draining: rest != []}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp insert_one(pct, components) do
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
      SimulacoesVisuais.Repo.insert_all("oee_snapshots", [row], placeholders: false)
    rescue
      e -> Logger.warning("[OeeSnapshotWriter] insert failed: #{inspect(e)}")
    end
  end

  defp to_pct(nil), do: nil
  defp to_pct(x) when is_number(x) and x <= 1.0, do: x * 100
  defp to_pct(x) when is_number(x), do: x
  defp to_pct(_), do: nil
end
