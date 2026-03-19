defmodule SimulacoesVisuaisWeb.PageController do
  use SimulacoesVisuaisWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
