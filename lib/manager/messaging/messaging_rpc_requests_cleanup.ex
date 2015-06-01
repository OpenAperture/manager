require Logger

defmodule OpenAperture.Manager.Messaging.RpcRequestsCleanup do
  use GenServer
  
  import Ecto.Query
  use Timex

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.MessagingRpcRequest

  @moduledoc """
  This module contains the GenServer for cleaning up expired MessagingRpcRequests
  """  

  @doc """
  Specific start_link implementation

  ## Return Values

  {:ok, pid} | {:error, reason}
  """
  @spec start_link() :: {:ok, pid} | {:error, String.t()}  
  def start_link() do
    Logger.debug("[RpcRequestsCleanup] Starting...")

    case GenServer.start_link(__MODULE__, %{}, name: __MODULE__) do
      {:ok, pid} ->
        if Application.get_env(:cleanup, :autostart, true) do
          GenServer.cast(pid, {:cleanup})
        end

        Agent.start_link(fn -> [] end, name: HeartbeatWorkload)
        Logger.debug("[RpcRequestsCleanup] Startup Complete")
        {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  GenServer callback for handling the :cleanup event.  This method
  cleanup expired MessagingRpcRequests every hour

  {:noreply, state}
  """
  @spec handle_cast({:cleanup}, Map) :: {:noreply, Map}
  def handle_cast({:cleanup}, state) do
    #once an hour, cleanup expired RPC requests
    :timer.sleep(3600000)
    cleanup_expired_requests
    GenServer.cast(__MODULE__, {:cleanup})
    {:noreply, state}
  end

  @doc """
  This method cleanup expired MessagingRpcRequests every hour

  {:noreply, state}
  """
  @spec cleanup_expired_requests :: term
  def cleanup_expired_requests do
    lookback_hours = 24
    now_secs = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
    lookback_time = :calendar.gregorian_seconds_to_datetime(now_secs-lookback_hours*60*60)
    ecto_datetime = from_erl(lookback_time)

    Logger.debug("Preparing to delete expired MessagingRpcRequests...")
    Repo.transaction(fn ->
      from(r in MessagingRpcRequest, where: r.inserted_at < ^ecto_datetime) |> Repo.delete_all
    end)
  end

  defp from_erl({{year, month, day}, {hour, min, sec}}) do
    %Ecto.DateTime{year: year, month: month, day: day,
                   hour: hour, min: min, sec: sec}
  end   
end