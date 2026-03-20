defmodule SimulacoesVisuais.ML.FeaturesTest do
  use ExUnit.Case, async: true

  alias SimulacoesVisuais.ML.Features

  test "oee_supervised_dataset builds tensors when FBE_08 facts align per minute" do
    base = ~U[2025-01-01 10:00:00Z]

    tel =
      for m <- 0..15 do
        ts = DateTime.add(base, m * 60, :second)

        [
          %{ts: ts, fact_name: "fbe_08_conveyor_speed", value_float: 1.0 * m},
          %{ts: ts, fact_name: "fbe_08_ir_bottle_detect", value_float: 0.0}
        ]
      end
      |> List.flatten()

    oee =
      for m <- 0..15 do
        %{ts: DateTime.add(base, m * 60 + 20, :second), oee_pct: 50.0 + m * 0.25}
      end

    assert {:ok, {x, y, names}} = Features.oee_supervised_dataset(tel, oee)
    assert Nx.axis_size(x, 0) == Nx.axis_size(y, 0)
    assert length(names) == 2
    assert Nx.axis_size(x, 1) == 2
  end
end
