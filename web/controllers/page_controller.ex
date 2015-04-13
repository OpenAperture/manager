defmodule OpenAperture.Manager.PageController do
  use OpenAperture.Manager.Web, :controller

  plug :action

  def index(conn, _params) do
    render conn, "index.html"
  end
end
