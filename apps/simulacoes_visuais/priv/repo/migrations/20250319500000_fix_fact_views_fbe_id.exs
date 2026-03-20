defmodule SimulacoesVisuais.Repo.Migrations.FixFactViewsFbeId do
  @moduledoc """
  Corrige `fbe_id` nas views de fato: `SUBSTRING(..., 1, 7)` gerava `FBE_01_`
  incompatível com `dim_equipamento_fbe` (`FBE_01`). Usa `fbe_XX` a partir dos
  dois primeiros segmentos de `fact_name`.

  Reaplica `GRANT SELECT` para `powerbi_analytics` (views recriadas).
  """
  use Ecto.Migration

  def up do
    execute "SET search_path TO public;"

    execute "DROP VIEW IF EXISTS fact_telemetria_agregada_1day;"
    execute "DROP VIEW IF EXISTS fact_telemetria_agregada_1h;"
    execute "DROP VIEW IF EXISTS fact_telemetria_agregada_1min;"

    execute """
    CREATE VIEW fact_telemetria_agregada_1min AS
    SELECT bucket AS ts_bucket,
      UPPER(SPLIT_PART(fact_name, '_', 1) || '_' || SPLIT_PART(fact_name, '_', 2)) AS fbe_id,
      fact_name,
      value_float_avg AS avg_value,
      value_float_min AS min_value,
      value_float_max AS max_value
    FROM telemetry_events_1min;
    """

    execute """
    CREATE VIEW fact_telemetria_agregada_1h AS
    SELECT bucket AS ts_bucket,
      UPPER(SPLIT_PART(fact_name, '_', 1) || '_' || SPLIT_PART(fact_name, '_', 2)) AS fbe_id,
      fact_name,
      value_float_avg AS avg_value,
      value_float_min AS min_value,
      value_float_max AS max_value
    FROM telemetry_events_1h;
    """

    execute """
    CREATE VIEW fact_telemetria_agregada_1day AS
    SELECT bucket AS ts_bucket,
      UPPER(SPLIT_PART(fact_name, '_', 1) || '_' || SPLIT_PART(fact_name, '_', 2)) AS fbe_id,
      fact_name,
      value_float_avg AS avg_value,
      value_float_min AS min_value,
      value_float_max AS max_value
    FROM telemetry_events_1day;
    """

    execute "GRANT SELECT ON fact_telemetria_agregada_1min TO powerbi_analytics;"
    execute "GRANT SELECT ON fact_telemetria_agregada_1h TO powerbi_analytics;"
    execute "GRANT SELECT ON fact_telemetria_agregada_1day TO powerbi_analytics;"
  end

  def down do
    execute "SET search_path TO public;"

    execute "DROP VIEW IF EXISTS fact_telemetria_agregada_1day;"
    execute "DROP VIEW IF EXISTS fact_telemetria_agregada_1h;"
    execute "DROP VIEW IF EXISTS fact_telemetria_agregada_1min;"

    execute """
    CREATE VIEW fact_telemetria_agregada_1min AS
    SELECT bucket AS ts_bucket,
      UPPER(SUBSTRING(fact_name FROM 1 FOR 7)) AS fbe_id,
      fact_name,
      value_float_avg AS avg_value,
      value_float_min AS min_value,
      value_float_max AS max_value
    FROM telemetry_events_1min;
    """

    execute """
    CREATE VIEW fact_telemetria_agregada_1h AS
    SELECT bucket AS ts_bucket,
      UPPER(SUBSTRING(fact_name FROM 1 FOR 7)) AS fbe_id,
      fact_name,
      value_float_avg AS avg_value,
      value_float_min AS min_value,
      value_float_max AS max_value
    FROM telemetry_events_1h;
    """

    execute """
    CREATE VIEW fact_telemetria_agregada_1day AS
    SELECT bucket AS ts_bucket,
      UPPER(SUBSTRING(fact_name FROM 1 FOR 7)) AS fbe_id,
      fact_name,
      value_float_avg AS avg_value,
      value_float_min AS min_value,
      value_float_max AS max_value
    FROM telemetry_events_1day;
    """

    execute "GRANT SELECT ON fact_telemetria_agregada_1min TO powerbi_analytics;"
    execute "GRANT SELECT ON fact_telemetria_agregada_1h TO powerbi_analytics;"
    execute "GRANT SELECT ON fact_telemetria_agregada_1day TO powerbi_analytics;"
  end
end
