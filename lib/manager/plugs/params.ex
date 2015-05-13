defmodule OpenAperture.Manager.Plugs.Params do
  @moduledoc """
  This module contains plugs for performing actions on request parameters.
  """
  import Plug.Conn

  @doc """
  Checks if an incoming request has the specified parameter, and if so, parses
  it into an integer. If it can't be parsed into an integer, it's an invalid
  parameter, so the plug responds with the specified error status code and 
  halts processing the request.
  """
  @spec parse_as_integer(Plug.Conn.t, {String.t, integer}) :: Plug.Conn.t
  def parse_as_integer(conn, {param_name, error_status_code}) do
    param = Map.get(conn.params, param_name, nil)
    if param != nil && is_binary(param) do
      case Integer.parse(param) do
        {value, ""} ->
          params = Map.put(conn.params, param_name, value)
          Map.put(conn, :params, params)
        _ ->
          conn
          |> resp(error_status_code, "#{param_name} must be an integer")
          |> halt
      end
    else
      conn
    end
  end

  @doc """
  Calls parse_as_integer(conn, {param_name, 404})
  """
  @spec parse_as_integer(Plug.Conn.t, String.t) :: Plug.Conn.t
  def parse_as_integer(conn, param_name) do
    parse_as_integer(conn, {param_name, 404})
  end

  @doc """
  Checks if an incoming request has the specified parameter, and if it does,
  executes the predicate specified by fun with the parameter value as the
  argument. If the predicate returns false, the function sets the connection's
  status code to error_status_code and halts request processing.
  """
  @spec validate_param(Plug.Conn.t, {String.t, ((any) -> boolean), integer}) :: Plug.Conn.t
  def validate_param(conn, {param_name, fun, error_status_code}) do
    param = Map.get(conn.params, param_name, nil)
    if param != nil && fun.(param) == false do
      conn
      |> resp(error_status_code, "#{inspect param} is not a valid value for #{param_name}")
      |> halt
    else
      conn
    end
  end
  
  @doc """
  Calls validate_param(conn, {param_name, fun, 400})
  """
  @spec validate_param(Plug.Conn.t, {String.t, ((any) -> boolean)}) :: Plug.Conn.t
  def validate_param(conn, {param_name, fun}) do
    validate_param(conn, {param_name, fun, 400})
  end
end