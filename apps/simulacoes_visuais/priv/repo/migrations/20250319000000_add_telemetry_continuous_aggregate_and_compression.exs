defmodule SimulacoesVisuais.Repo.Migrations.AddTelemetryContinuousAggregateAndCompression do
  @moduledoc """
  Artigo 07 itens faltantes: Continuous Aggregates (rollup 1 min) e política de
  compressão no TimescaleDB para telemetry_events.
  """
  use Ecto.Migration

  @cagg_name "telemetry_events_1min"
  @hypertable "public.telemetry_events"

  def up do
    execute "SET search_path TO public;"
    # Garante que a tabela seja hypertable (ex.: se a primeira migration não converteu ou a tabela já tinha dados).
    execute "SELECT create_hypertable('public.telemetry_events', 'ts', if_not_exists => true, migrate_data => true);"

    # Continuous aggregate: rollup por 1 minuto (avg, min, max por fact_name).
    # FROM deve referenciar diretamente a hypertable; sem subquery/CTE.
    execute """
    CREATE MATERIALIZED VIEW #{@cagg_name}
    WITH (timescaledb.continuous) AS
    SELECT
      time_bucket('1 minute', ts) AS bucket,
      fact_name,
      avg(value_float) AS value_float_avg,
      min(value_float) AS value_float_min,
      max(value_float) AS value_float_max
    FROM telemetry_events
    WHERE value_float IS NOT NULL
    GROUP BY bucket, fact_name
    WITH NO DATA;
    """

    execute """
    SELECT add_continuous_aggregate_policy('#{@cagg_name}',
      start_offset => INTERVAL '2 hours',
      end_offset => INTERVAL '1 minute',
      schedule_interval => INTERVAL '5 minutes');
    """

    execute "ALTER TABLE #{@hypertable} SET (timescaledb.compress, timescaledb.compress_segmentby = 'fact_name');"
    execute "SELECT add_compression_policy('#{@hypertable}', INTERVAL '1 day');"
  end

  def down do
    execute "SELECT remove_compression_policy('#{@hypertable}', if_exists => true);"
    execute "ALTER TABLE #{@hypertable} SET (timescaledb.compress = false);"
    execute "SELECT remove_continuous_aggregate_policy('#{@cagg_name}', if_exists => true);"
    execute "DROP MATERIALIZED VIEW IF EXISTS #{@cagg_name};"
  end
end
