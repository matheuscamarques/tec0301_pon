defmodule SimulacoesVisuaisWeb.PageControllerTest do
  use SimulacoesVisuaisWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "Gêmeo Digital"
    assert html =~ "Smart Brewery"
    assert html =~ "id=\"glossario\""
    assert html =~ "lang=\"pt-BR\""
    assert html =~ "<abbr"
  end
end
