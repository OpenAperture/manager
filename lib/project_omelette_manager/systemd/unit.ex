defmodule ProjectOmeletteManager.SystemdUnit do
  require Logger

  defstruct etcd_token: nil, dst_port: nil, fleet_unit: %FleetApi.Unit{}

  @type t :: %__MODULE__{
    etcd_token: String.t,
    dst_port: integer,
    fleet_unit: FleetApi.Unit.t}

  alias FleetApi.Etcd, as: Fleet
  
  @doc """
  Creates a new Agent for storing Systemd Unit state.
  """
  @spec create(SystemdUnit.t) :: {:ok, pid} | {:error, String.t}
  def create(unit) do
    Agent.start_link(fn -> unit end)
  end

  @doc """
  Creates a new Agent for storing Systemd Unit state. Raises an exception on
  error.
  """
  @spec create!(SystemdUnit.t) :: pid
  def create!(unit) do
    case create(unit) do
      {:ok, unit} -> unit
      {:error, reason} -> raise "Failed to create Systemd Unit: #{inspect reason}"
    end
  end

  @doc """
  Store an etcd token for the Systemd unit.
  """
  @spec set_etcd_token(pid, String.t) :: :ok
  def set_etcd_token(unit_pid, etcd_token) do
    Agent.update(unit_pid, fn unit -> %{unit | etcd_token: etcd_token} end)
  end

  @doc """
  Store the Systemd Unit's assigned port.
  """
  @spec set_assigned_port(pid, integer) :: :ok
  def set_assigned_port(unit_pid, port) do
    Agent.update(unit_pid, fn unit -> %{unit | dst_port: port} end)
  end

  @doc """
  Retrieve the Systemd Unit's assigned port.
  """
  @spec get_assigned_port(pid) :: integer | nil
  def get_assigned_port(unit_pid) do
    Agent.get(unit_pid, &(&1.dst_port))
  end

  @doc """
  Refresh the state of the Unit from the cluster.
  """
  @spec refresh(pid, String.t) :: :ok | :error
  def refresh(unit_pid, etcd_token \\ nil) do
    unit = Agent.get(unit_pid, &(&1))

    resolved_token = etcd_token || unit.etcd_token

    Logger.debug("Refreshing unit #{unit.fleet_unit.name} on cluster #{resolved_token}...")
    {:ok, api_pid} = Fleet.start_link(etcd_token)
    {:ok, fleet_unit} = Fleet.get_unit(api_pid, unit.fleet_unit.name)
    if fleet_unit.name == nil || String.length(fleet_unit.name) == 0 do
      Logger.error("The refresh for unit #{unit.fleet_unit.name} has failed -- the returned data is invalid: #{inspect unit}")
      :error
    else
      Agent.update(unit_pid, fn unit -> %{unit | fleet_unit: fleet_unit} end)
    end
  end

  @doc """
  Retrieve the unit's name.
  """
  @spec get_unit_name(pid) :: String.t
  def get_unit_name(unit_pid) do
    Agent.get(unit_pid, &(&1.fleet_unit.name))
  end

  @doc """
  Retrieve the unit's machine ID.
  """
  @spec get_machine_id(pid) :: String.t
  def get_machine_id(unit_pid) do
    Agent.get(unit_pid, &(&1.fleet_unit.machineID))
  end

  @doc """
  Determine if the unit is in a launched state (according to Fleet).
  """
  @spec is_launched?(pid) :: true | {false, String.t}
  def is_launched?(unit_pid) do
    unit_pid
    |> Agent.get(&(&1.fleet_unit.currentState))
    |> case do
      "launched" -> true
      other_state -> {false, other_state}
    end
  end

  @doc """
  Determine if the unit is active (according to systemd).
  """
  @spec is_active?(pid, String.t) :: true | {false, String.t, String.t, String.t}
  def is_active?(unit_pid, etcd_token \\ nil) do
    unit = Agent.get(unit_pid, &(&1))
    etcd_token = etcd_token || unit.etcd_token
    {:ok, api_pid} = Fleet.start_link(etcd_token)
    {:ok, current_unit_states} = Fleet.list_unit_states(api_pid)

    if unit.fleet_unit.name == nil || current_unit_states == [] do
      Logger.error("Unable to verify the state of unit #{unit.fleet_unit.name}! Please verify that all hosts in the etcd cluster are running Fleet version 0.8.3 or greater!")
      {false, nil, nil, nil}
    else
      requested_state = current_unit_states
                        |> Enum.find(&(String.contains?(&1.name, unit.fleet_unit.name)))

    
      if requested_state do
        case requested_state.systemdActiveState do
          "active" -> true
          systemd_state -> {false, systemd_state, requested_state.systemdLoadState, requested_state.systemdSubState}
        end
      else
        {false, nil, nil, nil}
      end
    end
  end

  @doc """
  Spin up a new unit within a fleet cluster
  """
  @spec spin_up_unit(pid, String.t) :: boolean
  def spin_up_unit(unit_pid, etcd_token \\ nil) do
    unit = Agent.get(unit_pid, &(&1))

    Logger.info("Deploying unit #{unit.fleet_unit.name}...")

    etcd_token = etcd_token || unit.etcd_token

    {:ok, api_pid} = Fleet.start_link(etcd_token)
    case Fleet.set_unit(api_pid, unit.fleet_unit.name, unit.fleet_unit) do
      :ok ->
        Logger.debug("Successfully loaded unit #{unit.fleet_unit.name}")
        true
      other ->
        Logger.error("Failed to create unit #{unit.fleet_unit.name}: #{inspect other}")
        false
    end
  end

  @doc """
  Tear down an existing unit within a fleet cluster.
  """
  @spec tear_down_unit(pid, String.t) :: :ok
  def tear_down_unit(unit_pid, etcd_token \\ nil) do
    unit = Agent.get(unit_pid, &(&1))
    etcd_token = etcd_token || unit.etcd_token

    Logger.info("Tearing down unit #{unit.fleet_unit.name}...")

    {:ok, api_pid} = Fleet.start_link(etcd_token)
    case Fleet.delete_unit(api_pid, unit.fleet_unit.name) do
      :ok ->
        Logger.debug("Successfully deleted unit #{unit.fleet_unit.name}")
        wait_for_unit_teardown(unit_pid, etcd_token)
      other ->
        Logger.error("Failed to delete unit #{unit.fleet_unit.name}: #{inspect other}")
    end
  end

  # Stalls until the container has shut down
  @spec wait_for_unit_teardown(pid, String.t) :: :ok
  defp wait_for_unit_teardown(unit_pid, etcd_token) do
    unit = Agent.get(unit_pid, &(&1))
    Logger.info("Verifying unit #{unit.fleet_unit.name} has stopped...")

    {:ok, api_pid} = Fleet.start_link(etcd_token)
    case Fleet.get_unit(api_pid, unit.fleet_unit.name) do
      {:ok, unit} ->
        Logger.debug("Unit #{unit.fleet_unit.name} is still stopping...")
        :timer.sleep(10000)
        wait_for_unit_teardown(unit_pid, etcd_token)
      {:error, %FleetApi.Error{code: 404}} ->
        Logger.info("Unit #{unit.fleet_unit.name} has stopped.")

        case is_active?(unit_pid) do
          true ->
            Logger.debug("Unit #{unit.fleet_unit.name} is still active...")
            :timer.sleep(10000)
            wait_for_unit_teardown(unit_pid, etcd_token)
          {false, "activating", _, _} ->
            Logger.debug("Unit #{unit.fleet_unit.name} is still starting up...")
            :timer.sleep(10000)
            wait_for_unit_teardown(unit_pid, etcd_token)
          {false, _, _, _} ->
            Logger.info("Unit #{unit.fleet_unit.name} is no longer active.")
            :ok
        end

    end
  end

  @doc """
  Retrieve the journal logs associated with a unit.
  """
  @spec get_journal(pid, String.t) :: {:ok, String.t, String.t} | {:error, String.t, String.t}
  def get_journal(unit_pid, etcd_token \\ nil) do
    unit = Agent.get(unit_pid, &(&1))
    etcd_token = etcd_token || unit.etcd_token

    {:ok, api_pid} = Fleet.start_link(etcd_token)
    {:ok, hosts} = Fleet.list_machines(api_pid)

    if(unit.fleet_unit.machineID != nil) do
      Logger.debug("Resolving host using machineID #{unit.fleet_unit.machineID}...")
      
      requested_host = hosts
                       |> Enum.find(&(String.contains?(&1.id, unit.fleet_unit.machineID)))

      if requested_host != nil do
        Logger.debug("Retrieving logs from host #{inspect requested_host}...")
        result = execute_journal_request([requested_host], unit.fleet_unit, true)        
      end
    end

    case result do
      {:ok, stdout, stderr} -> {:ok, stdout, stderr}
      _ ->
        Logger.debug("Unable to retrieve logs using the unit's machineID, (#{inspect requested_host}), defaulting to all hosts in cluster #{etcd_token}...")
        execute_journal_request(hosts, unit.fleet_unit, true)
    end
  end

  @doc """
  Execute a journal request against a list of hosts.
  """
  @spec execute_journal_request([FleetApi.Machine.t], FleetApi.Unit.t, boolean) :: {:ok, String.t, String.t} | {:error, String.t, String.t}
  def execute_journal_request([requested_host | remaining_hosts], fleet_unit, verify_result) do
    File.mkdir_p("/tmp/cloudos_build_server/systemd_unit")
    stdout_file = "/tmp/cloudos_build_server/systemd_unit/#{UUID.uuid1()}.log"
    stderr_file = "/tmp/cloudos_build_server/systemd_unit/#{UUID.uuid1()}.log"

    journal_script = EEx.eval_file("#{System.cwd!()}/templates/fleetctl-journal.sh.eex", [host_ip: requested_host.primaryIP, unit_name: fleet_unit.name, verify_result: verify_result])
    journal_script_file = "/tmp/cloudos_build_server/systemd_unit/#{UUID.uuid1()}.sh"
    File.write!(journal_script_file, journal_script)

    resolved_cmd = "bash #{journal_script_file} 2> #{stderr_file} > #{stdout_file} < /dev/null"

    Logger.debug ("Executing Fleet command:  #{resolved_cmd}")
    try do
      case System.cmd("/bin/bash", ["-c", resolved_cmd], []) do
        {stdout, 0} ->
          {:ok, read_output_file(stdout_file), read_output_file(stderr_file)}
        {stdout, return_status} ->
          Logger.debug("Host #{requested_host.primaryIP} returned an error (#{return_status}) when looking for unit #{fleet_unit.name}:\n#{read_output_file(stdout_file)}\n\n#{read_output_file(stderr_file)}")
          execute_journal_request(remaining_hosts, fleet_unit, verify_result)
      end
    after
      File.rm_rf(stdout_file)
      File.rm_rf(stderr_file)
      File.rm_rf(journal_script_file)
    end
  end

  @spec execute_journal_request([], FleetApi.Unit.t, boolean) :: {:ok, String.t, String.t} | {:error, String.t, String.t}
  def execute_journal_request([], fleet_unit, _) do
    {:error, "Unable to find a host running service #{fleet_unit.name}!", ""}
  end

  # Check a file exists before trying to read it  
  @spec read_output_file(String.t) :: String.t
  defp read_output_file(output_file) do
    case File.read(output_file) do
      {:ok, contents} -> contents
      {:error, posix_error} ->
        Logger.error("Error reading systemd output file #{output_file}: #{inspect posix_error}")
        ""
    end
  end
end