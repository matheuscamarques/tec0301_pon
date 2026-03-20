defmodule SimulacoesVisuais.MLDatasetExportTest do
  use ExUnit.Case, async: true

  alias SimulacoesVisuais.MLDatasetExport

  test "csv_line formata tipos e escapa vírgulas" do
    dt = ~U[2025-01-02 03:04:05.006789Z]
    assert MLDatasetExport.csv_line([dt]) == "2025-01-02T03:04:05.006789Z"

    assert MLDatasetExport.csv_line([1, 2.5, nil, "ok"]) == "1,2.5,,ok"

    assert MLDatasetExport.csv_line(["a,b", true]) == "\"a,b\",true"
  end
end
