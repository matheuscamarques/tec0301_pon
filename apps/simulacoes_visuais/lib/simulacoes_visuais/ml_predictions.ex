defmodule SimulacoesVisuais.MlPredictions do
  @moduledoc """
  Contexto para leitura e importação de `ml_predictions`.
  """
  import Ecto.Query

  alias SimulacoesVisuais.{MlPrediction, Repo}

  @doc "Últimas predições ordenadas por tempo (mais recentes primeiro)."
  def list_recent(limit \\ 50) when is_integer(limit) and limit > 0 do
    from(p in MlPrediction,
      order_by: [desc: p.ts],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Insere várias predições a partir de mapas com chaves string (ex.: JSON decodificado).
  Campos: `model_name` (obrigatório), `ts` (ISO8601 opcional, default agora;
  normalizado para precisão de microsegundos exigida por Ecto),
  `target_name`, `value_float`, `metadata` (mapa).
  """
  def insert_from_decoded_maps(maps) when is_list(maps) do
    now = DateTime.utc_now()

    rows =
      Enum.map(maps, fn m ->
        m = Map.new(m, fn {k, v} -> {to_string(k), v} end)

        case m["model_name"] do
          nil ->
            raise ArgumentError, "each row must include model_name"

          model_name ->
            %{
              id: Ecto.UUID.generate(),
              ts: parse_ts(m["ts"]) || now,
              model_name: model_name,
              target_name: m["target_name"],
              value_float: m["value_float"],
              metadata: m["metadata"] || %{},
              inserted_at: now,
              updated_at: now
            }
        end
      end)

    {n, _} = Repo.insert_all(MlPrediction, rows)
    {:ok, n}
  end

  defp parse_ts(nil), do: nil

  defp parse_ts(ts) when is_binary(ts) do
    case DateTime.from_iso8601(String.trim(ts)) do
      {:ok, dt, _} -> ensure_usec6(dt)
      {:error, _} -> nil
    end
  end

  defp parse_ts(%DateTime{} = dt), do: ensure_usec6(dt)
  defp parse_ts(_), do: nil

  # Ecto :utc_datetime_usec exige precisão 6 no tuplo microsecond ({us, 6}).
  defp ensure_usec6(%DateTime{microsecond: {us, _}} = dt) do
    %{dt | microsecond: {us, 6}}
  end
end
