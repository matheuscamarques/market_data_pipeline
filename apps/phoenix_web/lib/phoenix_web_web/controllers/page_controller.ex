defmodule PhoenixWebWeb.PageController do
  use PhoenixWebWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
