defmodule SimulacoesVisuais.Repo.Migrations.AddOeeAnomalyRuleEventsTables do
  @moduledoc """
  Artigo 14: Tabelas para persistência histórica de OEE, anomalias (EMA/3-Sigma) e
  regras disparadas, para consumo em dashboards Power BI.
  """
  use Ecto.Migration

  def up do
    create table(:oee_snapshots, primary_key: false) do
      add :ts, :utc_datetime_usec, null: false
      add :oee_pct, :float
      add :availability_pct, :float
      add :performance_pct, :float
      add :quality_pct, :float

      timestamps(type: :utc_datetime_usec)
    end

    create index(:oee_snapshots, [:ts])

    create table(:anomaly_events, primary_key: false) do
      add :ts, :utc_datetime_usec, null: false
      add :fact_name, :string, null: false
      add :value, :float, null: false
      add :ema, :float, null: false
      add :sigma, :float, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:anomaly_events, [:ts])
    create index(:anomaly_events, [:fact_name, :ts])

    create table(:rule_events, primary_key: false) do
      add :ts, :utc_datetime_usec, null: false
      add :regra_id, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:rule_events, [:ts])
    create index(:rule_events, [:regra_id, :ts])
  end

  def down do
    drop table(:rule_events)
    drop table(:anomaly_events)
    drop table(:oee_snapshots)
  end
end
