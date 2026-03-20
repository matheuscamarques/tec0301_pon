defmodule SimulacoesVisuais.SmartBrewery.RuleEventWriter do
  @moduledoc """
  Persiste eventos de regras PON disparadas no banco para dashboards Power BI (artigo 14).
  Subscreve a `smart_brewery:regras` e grava em `rule_events`.

  Fila limitada + inserts em lote (evita mailbox ilimitada quando regras disparam em rajada).
  """
  use GenServer

  require Logger

  @topic "smart_brewery:regras"
  @default_max_pending 2_000
  @default_batch_size 150

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(SimulacoesVisuais.PubSub, @topic)

    max_pending =
      Application.get_env(
        :simulacoes_visuais,
        :rule_event_writer_max_pending,
        @default_max_pending
      )
      |> max(100)

    batch_size =
      Application.get_env(:simulacoes_visuais, :rule_event_writer_batch_size, @default_batch_size)
      |> max(20)

    {:ok,
     %{
       pending: [],
       draining: false,
       max_pending: max_pending,
       batch_size: batch_size
     }}
  end

  @impl true
  def handle_info({:regra, regra_id}, state) do
    pending = state.pending ++ [{:regra, regra_id}]

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
    case_id = SimulacoesVisuais.SmartBrewery.CaseContext.current_case_id()

    rows =
      Enum.map(chunk, fn {:regra, regra_id} ->
        %{
          ts: now,
          regra_id: to_string(regra_id),
          case_id: case_id,
          inserted_at: now,
          updated_at: now
        }
      end)

    try do
      SimulacoesVisuais.Repo.insert_all("rule_events", rows, placeholders: false)
    rescue
      e -> Logger.warning("[RuleEventWriter] insert_all failed: #{inspect(e)}")
    end
  end
end
