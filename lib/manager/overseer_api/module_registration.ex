require Logger

defmodule OpenAperture.Manager.OverseerApi.ModuleRegistration do
  use GenServer

  @moduledoc """
  This module contains the GenServer for a Manager system module to interact with the Overseer system module
  """  

  alias OpenAperture.Manager.Repo
  require Repo

  alias OpenAperture.Manager.DB.Models.MessagingExchangeModule, as: MessagingExchangeModuleDb
  alias OpenAperture.Manager.Configuration

  @doc """
  Specific start_link implementation

  ## Return Values

  {:ok, pid} | {:error, reason}
  """
  @spec start_link() :: {:ok, pid} | {:error, String.t()} 
  def start_link() do
    module = %{
      hostname: System.get_env("HOSTNAME"),
      messaging_exchange_id: Configuration.get_current_exchange_id,
      type: :manager,
      status: :active,
      workload: []
    }
    
    case Agent.start_link(fn ->module end, name: __MODULE__) do
      {:ok, pid} ->
        if Application.get_env(:openaperture_manager_overseer_api, :autostart, true) do
          case register_module(module) do
            true -> 
              Logger.debug("[ModuleRegistration] Completed")
            false -> 
              Logger.error("[ModuleRegistration] Completed")
              Agent.update(pid, fn _ -> nil end)
          end
        end
        {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Method to register a system module

  ## Return Values

  boolean
  """
  @spec register_module(Map) :: term
  def register_module(module) do
    Logger.debug("[ModuleRegistration] Registering module #{module[:hostname]} (#{module[:type]}) with OpenAperture...")

    changeset = MessagingExchangeModuleDb.new(%{
      "messaging_exchange_id" => module[:messaging_exchange_id],
      "hostname" => module[:hostname],
      "type" => "#{module[:type]}",
      "status" => "#{module[:status]}",
      "workload" => Poison.encode!(module[:workload])
    })

    try do
      unless changeset.valid? do
        Logger.error("[ModuleRegistration] Unable to register module #{module[:hostname]}!  module - #{inspect module}, error - #{inspect changeset.errors}")
      else        
        Repo.insert(changeset)
      end
    catch
      :exit, code   -> 
        Logger.error("[ModuleRegistration] Failed to registered module #{module[:hostname]}!  module - #{inspect module}, error - #{inspect code}")
      :throw, value -> 
        Logger.error("[ModuleRegistration] Failed to registered module #{module[:hostname]}!  module - #{inspect module}, error - #{inspect value}")
      what, value   -> 
        Logger.error("[ModuleRegistration] Failed to registered module #{module[:hostname]}!  module - #{inspect module}, error - #{inspect what}, #{inspect value}")
    end

    true
  end

  @doc """
  Method to retrieve the current module

  ## Return Values

  Map
  """
  @spec get_module :: Map
  def get_module do
    Agent.get(__MODULE__, fn module -> module end)
  end
end
