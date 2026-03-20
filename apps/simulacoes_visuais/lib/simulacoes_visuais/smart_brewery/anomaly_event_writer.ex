defmodule SimulacoesVisuais.SmartBrewery.AnomalyEventWriter do
  @moduledoc """
  Persiste eventos de anomalia (EMA/3-Sigma) no banco para dashboards Power BI (artigo 14).
  Subscreve a `smart_brewery:anomalias` e grava em `anomaly_events`.

  Fila limitada + inserts em lote (evita mailbox ilimitada em picos de anomalias).
  """
  use GenServer

  require Logger

  @topic "smart_brewery:anomalias"
  @default_max_pending 1_000
  @default_batch_size 80

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(SimulacoesVisuais.PubSub, @topic)

    max_pending =
      Application.get_env(
        :simulacoes_visuais,
        :anomaly_event_writer_max_pending,
        @default_max_pending
      )
      |> max(50)

    batch_size =
      Application.get_env(
        :simulacoes_visuais,
        :anomaly_event_writer_batch_size,
        @default_batch_size
      )
      |> max(10)

    {:ok,
     %{
       pending: [],
       draining: false,
       max_pending: max_pending,
       batch_size: batch_size
     }}
  end

  @impl true
  def handle_info(
        {:anomalia, fact_name, value, ema, sigma},
        state
      )
      when is_atom(fact_name) and is_number(value) and is_number(ema) and is_number(sigma) do
    msg = {:anomalia, fact_name, value, ema, sigma}
    pending = state.pending ++ [msg]

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

  def handle_info(:drain, %{pending: pending, batch_size: batch_size} = state) do
    {chunk, rest} = Enum.split(pending, batch_size)
    insert_chunk(chunk)
    if rest != [], do: Process.send_after(self(), :drain, 0)
    {:noreply, %{state | pending: rest, draining: rest != []}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp insert_chunk([]), do: :ok

  defp insert_chunk(chunk) do
    now = DateTime.utc_now()

    rows =
      Enum.map(chunk, fn {:anomalia, fact_name, value, ema, sigma} ->
        %{
          ts: now,
          fact_name: Atom.to_string(fact_name),
          value: value * 1.0,
          ema: ema * 1.0,
          sigma: sigma * 1.0,
          inserted_at: now,
          updated_at: now
        }
      end)

    try do
      SimulacoesVisuais.Repo.insert_all("anomaly_events", rows, placeholders: false)
    rescue
      e -> Logger.warning("[AnomalyEventWriter] insert_all failed: #{inspect(e)}")
    end
  end
end
