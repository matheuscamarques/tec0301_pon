defmodule SimulacoesVisuaisWeb.TechGlossaryTest do
  use ExUnit.Case, async: true

  alias SimulacoesVisuaisWeb.TechGlossary

  test "fragment_id/1 and definition_fragment_id/1" do
    assert TechGlossary.fragment_id(:pon) == "glossario-pon"
    assert TechGlossary.fragment_id(:nr_13) == "glossario-nr-13"
    assert TechGlossary.definition_fragment_id(:pon) == "glossario-pon-def"
  end

  test "entry!/1 returns label and texts" do
    e = TechGlossary.entry!(:ml)
    assert e.label == "ML"
    assert e.abbr_title =~ "Machine Learning"
    assert e.definition =~ "ml_predictions"
  end

  test "terms_for/1 lists are non-empty" do
    assert length(TechGlossary.terms_for(:home)) > 0
    assert length(TechGlossary.terms_for(:ml_predictions)) > 0
    assert length(TechGlossary.terms_for(:smart_brewery)) > 0
  end
end
