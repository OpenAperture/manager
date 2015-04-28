require Logger

defmodule OpenAperture.Manager.OverseerApi.ModuleRegistration do
  use GenServer

  @moduledoc """
  This module contains the GenServer for a Manager system module to interact with the Overseer system module
  """  

  alias OpenapertureManager.Repo
  require Repo

  alias OpenAperture.Manager.Endpoint
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
            true -> {:ok, pid}
            false -> {:error, "[ModuleRegistration] Failed to register module #{module[:hostname]}!"}
          end
        else
          {:ok, pid}
        end
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

    unless changeset.valid? do
      Logger.error("[ModuleRegistration] Unable to register module #{module[:hostname]}!  module - #{inspect module}, error - #{inspect changeset.errors}")
      false
    else
      try do
        inserted_module = Repo.insert(changeset)
        Logger.debug("[ModuleRegistration] Successfully registered module #{module[:hostname]}")
        true
      rescue e ->
        Logger.error("[ModuleRegistration] Failed to registered module #{module[:hostname]}!  module - #{inspect module}, error - #{inspect e}")
        false
      end  
    end
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