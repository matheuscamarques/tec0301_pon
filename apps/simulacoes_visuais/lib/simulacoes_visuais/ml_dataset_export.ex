defmodule SimulacoesVisuais.MLDatasetExport do
  @moduledoc """
  Exportação de datasets do TimescaleDB (Smart Brewery) para treino de ML em **CSV**.

  ## Tabelas e SQL de referência

  As consultas abaixo espelham o que a task `mix simulacoes_visuais.export_ml` executa.
  Ajuste janelas (`$1` = `since`) conforme necessário.

  ### Telemetria bruta (séries multivariadas)

      SELECT ts, fact_name, value_float, value_int, value_str, inserted_at, updated_at
      FROM telemetry_events
      WHERE ts >= $1
      ORDER BY ts ASC;

  ### OEE (alvo / regressão)

      SELECT ts, oee_pct, availability_pct, performance_pct, quality_pct, inserted_at, updated_at
      FROM oee_snapshots
      WHERE ts >= $1
      ORDER BY ts ASC;

  ### Anomalias (rótulos fracos / baseline EMA+3σ)

      SELECT ts, fact_name, value, ema, sigma, inserted_at, updated_at
      FROM anomaly_events
      WHERE ts >= $1
      ORDER BY ts ASC;

  ### Disparos de regras (eventos discretos)

      SELECT ts, regra_id, case_id, inserted_at, updated_at
      FROM rule_events
      WHERE ts >= $1
      ORDER BY ts ASC;

  ### Dimensões (metadados)

      SELECT fbe_id, nome, fase_operacional FROM dim_equipamento_fbe ORDER BY fbe_id;
      SELECT fact_name, descricao, unidade FROM dim_variaveis_mapeamento ORDER BY fact_name;

  ### Agregados 1 min (menor volume que a hypertable bruta)

  Equivalente ao que alimenta `fact_telemetria_agregada_1min` (útil para séries já suavizadas):

      SELECT bucket, fact_name, value_float_avg, value_float_min, value_float_max
      FROM telemetry_events_1min
      WHERE bucket >= $1
      ORDER BY bucket ASC, fact_name ASC;

  ### Agregados 1 h e 1 dia (macro / tendências — artigo 16)

  Mesmo esquema de colunas (`bucket`, `fact_name`, agregados); apenas a granularidade temporal muda:

      SELECT bucket, fact_name, value_float_avg, value_float_min, value_float_max
      FROM telemetry_events_1h
      WHERE bucket >= $1
      ORDER BY bucket ASC, fact_name ASC;

      SELECT bucket, fact_name, value_float_avg, value_float_min, value_float_max
      FROM telemetry_events_1day
      WHERE bucket >= $1
      ORDER BY bucket ASC, fact_name ASC;

  ## Formato

  - CSV com cabeçalho, UTF-8.
  - Timestamps em ISO8601.
  - Parquet: use conversão externa (ex.: pandas, Polars) — não há dependência Parquet no app.
  """

  import Ecto.Query

  alias SimulacoesVisuais.{Repo, TelemetryEvent}

  @telemetry_columns ~w(ts fact_name value_float value_int value_str inserted_at updated_at)
  @oee_columns ~w(ts oee_pct availability_pct performance_pct quality_pct inserted_at updated_at)
  @anomaly_columns ~w(ts fact_name value ema sigma inserted_at updated_at)
  @rule_columns ~w(ts regra_id case_id inserted_at updated_at)
  @dim_fbe_columns ~w(fbe_id nome fase_operacional)
  @dim_var_columns ~w(fact_name descricao unidade)
  @cagg_1min_columns ~w(bucket fact_name value_float_avg value_float_min value_float_max)
  @cagg_1h_columns @cagg_1min_columns
  @cagg_1day_columns @cagg_1min_columns

  @doc """
  Exporta CSVs para `out_dir`. Opções:

  - `:since_hours` — janela para tabelas temporais (default 168 = 7 dias).
  - `:include_cagg_1min` — inclui `telemetry_events_1min` (default true).
  - `:include_cagg_1h_1day` — inclui `telemetry_events_1h` e `telemetry_events_1day` (default true).
    Requer migrations com essas CAGGs; desligue se o ambiente não as tiver.
  """
  def export_all(out_dir, opts \\ []) when is_binary(out_dir) do
    since_hours = Keyword.get(opts, :since_hours, 168)
    include_cagg? = Keyword.get(opts, :include_cagg_1min, true)
    include_1h_1day? = Keyword.get(opts, :include_cagg_1h_1day, true)
    since = DateTime.utc_now() |> DateTime.add(-since_hours * 3600, :second)
    File.mkdir_p!(out_dir)

    :ok = export_telemetry_stream(out_dir, since)
    :ok = export_oee(out_dir, since)
    :ok = export_anomalies(out_dir, since)
    :ok = export_rules(out_dir, since)
    :ok = export_dim_fbe(out_dir)
    :ok = export_dim_variables(out_dir)

    if include_cagg? do
      :ok = export_cagg_1min(out_dir, since)
    end

    if include_1h_1day? do
      :ok = export_cagg_1h(out_dir, since)
      :ok = export_cagg_1day(out_dir, since)
    end

    :ok
  end

  defp export_telemetry_stream(out_dir, %DateTime{} = since) do
    path = Path.join(out_dir, "telemetry_events.csv")
    query = from(e in TelemetryEvent, where: e.ts >= ^since, order_by: [asc: e.ts])

    Repo.transaction(
      fn ->
        stream = Repo.stream(query, timeout: :infinity)

        File.open!(path, [:write, :utf8], fn file ->
          IO.write(file, csv_line(@telemetry_columns) <> "\n")

          Enum.each(stream, fn row ->
            line =
              csv_line([
                row.ts,
                row.fact_name,
                row.value_float,
                row.value_int,
                row.value_str,
                row.inserted_at,
                row.updated_at
              ])

            IO.write(file, line <> "\n")
          end)
        end)

        :ok
      end,
      timeout: :infinity
    )
    |> case do
      {:ok, :ok} -> :ok
      {:error, reason} -> raise inspect(reason)
    end
  end

  defp export_oee(out_dir, since) do
    sql = """
    SELECT ts, oee_pct, availability_pct, performance_pct, quality_pct, inserted_at, updated_at
    FROM oee_snapshots
    WHERE ts >= $1
    ORDER BY ts ASC
    """

    export_query_result(Path.join(out_dir, "oee_snapshots.csv"), sql, [since], @oee_columns)
  end

  defp export_anomalies(out_dir, since) do
    sql = """
    SELECT ts, fact_name, value, ema, sigma, inserted_at, updated_at
    FROM anomaly_events
    WHERE ts >= $1
    ORDER BY ts ASC
    """

    export_query_result(Path.join(out_dir, "anomaly_events.csv"), sql, [since], @anomaly_columns)
  end

  defp export_rules(out_dir, since) do
    sql = """
    SELECT ts, regra_id, case_id, inserted_at, updated_at
    FROM rule_events
    WHERE ts >= $1
    ORDER BY ts ASC
    """

    export_query_result(Path.join(out_dir, "rule_events.csv"), sql, [since], @rule_columns)
  end

  defp export_dim_fbe(out_dir) do
    sql = """
    SELECT fbe_id, nome, fase_operacional
    FROM dim_equipamento_fbe
    ORDER BY fbe_id
    """

    export_query_result(Path.join(out_dir, "dim_equipamento_fbe.csv"), sql, [], @dim_fbe_columns)
  end

  defp export_dim_variables(out_dir) do
    sql = """
    SELECT fact_name, descricao, unidade
    FROM dim_variaveis_mapeamento
    ORDER BY fact_name
    """

    export_query_result(
      Path.join(out_dir, "dim_variaveis_mapeamento.csv"),
      sql,
      [],
      @dim_var_columns
    )
  end

  defp export_cagg_1min(out_dir, since) do
    sql = """
    SELECT bucket, fact_name, value_float_avg, value_float_min, value_float_max
    FROM telemetry_events_1min
    WHERE bucket >= $1
    ORDER BY bucket ASC, fact_name ASC
    """

    export_query_result(
      Path.join(out_dir, "telemetry_events_1min.csv"),
      sql,
      [since],
      @cagg_1min_columns
    )
  end

  defp export_cagg_1h(out_dir, since) do
    sql = """
    SELECT bucket, fact_name, value_float_avg, value_float_min, value_float_max
    FROM telemetry_events_1h
    WHERE bucket >= $1
    ORDER BY bucket ASC, fact_name ASC
    """

    export_query_result(
      Path.join(out_dir, "telemetry_events_1h.csv"),
      sql,
      [since],
      @cagg_1h_columns
    )
  end

  defp export_cagg_1day(out_dir, since) do
    sql = """
    SELECT bucket, fact_name, value_float_avg, value_float_min, value_float_max
    FROM telemetry_events_1day
    WHERE bucket >= $1
    ORDER BY bucket ASC, fact_name ASC
    """

    export_query_result(
      Path.join(out_dir, "telemetry_events_1day.csv"),
      sql,
      [since],
      @cagg_1day_columns
    )
  end

  defp export_query_result(path, sql, params, header_columns) do
    case Repo.query(sql, params) do
      {:ok, %{rows: rows}} ->
        File.open!(path, [:write, :utf8], fn file ->
          IO.write(file, csv_line(header_columns) <> "\n")

          Enum.each(rows, fn row ->
            IO.write(file, csv_line(row) <> "\n")
          end)
        end)

        :ok

      {:error, e} ->
        raise "export failed #{path}: #{inspect(e)}"
    end
  end

  @doc false
  def csv_line(values) when is_list(values) do
    values
    |> Enum.map(&csv_cell/1)
    |> Enum.join(",")
  end

  defp csv_cell(nil), do: ""

  defp csv_cell(%DateTime{} = dt),
    do: dt |> DateTime.truncate(:microsecond) |> DateTime.to_iso8601() |> csv_escape()

  defp csv_cell(%NaiveDateTime{} = ndt),
    do: ndt |> NaiveDateTime.to_iso8601() |> csv_escape()

  defp csv_cell(n) when is_integer(n), do: Integer.to_string(n)

  defp csv_cell(n) when is_float(n), do: Float.to_string(n)

  defp csv_cell(b) when is_boolean(b), do: if(b, do: "true", else: "false")

  defp csv_cell(s) when is_binary(s), do: csv_escape(s)

  defp csv_cell(other), do: other |> inspect() |> csv_escape()

  defp csv_escape(s) when is_binary(s) do
    if String.contains?(s, [",", "\"", "\n", "\r"]) do
      "\"" <> String.replace(s, "\"", "\"\"") <> "\""
    else
      s
    end
  end
end
