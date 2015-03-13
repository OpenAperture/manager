defmodule ProjectOmeletteManager.PageController do
  use ProjectOmeletteManager.Web, :controller

  plug :action

  def index(conn, _params) do
    render conn, "index.html"
  end
end
