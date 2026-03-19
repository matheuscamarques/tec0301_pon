defmodule SimulacoesVisuais.TelemetryEvent do
  @moduledoc """
  Schema para persistência de fatos de telemetria no TSDB (TimescaleDB).
  Artigo 07 §4.2. Tabela adequada a hypertable por timestamp.
  """
  use Ecto.Schema

  @primary_key false
  schema "telemetry_events" do
    field(:ts, :utc_datetime_usec)
    field(:fact_name, :string)
    field(:value_float, :float)
    field(:value_int, :integer)
    field(:value_str, :string)

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Converte uma lista de atualizações {nome_fato, valor} em listas de atributos
  para insert_all. Apenas valores numéricos ou convertíveis são persistidos.
  """
  def changesets_from_batch(updates, now \\ DateTime.utc_now()) do
    Enum.flat_map(updates, fn {nome, valor} ->
      case to_row(nome, valor, now) do
        nil -> []
        row -> [row]
      end
    end)
  end

  defp to_row(nome, valor, now) when is_number(valor) do
    %{
      ts: now,
      fact_name: Atom.to_string(nome),
      value_float: to_float(valor),
      value_int: nil,
      value_str: nil,
      inserted_at: now,
      updated_at: now
    }
  end

  defp to_row(_nome, _valor, _now), do: nil

  defp to_float(n) when is_integer(n), do: n * 1.0
  defp to_float(n) when is_float(n), do: n

  @doc """
  Consulta séries por nome do fato e janela de tempo (para sparklines/gráficos).
  Requer Repo configurado e iniciado. Retorna lista de %{ts: datetime, value: float}.
  """
  def list_series(fact_name, window_minutes \\ 60, limit \\ 500) when is_binary(fact_name) do
    since = DateTime.utc_now() |> DateTime.add(-window_minutes * 60, :second)
    import Ecto.Query

    query =
      from(e in __MODULE__,
        where: e.fact_name == ^fact_name and e.ts >= ^since,
        order_by: [asc: e.ts],
        limit: ^limit,
        select: %{ts: e.ts, value: e.value_float}
      )

    try do
      SimulacoesVisuais.Repo.all(query)
    rescue
      _ -> []
    end
  end
end
