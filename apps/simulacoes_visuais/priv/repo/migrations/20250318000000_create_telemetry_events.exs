defmodule SimulacoesVisuais.Repo.Migrations.CreateTelemetryEvents do
  use Ecto.Migration

  def change do
    # Artigo 07 §4.2: TSDB com TimescaleDB. Requer extensão instalada (ex.: Docker image timescale/timescaledb).
    execute "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;", ""

    create table(:telemetry_events, primary_key: false) do
      add :ts, :utc_datetime_usec, null: false
      add :fact_name, :string, null: false
      add :value_float, :float
      add :value_int, :integer
      add :value_str, :string

      timestamps(type: :utc_datetime_usec)
    end

    create index(:telemetry_events, [:fact_name, :ts])
    create index(:telemetry_events, [:ts])

    # Hypertable por ts para particionamento temporal (artigo 07 §4.2).
    execute "SELECT create_hypertable('telemetry_events', 'ts', if_not_exists => true);", ""

    # Política de retenção: dados brutos por 7 dias (plano §4.2). TimescaleDB 2.x.
    execute "SELECT add_retention_policy('telemetry_events', INTERVAL '7 days');",
            "SELECT remove_retention_policy('telemetry_events');"
  end
end
