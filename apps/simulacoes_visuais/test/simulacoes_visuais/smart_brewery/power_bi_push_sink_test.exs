defmodule SimulacoesVisuais.SmartBrewery.PowerBIPushSinkTest do
  use ExUnit.Case, async: false

  alias SimulacoesVisuais.SmartBrewery.FatoDescriptions
  alias SimulacoesVisuais.SmartBrewery.PowerBIPushSink

  setup do
    prev = Application.get_env(:simulacoes_visuais, :power_bi_push)

    on_exit(fn ->
      if prev != nil do
        Application.put_env(:simulacoes_visuais, :power_bi_push, prev)
      else
        Application.delete_env(:simulacoes_visuais, :power_bi_push)
      end
    end)

    :ok
  end

  test "encode_rows_for_push maps TSDB rows to API maps with descricao when include_labels" do
    Application.put_env(:simulacoes_visuais, :power_bi_push,
      enabled: false,
      include_labels: true
    )

    ts = ~U[2025-01-15 12:00:00.000000Z]

    rows = [
      %{
        ts: ts,
        fact_name: "fbe_06_ph",
        value_float: 4.2,
        value_int: nil,
        value_str: nil,
        inserted_at: ts,
        updated_at: ts
      }
    ]

    [one] = PowerBIPushSink.encode_rows_for_push(rows)

    assert one["fact_name"] == "fbe_06_ph"
    assert one["value_float"] == 4.2
    assert one["value_int"] == nil
    assert one["value_str"] == nil
    assert one["ts"] == "2025-01-15T12:00:00.000000Z"
    assert one["descricao"] == FatoDescriptions.descricao(:fbe_06_ph)
  end

  test "encode_rows_for_push omits descricao when include_labels is false" do
    Application.put_env(:simulacoes_visuais, :power_bi_push,
      enabled: false,
      include_labels: false
    )

    ts = ~U[2025-01-15 12:00:00.000000Z]

    rows = [
      %{
        ts: ts,
        fact_name: "fbe_06_ph",
        value_float: 4.2,
        value_int: nil,
        value_str: nil,
        inserted_at: ts,
        updated_at: ts
      }
    ]

    [one] = PowerBIPushSink.encode_rows_for_push(rows)
    refute Map.has_key?(one, "descricao")
  end

  test "encode_rows_for_push skips unexpected entries" do
    assert PowerBIPushSink.encode_rows_for_push([%{}]) == [%{}]
  end
end
