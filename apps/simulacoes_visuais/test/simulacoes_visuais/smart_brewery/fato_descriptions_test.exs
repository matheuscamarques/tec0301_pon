defmodule SimulacoesVisuais.SmartBrewery.FatoDescriptionsTest do
  use ExUnit.Case, async: true

  alias SimulacoesVisuais.SmartBrewery.FatoDescriptions
  alias Tec0301Pon.Examples.SmartBrewery

  test "cada fato do gêmeo tem descrição de UI" do
    for nome <- SmartBrewery.fatos_names() do
      desc = FatoDescriptions.descricao(nome)
      assert desc != "", "falta descrição para #{inspect(nome)}"
      assert String.length(desc) >= 10
    end
  end

  test "átomo desconhecido retorna string vazia" do
    assert FatoDescriptions.descricao(:nao_existe_no_mapa) == ""
  end

  test "descricao_bin/1 espelha descricao/1 para fact_name persistido" do
    assert FatoDescriptions.descricao_bin("fbe_06_ph") == FatoDescriptions.descricao(:fbe_06_ph)
  end

  test "descricao_bin/1 retorna vazio para nome desconhecido" do
    assert FatoDescriptions.descricao_bin("fbe_99_desconhecido") == ""
  end
end
