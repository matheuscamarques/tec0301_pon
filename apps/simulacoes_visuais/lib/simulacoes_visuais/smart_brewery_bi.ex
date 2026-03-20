defmodule SimulacoesVisuais.SmartBreweryBI do
  @moduledoc """
  Contexto de BI nativo para Smart Brewery.

  Centraliza consultas de OEE, séries temporais, CEP, correlações e eventos.

  Tendência de telemetria, CEP, correlação e sinótico leem diretamente a hypertable
  `telemetry_events` com `time_bucket` (TimescaleDB), evitando atraso das continuous
  aggregates usadas pelas views `fact_telemetria_agregada_*` (úteis a Power BI / relatórios).
  """

  alias SimulacoesVisuais.Repo

  require Logger

  @valid_windows ~w(6h 24h 7d 30d)
  @valid_granularity ~w(1min 1h 1day)

  def default_filters do
    %{
      "window" => "24h",
      "granularity" => "1h",
      "fbe_id" => "all",
      "fact_name" => "all"
    }
  end

  def normalize_filters(params) when is_map(params) do
    defaults = default_filters()

    window = if params["window"] in @valid_windows, do: params["window"], else: defaults["window"]

    granularity =
      if params["granularity"] in @valid_granularity,
        do: params["granularity"],
        else: defaults["granularity"]

    %{
      "window" => window,
      "granularity" => granularity,
      "fbe_id" => normalize_id(params["fbe_id"], "all"),
      "fact_name" => normalize_id(params["fact_name"], "all")
    }
  end

  def normalize_filters(_), do: default_filters()

  def options do
    %{
      fbe: list_fbe_options(),
      facts: list_fact_options()
    }
  end

  def dashboard_data(filters) do
    filters = normalize_filters(filters)
    hours = window_to_hours(filters["window"])

    %{
      oee_cards: oee_cards(hours),
      oee_trend: oee_trend(hours, filters["granularity"]),
      telemetry_trend: telemetry_trend(filters, hours),
      cep_chart: cep_chart(filters, hours),
      correlation_points: correlation_points(filters, hours),
      synoptic_status: synoptic_status(hours),
      anomaly_pareto: anomaly_pareto(hours),
      rule_top: rule_top(hours),
      totals: totals(hours)
    }
  end

  @doc """
  Executa cada consulta usada pelo dashboard BI (mesmas tabelas/funções que `dashboard_data/1`).
  Retorna lista de `{nome, :ok, num_rows}` ou `{nome, {:error, term()}}` — útil com `mix verify.bi`.
  """
  def run_query_diagnostics do
    filters = default_filters()
    hours = window_to_hours(filters["window"])
    interval = bucket_interval_sql(filters["granularity"])
    like = fbe_like_pattern(filters["fbe_id"])
    bucket_expr = bucket_expr_for(filters["granularity"])

    telemetry_sql = """
    SELECT time_bucket('#{interval}'::interval, ts) AS ts_bucket, avg(value_float) AS avg_value
    FROM telemetry_events
    WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour')
      AND value_float IS NOT NULL
      AND ($2::text = 'all' OR fact_name LIKE $3::text)
      AND ($4::text = 'all' OR fact_name = $4::text)
    GROUP BY ts_bucket
    ORDER BY ts_bucket ASC
    LIMIT 5
    """

    correlation_sql = """
    WITH per_bucket AS (
      SELECT
        time_bucket('#{interval}'::interval, ts) AS ts_bucket,
        fact_name,
        avg(value_float) AS v
      FROM telemetry_events
      WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour')
        AND value_float IS NOT NULL
        AND ($2::text = 'all' OR fact_name LIKE $3::text)
        AND fact_name IN (
          'fbe_03_diff_pressure', 'fbe_03_wort_clarity', 'fbe_03_pump_speed',
          'fbe_06_gravity_brix', 'fbe_06_co2_exhaust_flow', 'fbe_06_ph'
        )
      GROUP BY ts_bucket, fact_name
    ),
    pivot AS (
      SELECT
        ts_bucket,
        MAX(CASE WHEN fact_name = 'fbe_03_diff_pressure' THEN v END) AS pressure,
        MAX(CASE WHEN fact_name = 'fbe_03_wort_clarity' THEN v END) AS clarity,
        MAX(CASE WHEN fact_name = 'fbe_03_pump_speed' THEN v END) AS pump,
        MAX(CASE WHEN fact_name = 'fbe_06_gravity_brix' THEN v END) AS brix,
        MAX(CASE WHEN fact_name = 'fbe_06_co2_exhaust_flow' THEN v END) AS co2,
        MAX(CASE WHEN fact_name = 'fbe_06_ph' THEN v END) AS ph
      FROM per_bucket
      GROUP BY ts_bucket
    )
    SELECT ts_bucket, pressure, clarity, pump, brix, co2, ph
    FROM pivot
    ORDER BY ts_bucket ASC
    LIMIT 5
    """

    synoptic_sql = """
    SELECT
      UPPER(SPLIT_PART(fact_name, '_', 1) || '_' || SPLIT_PART(fact_name, '_', 2)) AS fbe_id,
      AVG(value_float) AS avg_v,
      MAX(value_float) AS max_v
    FROM telemetry_events
    WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour')
      AND value_float IS NOT NULL
    GROUP BY UPPER(SPLIT_PART(fact_name, '_', 1) || '_' || SPLIT_PART(fact_name, '_', 2))
    ORDER BY fbe_id
    LIMIT 5
    """

    oee_trend_sql = """
    SELECT #{bucket_expr} AS bucket, AVG(oee_pct), AVG(availability_pct), AVG(performance_pct), AVG(quality_pct)
    FROM oee_snapshots
    WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour')
    GROUP BY bucket
    ORDER BY bucket ASC
    LIMIT 5
    """

    [
      diag("timescaledb.time_bucket", "SELECT time_bucket('1 hour'::interval, NOW())", []),
      diag(
        "dim_equipamento_fbe",
        "SELECT fbe_id, nome FROM dim_equipamento_fbe ORDER BY fbe_id LIMIT 1",
        []
      ),
      diag(
        "dim_variaveis_mapeamento",
        "SELECT fact_name, descricao FROM dim_variaveis_mapeamento ORDER BY fact_name LIMIT 1",
        []
      ),
      diag(
        "oee_snapshots.latest",
        "SELECT oee_pct, availability_pct, performance_pct, quality_pct, ts FROM oee_snapshots ORDER BY ts DESC LIMIT 1",
        []
      ),
      diag(
        "oee_snapshots.window_avg",
        "SELECT AVG(oee_pct), AVG(availability_pct), AVG(performance_pct), AVG(quality_pct) FROM oee_snapshots WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour')",
        [hours]
      ),
      diag("oee_snapshots.trend_buckets", oee_trend_sql, [hours]),
      diag(
        "telemetry_events.trend",
        telemetry_sql,
        [hours, filters["fbe_id"], like, filters["fact_name"]]
      ),
      diag("telemetry_events.correlation_pivot", correlation_sql, [hours, filters["fbe_id"], like]),
      diag("telemetry_events.synoptic", synoptic_sql, [hours]),
      diag(
        "anomaly_events.pareto",
        "SELECT fact_name, COUNT(*)::bigint AS total FROM anomaly_events WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour') GROUP BY fact_name ORDER BY total DESC LIMIT 3",
        [hours]
      ),
      diag(
        "rule_events.top",
        "SELECT regra_id, COUNT(*)::bigint AS total FROM rule_events WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour') GROUP BY regra_id ORDER BY total DESC LIMIT 3",
        [hours]
      ),
      diag(
        "totals.subselects",
        """
        SELECT
          (SELECT COUNT(*)::bigint FROM anomaly_events WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour')) AS anomalies,
          (SELECT COUNT(*)::bigint FROM rule_events WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour')) AS rules
        """,
        [hours]
      )
    ]
  end

  defp diag(label, sql, params) do
    case Repo.query(sql, params) do
      {:ok, res} -> {label, :ok, res.num_rows}
      {:error, e} -> {label, {:error, e}}
    end
  end

  defp list_fbe_options do
    sql = "SELECT fbe_id, nome FROM dim_equipamento_fbe ORDER BY fbe_id"

    case safe_query(sql, []) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, nome] -> {"#{id} · #{nome}", id} end)

      _ ->
        []
    end
  end

  defp list_fact_options do
    sql = """
    SELECT fact_name, descricao, COALESCE(unidade, '')
    FROM dim_variaveis_mapeamento
    ORDER BY fact_name
    """

    case safe_query(sql, []) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [fact, desc, unit] ->
          label = if unit == "", do: "#{fact} · #{desc}", else: "#{fact} · #{desc} (#{unit})"
          {label, fact}
        end)

      _ ->
        []
    end
  end

  defp oee_cards(hours) do
    latest_sql = """
    SELECT oee_pct, availability_pct, performance_pct, quality_pct, ts
    FROM oee_snapshots
    ORDER BY ts DESC
    LIMIT 1
    """

    avg_sql = """
    SELECT AVG(oee_pct), AVG(availability_pct), AVG(performance_pct), AVG(quality_pct)
    FROM oee_snapshots
    WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour')
    """

    latest =
      case safe_query(latest_sql, []) do
        {:ok, %{rows: [[o, a, p, q, ts]]}} ->
          %{oee: o, availability: a, performance: p, quality: q, ts: ts}

        _ ->
          %{oee: nil, availability: nil, performance: nil, quality: nil, ts: nil}
      end

    avg =
      case safe_query(avg_sql, [hours]) do
        {:ok, %{rows: [[o, a, p, q]]}} ->
          %{oee: o, availability: a, performance: p, quality: q}

        _ ->
          %{oee: nil, availability: nil, performance: nil, quality: nil}
      end

    %{latest: latest, average_window: avg}
  end

  defp oee_trend(hours, granularity) do
    bucket_expr = bucket_expr_for(granularity)

    sql = """
    SELECT #{bucket_expr} AS bucket, AVG(oee_pct), AVG(availability_pct), AVG(performance_pct), AVG(quality_pct)
    FROM oee_snapshots
    WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour')
    GROUP BY bucket
    ORDER BY bucket ASC
    LIMIT 400
    """

    case safe_query(sql, [hours]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [ts, oee, a, p, q] ->
          %{ts: ts, oee: oee, availability: a, performance: p, quality: q}
        end)

      _ ->
        []
    end
  end

  defp telemetry_trend(filters, hours) do
    interval = bucket_interval_sql(filters["granularity"])
    like = fbe_like_pattern(filters["fbe_id"])

    sql = """
    SELECT time_bucket('#{interval}'::interval, ts) AS ts_bucket, avg(value_float) AS avg_value
    FROM telemetry_events
    WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour')
      AND value_float IS NOT NULL
      AND ($2::text = 'all' OR fact_name LIKE $3::text)
      AND ($4::text = 'all' OR fact_name = $4::text)
    GROUP BY ts_bucket
    ORDER BY ts_bucket ASC
    LIMIT 800
    """

    case safe_query(sql, [hours, filters["fbe_id"], like, filters["fact_name"]]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [ts, value] -> %{ts: ts, value: value} end)

      _ ->
        []
    end
  end

  defp cep_chart(filters, hours) do
    interval = bucket_interval_sql(filters["granularity"])
    like = fbe_like_pattern(filters["fbe_id"])

    sql = """
    SELECT ts_bucket, avg_value
    FROM (
      SELECT time_bucket('#{interval}'::interval, ts) AS ts_bucket, avg(value_float) AS avg_value
      FROM telemetry_events
      WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour')
        AND value_float IS NOT NULL
        AND ($2::text = 'all' OR fact_name LIKE $3::text)
        AND ($4::text = 'all' OR fact_name = $4::text)
      GROUP BY ts_bucket
    ) AS buckets
    WHERE avg_value IS NOT NULL
    ORDER BY ts_bucket ASC
    LIMIT 600
    """

    points =
      case safe_query(sql, [hours, filters["fbe_id"], like, filters["fact_name"]]) do
        {:ok, %{rows: rows}} ->
          Enum.map(rows, fn [ts, value] -> %{ts: ts, value: value} end)

        _ ->
          []
      end

    values =
      points
      |> Enum.map(& &1.value)
      |> Enum.filter(&is_number/1)

    cl = avg(values)
    amr = moving_range_avg(values)

    %{
      points: points,
      cl: cl,
      amr: amr,
      ucl: if(is_number(cl) and is_number(amr), do: cl + 2.66 * amr, else: nil),
      lcl: if(is_number(cl) and is_number(amr), do: cl - 2.66 * amr, else: nil)
    }
  end

  defp correlation_points(filters, hours) do
    interval = bucket_interval_sql(filters["granularity"])
    like = fbe_like_pattern(filters["fbe_id"])

    sql = """
    WITH per_bucket AS (
      SELECT
        time_bucket('#{interval}'::interval, ts) AS ts_bucket,
        fact_name,
        avg(value_float) AS v
      FROM telemetry_events
      WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour')
        AND value_float IS NOT NULL
        AND ($2::text = 'all' OR fact_name LIKE $3::text)
        AND fact_name IN (
          'fbe_03_diff_pressure', 'fbe_03_wort_clarity', 'fbe_03_pump_speed',
          'fbe_06_gravity_brix', 'fbe_06_co2_exhaust_flow', 'fbe_06_ph'
        )
      GROUP BY ts_bucket, fact_name
    ),
    pivot AS (
      SELECT
        ts_bucket,
        MAX(CASE WHEN fact_name = 'fbe_03_diff_pressure' THEN v END) AS pressure,
        MAX(CASE WHEN fact_name = 'fbe_03_wort_clarity' THEN v END) AS clarity,
        MAX(CASE WHEN fact_name = 'fbe_03_pump_speed' THEN v END) AS pump,
        MAX(CASE WHEN fact_name = 'fbe_06_gravity_brix' THEN v END) AS brix,
        MAX(CASE WHEN fact_name = 'fbe_06_co2_exhaust_flow' THEN v END) AS co2,
        MAX(CASE WHEN fact_name = 'fbe_06_ph' THEN v END) AS ph
      FROM per_bucket
      GROUP BY ts_bucket
    )
    SELECT ts_bucket, pressure, clarity, pump, brix, co2, ph
    FROM pivot
    ORDER BY ts_bucket ASC
    LIMIT 400
    """

    case safe_query(sql, [hours, filters["fbe_id"], like]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [ts, pressure, clarity, pump, brix, co2, ph] ->
          %{
            ts: ts,
            pressure: pressure,
            clarity: clarity,
            pump: pump,
            brix: brix,
            co2: co2,
            ph: ph
          }
        end)

      _ ->
        []
    end
  end

  defp synoptic_status(hours) do
    sql = """
    SELECT
      UPPER(SPLIT_PART(fact_name, '_', 1) || '_' || SPLIT_PART(fact_name, '_', 2)) AS fbe_id,
      AVG(value_float) AS avg_v,
      MAX(value_float) AS max_v
    FROM telemetry_events
    WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour')
      AND value_float IS NOT NULL
    GROUP BY UPPER(SPLIT_PART(fact_name, '_', 1) || '_' || SPLIT_PART(fact_name, '_', 2))
    ORDER BY fbe_id
    """

    case safe_query(sql, [hours]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [fbe, avg_v, max_v] ->
          status =
            cond do
              is_number(max_v) and max_v > 150 -> :warning
              is_number(avg_v) -> :ok
              true -> :unknown
            end

          %{fbe_id: fbe, avg_value: avg_v, max_value: max_v, status: status}
        end)

      _ ->
        []
    end
  end

  defp anomaly_pareto(hours) do
    sql = """
    SELECT fact_name, COUNT(*)::bigint AS total
    FROM anomaly_events
    WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour')
    GROUP BY fact_name
    ORDER BY total DESC
    LIMIT 8
    """

    case safe_query(sql, [hours]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [fact_name, total] -> %{label: fact_name, total: total} end)

      _ ->
        []
    end
  end

  defp rule_top(hours) do
    sql = """
    SELECT regra_id, COUNT(*)::bigint AS total
    FROM rule_events
    WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour')
    GROUP BY regra_id
    ORDER BY total DESC
    LIMIT 8
    """

    case safe_query(sql, [hours]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [rule, total] -> %{label: "R_#{rule}", total: total} end)

      _ ->
        []
    end
  end

  defp totals(hours) do
    sql = """
    SELECT
      (SELECT COUNT(*)::bigint FROM anomaly_events WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour')) AS anomalies,
      (SELECT COUNT(*)::bigint FROM rule_events WHERE ts >= NOW() - ($1::int * INTERVAL '1 hour')) AS rules
    """

    case safe_query(sql, [hours]) do
      {:ok, %{rows: [[anomalies, rules]]}} -> %{anomalies: anomalies, rules: rules}
      _ -> %{anomalies: 0, rules: 0}
    end
  end

  defp safe_query(sql, params) do
    case Repo.query(sql, params) do
      {:ok, _} = ok ->
        ok

      {:error, e} = err ->
        Logger.warning(
          "[SmartBreweryBI] SQL error: #{Exception.message(e)} | #{String.slice(String.trim(sql), 0, 160)}"
        )

        err
    end
  rescue
    e ->
      Logger.warning("[SmartBreweryBI] query raised: #{Exception.message(e)}")
      {:error, :query_failed}
  end

  defp avg([]), do: nil
  defp avg(values), do: Enum.sum(values) / length(values)

  defp moving_range_avg(values) do
    values
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] -> abs(b - a) end)
    |> avg()
  end

  defp window_to_hours("6h"), do: 6
  defp window_to_hours("24h"), do: 24
  defp window_to_hours("7d"), do: 24 * 7
  defp window_to_hours("30d"), do: 24 * 30
  defp window_to_hours(_), do: 24

  defp bucket_interval_sql("1min"), do: "1 minute"
  defp bucket_interval_sql("1h"), do: "1 hour"
  defp bucket_interval_sql("1day"), do: "1 day"
  defp bucket_interval_sql(_), do: "1 hour"

  defp fbe_like_pattern("all"), do: "%"

  defp fbe_like_pattern(fbe_id) when is_binary(fbe_id) do
    fbe_id
    |> String.replace("FBE_", "fbe_", global: false)
    |> Kernel.<>("%")
  end

  defp bucket_expr_for("1min"), do: "date_trunc('minute', ts)"
  defp bucket_expr_for("1h"), do: "date_trunc('hour', ts)"
  defp bucket_expr_for("1day"), do: "date_trunc('day', ts)"
  defp bucket_expr_for(_), do: "date_trunc('hour', ts)"

  defp normalize_id(nil, fallback), do: fallback
  defp normalize_id("", fallback), do: fallback
  defp normalize_id(value, _fallback) when is_binary(value), do: value
  defp normalize_id(_value, fallback), do: fallback
end
