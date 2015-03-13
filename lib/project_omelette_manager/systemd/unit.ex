defmodule ProjectOmeletteManager.Systemd.Unit do
  require Logger
  @doc """
  Creates a new Agent for storing Systemd Unit state.
  """
  @spec create(Map.t) :: {:ok, pid} | {:error, String.t}
  def create(options) do
    Agent.start_link(fn -> options end)
  end

  @doc """
  Creates a new Agent for storing Systemd Unit state. Raises an exception on
  error.
  """
  @spec create!(Map.t) :: pid
  def create!(options) do
    case create(options) do
      {:ok, unit} -> unit
      {:error, reason} -> raise "Failed to create Systemd Unit: #{inspect reason}"
    end
  end

  @doc """
  Store an etcd token for the Systemd unit.
  """
  @spec set_etcd_token(pid, String.t) :: :ok
  def set_etcd_token(unit_pid, etcd_token) do
    etcd_map = %{:etcd_token => etcd_token, "etcd_token" => etcd_token}

    unit_pid
    |> Agent.update(&(Map.merge(&1, etcd_map)))
  end

  @doc """
  Store the Systemd Unit's assigned port.
  """
  @spec set_assigned_port(pid, integer) :: :ok
  def set_assigned_port(unit_pid, port) do
    port_map = %{:dst_port => port, "dst_port": port}
    unit_pid
    |> Agent.update(&(Map.merge(&1, port_map)))
  end

  @doc """
  Retrieve the Systemd Unit's assigned port.
  """
  @spec get_assigned_port(pid) :: integer | nil
  def get_assigned_port(unit_pid) do
    unit_pid
    |> Agent.get(&(&1[:dst_port]))
  end

  @doc """
  Refresh the state of the Unit from the cluster.
  """
  @spec refresh(pid, String.t) :: :ok | :error
  def refresh(unit_pid, etcd_token \\ nil) do
    unit_options = Agent.get(unit_pid, &(&1))

    resolved_token = etcd_token || unit_options[:etcd_token]

    Logger.debug("Refreshing unit #{unit_options["name"]} on cluster #{resolved_token}...")
    ## TODO: Implement this once FleetApi is in place...
    #refreshed_options = FleetApi.Unit.get_unit!(resolved_etcd_token, unit_options["name"])
    refreshed_options = unit_options
    if refreshed_options["name"] == nil || String.length(refreshed_options["name"]) == 0 do
      Logger.error("The refresh for unit #{unit_options["name"]} has failed -- the returned data is invalid: #{inspect refreshed_options}")
      :error
    else
      Agent.update(unit_pid, fn _ -> refreshed_options end)
      set_etcd_token(unit_pid, resolved_token)
    end
  end

  @doc """
  Retrieve the unit's name.
  """
  @spec get_unit_name(pid) :: String.t
  def get_unit_name(unit_pid) do
    Agent.get(unit_pid, &(&1["name"]))
  end

  @doc """
  Retrieve the unit's machine ID.
  """
  @spec get_machine_id(pid) :: String.t
  def get_machine_id(unit_pid) do
    Agent.get(unit_pid, &(&1["machineID"]))
  end

  @doc """
  Determine if the unit is in a launched state (according to Fleet).
  """
  @spec is_launched?(pid) :: true | {false, String.t}
  def is_launched?(unit_pid) do
    unit_pid
    |> Agent.get(&(&1["currentState"]))
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
    unit_options = Agent.get(unit_pid, &(&1))
    ## TODO: Implement this once FleetAPI is in place...
    #current_unit_states = FleetApi.UnitState.list!(etcd_token || unit_options[:etcd_token])
    current_unit_states = []

    if unit_options["name"] == nil || current_unit_states == [] do
      Logger.error("Unable to verify the state of unit #{unit_options["name"]}! Please verify that all hosts in the etcd cluster are running Fleet version 0.8.3 or greater!")
      {false, nil, nil, nil}
    else
      requested_state = current_unit_states
                        |> Enum.find(&(String.contains?(&1["name"], unit_options["name"])))

    
      if requested_state do
        case requested_state["systemdActiveState"] do
          "active" -> true
          systemd_state -> {false, systemd_state, requested_state["systemdLoadState"], requested_state["systemdSubState"]}
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
    unit_options = Agent.get(unit_pid, &(&1))

    Logger.info("Deploying unit #{unit_options["name"]}...")
    ## TODO: Implement this once FleetAPI is in place...
    # case FleetApi.Unit.set_unit(etcd_token || unit_options[:etcd_token], unit_options, [{"Content-Type", "application/json"}]) do
    #   %FleetApi.Response{status: status} when status in [201, 204] ->
    #     Logger.debug("Successfully loaded unit #{unit_options["name"]}")
    #     true
    #   %FleetApi.Response{status: status, body: body} ->
    #     Logger.error("Failed to create unit #{unit_options["name"]} (#{status}): #{inspect body}")
    #     false
    # end

    false
  end

  @doc """
  Tear down an existing unit within a fleet cluster.
  """
  @spec tear_down_unit(pid, String.t) :: :ok
  def tear_down_unit(unit_pid, etcd_token \\ nil) do
    unit_options = Agent.get(unit_pid, &(&1))
    etcd_token = etcd_token || unit_options[:etcd_token]

    Logger.info("Tearing down unit #{unit_options["name"]}...")
    ## TODO: Implement this once FleetAPI is in place...
    # case FleetApi.Unit.delete_unit(etcd_token, unit_options["name"]) do
    #   %FleetApi.Response{status: status} when status in [201, 204] ->
    #     Logger.debug("Successfully deleted unit #{unit_options["name"]}")
    #     wait_for_unit_teardown(unit_options, etcd_token)
    #   %FleetApi.Response{status: status, body: body} ->
    #     Logger.error("Failed to delete unit #{unit_options["name"]} (#{status}): #{inspect body}")
    # end
    {false, nil, nil, nil}
  end

  # Stalls until the container has shut down
  #@spec wait_for_unit_teardown(pid, String.t) :: :ok
  defp wait_for_unit_teardown(unit_pid, etcd_token) do
    unit_options = Agent.get(unit_pid, &(&1))
    Logger.info("Verifying unit #{unit_options["name"]} has stopped...")

    ## TODO: Implement this once FleetAPI is in place...
    # case FleetApi.Unit.get_unit(etcd_token, unit_options["name"]) do
    #   %FleetApi.Response{status: 200, body: body} ->
    #     Logger.debug("Unit #{unit_options["name"]} is still stopping...")
    #     :timer.sleep(10000)
    #     wait_for_unit_teardown(unit_options, etcd_token)
    #   %FleetApi.Response{status: 404} ->
    #     Logger.info("Unit #{unit_options["name"]} has stopped.")

    #     case is_active?(unit_pid) do
    #       true ->
    #         Logger.debug("Unit #{unit_options["name"]} is still active...")
    #         :timer.sleep(10000)
    #         wait_for_unit_teardown(unit_pid, etcd_token)
    #       {false, "activating", _, _} ->
    #         Logger.debug("Unit #{unit_options["name"]} is still starting up...")
    #         :timer.sleep(10000)
    #         wait_for_unit_teardown(unit_pid, etcd_token)
    #       {false, _, _, _} ->
    #         Logger.info("Unit #{unit_options["name"]} is no longer active.")
    #         :ok
    #     end
    # end
    :ok
  end

  @doc """
  Retrieve the journal logs associated with a unit.
  """
  @spec get_journal(pid, String.t) :: {:ok, String.t, String.t} | {:error, String.t, String.t}
  def get_journal(unit_pid, etcd_token \\ nil) do
    unit_options = Agent.get(unit_pid, &(&1))
    etcd_token = etcd_token || unit_options[:etcd_token]

    if(unit_options["machineID"] != nil) do
      Logger.debug("Resolving host using machineID #{unit_options["machineID"]}...")
      ## TODO: Implement this once FleetAPI is in place...
      # hosts = FleetApi.Machine.list!(etcd_token)
      hosts = []

      requested_host = hosts
                       |> Enum.find(&(String.contains?(&1["id"], unit_options["machineID"])))

      if requested_host != nil do
        Logger.debug("Retrieving logs from host #{inspect requested_host}...")
        result = execute_journal_request([requested_host], unit_options, true)        
      end

      case result do
        {:ok, stdout, stderr} -> {:ok, stdout, stderr}
        _ ->
          Logger.debug("Unable to retrieve logs using the unit's machineID, (#{inspect requested_host}), defaulting to all hosts in cluster #{etcd_token}...")
          ## TODO: Implement this once FleetAPI is in place...
          # hosts = FleetApi.Machine.list!(etcd_token)
          # execute_journal_request(hosts, unit_options, true)
          {:error, nil, nil}
      end
    end
  end

  @doc """
  Execute a journal request against a list of hosts.
  """
  @spec execute_journal_request(List.t, Map.t, boolean) :: {:ok, String.t, String.t} | {:error, String.t, String.t}
  def execute_journal_request([requested_host | remaining_hosts], unit_options, verify_result) do
    File.mkdir_p("/tmp/cloudos_build_server/systemd_unit")
    stdout_file = "/tmp/cloudos_build_server/systemd_unit/#{UUID.uuid1()}.log"
    stderr_file = "/tmp/cloudos_build_server/systemd_unit/#{UUID.uuid1()}.log"

    journal_script = EEx.eval_file("#{System.cwd!()}/templates/fleetctl-journal.sh.eex", [host_ip: requested_host["primaryIP"], unit_name: unit_options["name"], verify_result: verify_result])
    journal_script_file = "/tmp/cloudos_build_server/systemd_unit/#{UUID.uuid1()}.sh"
    File.write!(journal_script_file, journal_script)

    resolved_cmd = "bash #{journal_script_file} 2> #{stderr_file} > #{stdout_file} < /dev/null"

    Logger.debug ("Executing Fleet command:  #{resolved_cmd}")
    try do
      case System.cmd("/bin/bash", ["-c", resolved_cmd], []) do
        {stdout, 0} ->
          {:ok, read_output_file(stdout_file), read_output_file(stderr_file)}
        {stdout, return_status} ->
          Logger.debug("Host #{requested_host["primaryIP"]} returned an error (#{return_status}) when looking for unit #{unit_options["name"]}:\n#{read_output_file(stdout_file)}\n\n#{read_output_file(stderr_file)}")
          execute_journal_request(remaining_hosts, unit_options, verify_result)
      end
    after
      File.rm_rf(stdout_file)
      File.rm_rf(stderr_file)
      File.rm_rf(journal_script_file)
    end
  end

  @spec execute_journal_request(List.t, Map.t, boolean) :: {:ok, String.t, String.t} | {:error, String.t, String.t}
  def execute_journal_request([], unit_options, _) do
    {:error, "Unable to find a host running service #{unit_options["name"]}!", ""}
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