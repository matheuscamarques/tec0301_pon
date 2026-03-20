defmodule SimulacoesVisuais.TelemetryEventTest do
  use ExUnit.Case, async: true

  alias SimulacoesVisuais.TelemetryEvent

  @now ~U[2025-03-01 12:00:00.000000Z]

  test "changesets_from_batch persiste numéricos, booleanos e átomos" do
    rows =
      TelemetryEvent.changesets_from_batch(
        [
          {:fbe_num, 42},
          {:fbe_float, 3.5},
          {:fbe_bool, true},
          {:fbe_atom, :closed},
          {:fbe_nil, nil}
        ],
        @now
      )

    assert length(rows) == 4

    num = Enum.find(rows, &(&1.fact_name == "fbe_num"))
    assert num.value_float == 42.0
    assert num.value_int == nil
    assert num.value_str == nil

    bool = Enum.find(rows, &(&1.fact_name == "fbe_bool"))
    assert bool.value_float == nil
    assert bool.value_int == 1
    assert bool.value_str == "true"

    atom = Enum.find(rows, &(&1.fact_name == "fbe_atom"))
    assert atom.value_str == "closed"
    assert atom.value_float == nil
  end
end
