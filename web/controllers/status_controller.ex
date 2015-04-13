#
# == status_controller.ex
#
# This module contains the Phoenix controller for managing OpenAperture server statuses.
#
# == Contact
#
# Author::    Trantor (trantordevonly@perceptivesoftware.com)
# Copyright:: 2014 Lexmark International Technology S.A.  All rights reserved.
# License::   n/a
#
require Logger
defmodule OpenAperture.Manager.StatusController do
  use Phoenix.Controller

  plug :action

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

  @doc """
  GET /status/dependencies - retrieve dependencies status entries.

  This endpoint is required to be auth-free (since auth is an external dependency)

  ## Options

  The `conn` option defines the underlying HTTP connection.

  The `_params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection.
  """
  def dependencies(conn, _params) do
    json conn, JSON.encode!(BuildServerDependencies.get_statuses)
  end   

  @doc false
  # Method to parse database exceptions
  # 
  ## Options
  # 
  # The `conn` option defines the underlying HTTP connection.
  #
  # The exception option defines the database exception
  # 
  ## Return values
  # 
  # Underlying HTTP connection.
  # 
  defp parse_db_status_exception(%Postgrex.Error{message: message, postgres: %{code: code, message: postgrex_msg, severity: severity}}) do
    Logger.error("A postgrex exception occurred connecting to the database:  [#{severity}] #{message} - #{code}, #{postgrex_msg}")
    "Database connection error, [#{severity}] #{message} - #{code}, #{postgrex_msg}"
  end

  @doc false
  # Method to parse database exceptions
  # 
  ## Options
  # 
  # The `conn` option defines the underlying HTTP connection.
  #
  # The exception option defines the database exception
  # 
  ## Return values
  # 
  # Underlying HTTP connection.
  # 
  defp parse_db_status_exception(%Postgrex.Error{message: message}) do
    Logger.error("A postgrex exception occurred connecting to the database:  Postgrex encountered an error:  #{message}")
    "Database connection error, Postgrex encountered an error:  #{message}"
  end

  @doc false
  # Method to parse database exceptions
  # 
  ## Options
  # 
  # The `conn` option defines the underlying HTTP connection.
  #
  # The exception option defines the database exception
  # 
  ## Return values
  # 
  # Underlying HTTP connection.
  # 
  defp parse_db_status_exception(e) do
    Logger.error("An unknown exception occurred connecting to the database:  #{inspect e}")
    "Unknown database connection error:  #{inspect e}"
  end  
end
