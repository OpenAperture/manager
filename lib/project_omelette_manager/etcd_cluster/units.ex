defmodule ProjectOmeletteManager.EtcdCluster.Units do
  require Logger
  @type etcd_token :: String.t

  @doc """
  A pid representing an agent holding a ProjectOmeletteManager.SystemdUnit.
  """
  @type systemd_unit_pid :: pid

  alias FleetApi.Etcd, as: Fleet
  alias ProjectOmeletteManager.SystemdUnit

  @doc """
  Deploys new units to the cluster
  """ 
  @spec deploy_units([FleetApi.Unit.t], String.t, [integer]) :: [systemd_unit_pid]
  def deploy_units(units, etcd_token, available_ports \\ []) do
    {:ok, api_pid} = Fleet.start_link(etcd_token)
    {:ok, existing_units} = Fleet.list_units(api_pid)

    num_instances = if available_ports == nil || available_ports == [] do
      {:ok, hosts} = Fleet.list_machines(api_pid)
      length(hosts)
    else
      length(available_ports)
    end

    cycle_units(units, num_instances, etcd_token, available_ports, existing_units, [])
  end

  # Executes a rolling cycle units on the cluster.
  @spec cycle_units([FleetApi.Unit.t], integer, String.t, [integer], [FleetApi.Unit.t], [pid]) :: [FleetApi.Unit.t]
  defp cycle_units([unit | remaining_units], max_instances, etcd_token, available_ports, all_existing_units, newly_deployed_unit_pids) do
    if unit == nil || unit.name == nil do
      remaining_ports = available_ports
    else
      [unit_name|_] = String.split(unit.name, ".service")

      # List comprehension to collect any existing units with this unit name.
      existing_units = for existing <- all_existing_units, String.contains?(existing.name, unit_name), do: existing

      # if there are any instances left over (originally there were 4, now there are 3), tear them down
      {remaining_units, newly_deployed_unit_pids, remaining_ports} = cycle_single_unit(unit, 0, max_instances, available_ports, etcd_token, {existing_units, [], []})

      teardown_units(remaining_units, etcd_token)
    end

    cycle_units(remaining_units, max_instances, etcd_token, remaining_ports, all_existing_units, newly_deployed_unit_pids)
  end

  # This function clause is the base state for the recursion used in the main `cycle_units` implementation.
  defp cycle_units([], _, _, _, _, newly_deployed_unit_pids), do: newly_deployed_unit_pids

  @spec cycle_single_unit(FleetApi.Unit, integer, integer, [integer], String.t, {[FleetApi.Unit.t], [pid], [integer]}) :: :ok
  defp cycle_single_unit(unit, instance_id, max_instances, available_ports, etcd_token, {existing_units, newly_deployed_unit_pids, remaining_ports}) do
    if (instance_id >= max_instances) do
      # We've maxed out our unit count, stop and return any existing units that need to be terminated.
      {existing_units, newly_deployed_unit_pids, remaining_ports}
    else
      resolved_unit = %{unit | desiredState: "launched"}

      #check to see if a unit with the same name already is running
      existing_unit = Enum.find(existing_units, fn u ->
        String.contains?(u.name, resolved_unit.unit)
      end)

      #if the same unit name is running, stop it and track the remaining units
      if (existing_unit != nil) do
        teardown_units([existing_unit], etcd_token)
        remaining_units = List.delete(existing_units, existing_unit)
      else
        remaining_units = existing_units
      end

      #spin through and determine if we need to swap out the port
      if available_ports != nil do
        port = List.first(available_ports)
        available_ports = List.delete_at(available_ports, 0)
      else
        port = 0
      end
            
      if resolved_unit.options != nil && length(resolved_unit.options) > 0 do
        new_options = resolved_unit.options
                      |> Enum.map(fn option ->
                        if String.contains?(option.value, "<%=") do
                          new_value = EEx.eval_string(option.value, [dst_port: port])
                          %{option | value: new_value}
                        else
                          option
                        end
                      end)

        resolved_unit = %{resolved_unit | options: new_options}
      end

      #spin up the new unit
      systemd_unit = %SystemdUnit{
        etcd_token: etcd_token,
        dst_port: port,
        fleet_unit: resolved_unit}

      case SystemdUnit.create(systemd_unit) do
        {:ok, pid} ->
          case SystemdUnit.spin_up_unit(pid, etcd_token) do
            true ->
              newly_deployed_unit_pids = newly_deployed_unit_pids ++ [pid]
            false ->
              Logger.error("Unable to monitor instance #{resolved_unit.name}")
          end
        {:error, reason} -> Logger.error("Failed to create systemd unit for #{resolved_unit.name}:  #{reason}")
      end

      #continue to spin up new units
      cycle_single_unit(unit, instance_id + 1, max_instances, available_ports, etcd_token, {remaining_units, newly_deployed_unit_pids, available_ports})
    end
  end

  defp teardown_units([unit | remaining_units], etcd_token) do
    systemd_unit = %SystemdUnit{
      etcd_token: etcd_token,
      fleet_unit: unit
    }
    case SystemdUnit.create(systemd_unit) do
      {:ok, pid} -> 
        SystemdUnit.tear_down_unit(pid, etcd_token)
      {:error, reason} -> Logger.error("Unable to teardown unit #{unit.name}:  #{reason}")
    end
    
    teardown_units(remaining_units, etcd_token)
  end

  defp teardown_units([], etcd_token) do
    Logger.info "Finished tearing down all previous units in cluster #{etcd_token}"
    :ok
  end
end