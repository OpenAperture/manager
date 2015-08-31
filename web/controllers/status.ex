#
# == status_controller.ex
#
# This module contains the Phoenix controller for managing OpenAperture server statuses.
#
require Logger
defmodule OpenAperture.Manager.Controllers.Status do
  use Phoenix.Controller

  @moduledoc """
  This module contains the Phoenix controller for managing OpenAperture server statuses.
  """   

  @doc """
  GET /status - retrieve server status

  ## Options

  The `conn` option defines the underlying HTTP connection.

  The `_params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection.
  """
  def index(conn, _params) do
    json conn, ""
  end
end
