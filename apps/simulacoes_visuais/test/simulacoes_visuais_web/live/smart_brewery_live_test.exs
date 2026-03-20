defmodule SimulacoesVisuaisWeb.SmartBreweryLiveTest do
  use SimulacoesVisuaisWeb.ConnCase

  import Phoenix.LiveViewTest

  test "GET /smart-brewery includes glossary, BI tab hint and technical abbr tooltips", %{
    conn: conn
  } do
    {:ok, view, html} = live(conn, ~p"/smart-brewery")

    assert html =~ "id=\"glossario\""
    assert html =~ "id=\"glossario-heading\""
    assert html =~ "id=\"tab-bi\""

    assert html =~
             "Business Intelligence: gráficos e consultas analíticas sobre dados armazenados na aplicação."

    assert has_element?(view, "abbr[title*='Paradigma Orientado a Notificações']")
    assert has_element?(view, "#glossario-pon")
  end
end
