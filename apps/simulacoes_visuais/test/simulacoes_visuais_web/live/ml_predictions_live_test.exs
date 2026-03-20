defmodule SimulacoesVisuaisWeb.MlPredictionsLiveTest do
  use SimulacoesVisuaisWeb.ConnCase

  import Phoenix.LiveViewTest

  test "GET /smart-brewery/ml-predictions renders", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/smart-brewery/ml-predictions")
    assert html =~ "Predições ML"
    assert html =~ "ml-predictions-table"
    assert has_element?(view, "#glossario")
    assert html =~ "id=\"glossario-timestamp-utc-def\""
    assert html =~ "<abbr"
  end
end
