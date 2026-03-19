defmodule SimulacoesVisuaisWeb.PageControllerTest do
  use SimulacoesVisuaisWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "Gêmeo Digital"
    assert html =~ "Smart Brewery"
  end
end
