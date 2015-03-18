#
# == status_controller.ex
#
# This module contains the Phoenix controller for managing CloudOS server statuses.
#
# == Contact
#
# Author::    Trantor (trantordevonly@perceptivesoftware.com)
# Copyright:: 2014 Lexmark International Technology S.A.  All rights reserved.
# License::   n/a
#
require Logger
defmodule ProjectOmeletteManager.StatusController do
  use Phoenix.Controller

#  alias CloudosBuildServer.Agents.BuildServerDependencies

  plug :action

  @moduledoc """
  This module contains the Phoenix controller for managing CloudOS server statuses.
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
  GET /status2 - retrieve context-aware status

  ## Options

  The `conn` option defines the underlying HTTP connection.

  The `_params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection.
  """
  # def status2(conn, _params) do
  #   response = BuildServerDependencies.get_statuses
  #   cond do
  #     response == nil -> 
  #       errors = ["Unable to determine dependency statuses!"]
  #       Logger.error("Status2 check has failed:  #{inspect errors}")
  #       json conn, :internal_server_error, JSON.encode!(%{errors: errors})
  #     response[:statuses] == nil-> 
  #       errors = ["No dependency statuses were found!"]
  #       Logger.error("Status2 check has failed:  #{inspect errors}")
  #       json conn, :internal_server_error, JSON.encode!(%{errors: errors})
  #     length(response[:statuses]) == 0 -> json conn, :ok, ""
  #     true ->
  #       response_errors = Enum.reduce response[:statuses], [], fn (status, errors) ->
  #         if status == nil || status[:availability] != true do
  #           errors ++ ["Dependency #{status[:display]} is unavailable!"]
  #         else
  #           errors
  #         end
  #       end

  #       now_secs = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
  #       last_success_secs = :calendar.datetime_to_gregorian_seconds(response[:last_success_dt_tm])
  #       time_diff_secs = now_secs - last_success_secs

  #       #if the last success time was over 10 minutes ago, fail the status
  #       if time_diff_secs > 600 do
  #         response_errors = response_errors ++ ["The last successful status check was #{time_diff_secs} seconds ago (#{:httpd_util.rfc1123_date(response[:last_success_dt_tm])})"]
  #       end
  
  #       if length(response_errors) > 0 do
  #         Logger.error("Status2 check has failed:  #{inspect response_errors}")          
  #         json conn, :internal_server_error, JSON.encode!(%{errors: response_errors})
  #       else
  #         try do
  #           try do
  #             #run a bogus query to determine if the database connection is alive
  #             CloudosBuildServer.DB.Queries.EtcdCluster.get_by_etcd_token("123abc")
  #             json conn, :ok, ""
  #           rescue e in ArgumentError -> 
  #             errors = ["An exception occurred connecting to the database:  #{inspect e}"]              
  #             Logger.error("Status2 check has failed:  #{inspect response_errors}")
  #             json conn, :internal_server_error, JSON.encode!(%{errors: errors})
  #           end
  #         rescue e in _ -> 
  #           errors = ["An exception occurred connecting to the database:  #{inspect parse_db_status_exception(e)}"]
  #           Logger.error("Status2 check has failed:  #{inspect response_errors}")          
  #           json conn, :internal_server_error, JSON.encode!(%{errors: errors})            
  #         end          
  #       end
  #   end
  # end  

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
