defmodule SimulacoesVisuais.Repo.Migrations.AddRuleEventsCaseIdAndMlPredictions do
  @moduledoc """
  Artigo 15: `case_id` em rule_events para process mining (event log com Case ID).
  Tabela `ml_predictions` para persistir saídas de inferência batch (opcional).
  """
  use Ecto.Migration

  def up do
    alter table(:rule_events) do
      add :case_id, :text
    end

    create index(:rule_events, [:case_id, :ts])

    create table(:ml_predictions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :ts, :utc_datetime_usec, null: false
      add :model_name, :string, null: false
      add :target_name, :string
      add :value_float, :float
      add :metadata, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:ml_predictions, [:ts])
    create index(:ml_predictions, [:model_name, :ts])
  end

  def down do
    drop table(:ml_predictions)

    drop index(:rule_events, [:case_id, :ts])

    alter table(:rule_events) do
      remove :case_id
    end
  end
end
