defmodule SimulacoesVisuais.Repo.Migrations.AddTelemetryCaggs1h1day do
  @moduledoc """
  Artigo 14: CAGGs hierárquicos para dashboards táticos (1 min) e executivos (1 h, 1 dia).
  Permite que o Power BI consulte telemetry_events_1h ou telemetry_events_1day para
  janelas longas sem varrer a hypertable bruta.

  Para DirectQuery estável (evitar união com dados não materializados), pode-se
  alterar qualquer CAGG no PostgreSQL com:
  ALTER MATERIALIZED VIEW <cagg_name> SET (timescaledb.materialized_only = true);
  """
  use Ecto.Migration

  @cagg_1h "telemetry_events_1h"
  @cagg_1day "telemetry_events_1day"
  @hypertable "public.telemetry_events"

  def up do
    execute "SET search_path TO public;"

    execute """
    CREATE MATERIALIZED VIEW #{@cagg_1h}
    WITH (timescaledb.continuous) AS
    SELECT
      time_bucket('1 hour', ts) AS bucket,
      fact_name,
      avg(value_float) AS value_float_avg,
      min(value_float) AS value_float_min,
      max(value_float) AS value_float_max
    FROM #{@hypertable}
    WHERE value_float IS NOT NULL
    GROUP BY bucket, fact_name
    WITH NO DATA;
    """

    execute """
    SELECT add_continuous_aggregate_policy('#{@cagg_1h}',
      start_offset => INTERVAL '7 days',
      end_offset => INTERVAL '1 hour',
      schedule_interval => INTERVAL '1 hour');
    """

    execute """
    CREATE MATERIALIZED VIEW #{@cagg_1day}
    WITH (timescaledb.continuous) AS
    SELECT
      time_bucket('1 day', ts) AS bucket,
      fact_name,
      avg(value_float) AS value_float_avg,
      min(value_float) AS value_float_min,
      max(value_float) AS value_float_max
    FROM #{@hypertable}
    WHERE value_float IS NOT NULL
    GROUP BY bucket, fact_name
    WITH NO DATA;
    """

    execute """
    SELECT add_continuous_aggregate_policy('#{@cagg_1day}',
      start_offset => INTERVAL '30 days',
      end_offset => INTERVAL '1 day',
      schedule_interval => INTERVAL '1 day');
    """
  end

  def down do
    execute "SELECT remove_continuous_aggregate_policy('#{@cagg_1day}', if_exists => true);"
    execute "DROP MATERIALIZED VIEW IF EXISTS #{@cagg_1day};"
    execute "SELECT remove_continuous_aggregate_policy('#{@cagg_1h}', if_exists => true);"
    execute "DROP MATERIALIZED VIEW IF EXISTS #{@cagg_1h};"
  end
end
