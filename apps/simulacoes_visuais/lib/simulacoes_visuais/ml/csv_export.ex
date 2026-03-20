defmodule SimulacoesVisuais.ML.CsvExport do
  @moduledoc """
  Leitura de CSVs gerados por `mix export.ml` para pipelines ML em Elixir (Nx/Axon/Scholar).
  """
  alias NimbleCSV.RFC4180, as: CSV

  @doc """
  Retorna linhas de `telemetry_events.csv` como mapas com chaves `:ts`, `:fact_name`, `:value_float`.
  Ignora linhas sem `value_float` parseável.
  """
  def read_telemetry!(path) when is_binary(path) do
    path
    |> File.read!()
    |> CSV.parse_string(skip_headers: false)
    |> case do
      [] ->
        []

      [header | rows] ->
        idx = header_index(header)

        Enum.flat_map(rows, fn row ->
          case row_to_telemetry(row, idx) do
            nil -> []
            m -> [m]
          end
        end)
    end
  end

  defp header_index(header) do
    %{
      ts: Enum.find_index(header, &(&1 == "ts")),
      fact_name: Enum.find_index(header, &(&1 == "fact_name")),
      value_float: Enum.find_index(header, &(&1 == "value_float"))
    }
  end

  defp row_to_telemetry(row, idx) do
    vf_raw = Enum.at(row, idx.value_float)

    if vf_raw in [nil, ""] do
      nil
    else
      case Float.parse(vf_raw) do
        {f, _} ->
          ts = Enum.at(row, idx.ts) |> parse_dt!()
          fact = Enum.at(row, idx.fact_name)

          %{ts: ts, fact_name: fact, value_float: f}

        :error ->
          nil
      end
    end
  end

  @doc "Linhas de `oee_snapshots.csv` como `%{ts: _, oee_pct: float}`."
  def read_oee!(path) when is_binary(path) do
    path
    |> File.read!()
    |> CSV.parse_string(skip_headers: false)
    |> case do
      [] ->
        []

      [header | rows] ->
        idx = %{
          ts: Enum.find_index(header, &(&1 == "ts")),
          oee_pct: Enum.find_index(header, &(&1 == "oee_pct"))
        }

        Enum.flat_map(rows, fn row ->
          case row_to_oee(row, idx) do
            nil -> []
            m -> [m]
          end
        end)
    end
  end

  defp row_to_oee(row, idx) do
    raw = Enum.at(row, idx.oee_pct)

    if raw in [nil, ""] do
      nil
    else
      case Float.parse(raw) do
        {f, _} ->
          %{ts: Enum.at(row, idx.ts) |> parse_dt!(), oee_pct: f}

        :error ->
          nil
      end
    end
  end

  defp parse_dt!(s) when is_binary(s) do
    s = String.trim(s)

    case DateTime.from_iso8601(s) do
      {:ok, dt, _} ->
        dt

      {:error, _} ->
        case NaiveDateTime.from_iso8601(s) do
          {:ok, ndt} -> DateTime.from_naive!(ndt, "Etc/UTC")
        end
    end
  end
end
