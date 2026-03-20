defmodule SimulacoesVisuais.SmartBrewery.PowerBIPushSink do
  @moduledoc """
  Enfileira linhas já persistidas em `telemetry_events` e envia ao [Power BI Push REST API](https://learn.microsoft.com/en-us/rest/api/power-bi/push-datasets)
  com throttle entre pedidos.

  Desativado por default (`:power_bi_push` → `enabled: false`). Ver `docs/power-bi-realtime.md` na raiz do repositório.
  """
  use GenServer

  require Logger

  @api_base "https://api.powerbi.com/v1.0/myorg"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Enfileira um lote de maps no formato retornado por `TelemetryEvent.changesets_from_batch/2`.
  Sem efeito quando push está desligado ou mal configurado.
  """
  def cast_rows(rows) when is_list(rows) do
    GenServer.cast(__MODULE__, {:rows, rows})
  end

  @doc false
  def encode_rows_for_push(rows) when is_list(rows) do
    opts = Application.get_env(:simulacoes_visuais, :power_bi_push, [])
    Enum.map(rows, &encode_row(&1, opts))
  end

  defp encode_row(
         %{
           ts: ts,
           fact_name: fact_name,
           value_float: vf,
           value_int: vi,
           value_str: vs
         },
         opts
       ) do
    fact_str = to_string(fact_name)

    base = %{
      "ts" => datetime_to_iso8601(ts),
      "fact_name" => fact_str,
      "value_float" => vf,
      "value_int" => vi,
      "value_str" => vs
    }

    if Keyword.get(opts, :include_labels, true) do
      desc =
        SimulacoesVisuais.SmartBrewery.FatoDescriptions.descricao_bin(fact_str)

      Map.put(base, "descricao", desc)
    else
      base
    end
  end

  defp encode_row(_, _opts), do: %{}

  defp datetime_to_iso8601(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp datetime_to_iso8601(other), do: inspect(other)

  @impl true
  def init(_opts) do
    {:ok, %{buffer: [], timer_ref: nil}}
  end

  @impl true
  def handle_cast({:rows, rows}, state) do
    opts = push_opts()

    if push_active?(opts) do
      encoded =
        rows
        |> encode_rows_for_push()
        |> Enum.reject(&(&1 == %{}))

      max_buf = Keyword.fetch!(opts, :max_buffer_rows)
      buffer = state.buffer ++ encoded
      buffer = if length(buffer) > max_buf, do: Enum.take(buffer, -max_buf), else: buffer

      timer_ref =
        if state.timer_ref == nil do
          Process.send_after(self(), :flush_due, Keyword.fetch!(opts, :min_interval_ms))
        else
          state.timer_ref
        end

      {:noreply, %{state | buffer: buffer, timer_ref: timer_ref}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:flush_due, state) do
    opts = push_opts()
    state = %{state | timer_ref: nil}

    if not push_active?(opts) or state.buffer == [] do
      {:noreply, state}
    else
      max_rows = Keyword.fetch!(opts, :max_rows_per_push)
      {to_send, rest} = Enum.split(state.buffer, max_rows)

      if to_send != [] do
        post_rows(to_send, opts)
      end

      timer_ref =
        if rest != [] do
          Process.send_after(self(), :flush_due, Keyword.fetch!(opts, :min_interval_ms))
        else
          nil
        end

      {:noreply, %{state | buffer: rest, timer_ref: timer_ref}}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp push_opts do
    Application.get_env(:simulacoes_visuais, :power_bi_push, [])
  end

  defp push_active?(opts) when is_list(opts) do
    Keyword.get(opts, :enabled, false) == true and
      match?({:ok, _, _, _}, validate_ids(opts))
  end

  defp validate_ids(opts) do
    group = Keyword.get(opts, :group_id)
    dataset = Keyword.get(opts, :dataset_id)
    token = Keyword.get(opts, :access_token)
    table = Keyword.get(opts, :table_name) || "Telemetry"

    if is_binary(group) and group != "" and is_binary(dataset) and dataset != "" and
         is_binary(token) and token != "" and is_binary(table) and table != "" do
      {:ok, group, dataset, table}
    else
      :error
    end
  end

  defp post_rows(rows, opts) do
    {:ok, group_id, dataset_id, table_name} = validate_ids(opts)
    token = Keyword.fetch!(opts, :access_token)

    table_enc = URI.encode(table_name, &URI.char_unreserved?/1)

    url =
      "#{@api_base}/groups/#{URI.encode(group_id, &URI.char_unreserved?/1)}/datasets/#{URI.encode(dataset_id, &URI.char_unreserved?/1)}/tables/#{table_enc}/rows"

    case Req.post(url,
           json: %{rows: rows},
           headers: [{"Authorization", "Bearer #{token}"}]
         ) do
      {:ok, %{status: s}} when s in 200..299 ->
        :ok

      {:ok, %{status: s, body: body}} ->
        Logger.warning(
          "[PowerBIPushSink] push failed status=#{s} body=#{inspect(body, limit: 200)}"
        )

      {:error, reason} ->
        Logger.warning("[PowerBIPushSink] push error #{inspect(reason)}")
    end
  end
end
