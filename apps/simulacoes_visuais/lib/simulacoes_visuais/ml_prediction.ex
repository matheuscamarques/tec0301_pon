defmodule SimulacoesVisuais.MlPrediction do
  @moduledoc """
  Predições persistidas por pipelines ML batch (artigo 15), p.ex. regressão de OEE ou scores de anomalia.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "ml_predictions" do
    field(:ts, :utc_datetime_usec)
    field(:model_name, :string)
    field(:target_name, :string)
    field(:value_float, :float)
    field(:metadata, :map)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, [:ts, :model_name, :target_name, :value_float, :metadata])
    |> validate_required([:ts, :model_name])
  end
end
