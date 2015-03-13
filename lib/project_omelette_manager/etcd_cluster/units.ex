defmodule ProjectOmeletteManager.EtcdCluster.Units do
  require Logger
  @type unit :: Map.t
  @type etcd_token :: String.t

  @doc """
  Deploys new units to the cluster
  """ 
  @spec deploy_units([unit], String.t, [integer]) :: [unit]
  def deploy_units(units, etcd_token, available_ports \\ []) do
    ## TODO: Fix once FleetApi is in place
    # existing_units = FleetApi.Unit.list!(etcd_token)
    existing_units = []

    num_instances = if available_ports == nil || available_ports == [] do
      ## TODO: Fix once FleetApi is in place
      # etcd_token
      # |> FleetApi.Machine.list!
      # |> length
      0
    else
      length(available_ports)
    end

    cycle_units(units, num_instances, etcd_token, available_ports, existing_units, [])
  end

  # Executes a rolling cycle units on the cluster.
  @spec cycle_units([unit], integer, String.t, [integer], [unit], [unit]) :: [unit]
  defp cycle_units([unit | remaining_units], max_instances, etcd_token, available_ports, all_existing_units, newly_deployed_units) do
    if unit == nil || unit["name"] == nil do
      remaining_ports = available_ports
    else
      [unit_name|_] = String.split(unit["name"], ".service")

      # List comprehension to pick collect any existing units with this unit name.
      existing_units = for existing <- all_existing_units, String.contains?(existing["name"], unit_name), do: existing

      # if there are any instances left over (originally there were 4, now there are 3), tear them down
      {remaining_units, newly_deployed_units, remaining_ports} = cycle_single_unit(unit, 0, max_instances, available_ports, etcd_token, {existing_units, [], []})
      teardown_units(remaining_units, etcd_token)
    end

    cycle_units(remaining_units, max_instances, etcd_token, remaining_ports, all_existing_units, newly_deployed_units)
  end

  # This function clause is the base state for the recursion used in the main `cycle_units` implementation.
  defp cycle_units([], _, _, _, _, newly_deployed_units), do: newly_deployed_units

  defp cycle_single_unit(unit, instance_id, max_instances, available_ports, etcd_token, {existing_units, newly_deployed_units, remaining_ports}) do
    if (instance_id >= max_instances) do
      # We've maxed out our unit count, stop and return any existing units that need to be terminated.
      {existing_units, newly_deployed_units, remaining_ports}
    else
      resolved_unit = Map.put(unit, "desiredState", "launched")

      #fleet_api requires that name be an atom, so ensure that it's present
      if (resolved_unit[:name] == nil && resolved_unit["name"] != nil) do
        orig_unit_name = hd(String.split(resolved_unit["name"], ".service"))
        unit_instance_name = "#{orig_unit_name}#{instance_id}.service"
        resolved_unit = Map.put(resolved_unit, :name, unit_instance_name)
        resolved_unit = Map.put(resolved_unit, "name", unit_instance_name)
      end

      #check to see if a unit with the same name already is running
      existing_unit = Enum.reduce(existing_units, nil, fn(cur_unit, existing_unit)->
        if ((existing_unit == nil) && String.contains?(cur_unit["name"], resolved_unit["name"])) do
          existing_unit = cur_unit
        end
        existing_unit
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
            
      if resolved_unit["options"] != nil && length(resolved_unit["options"]) > 0 do
        new_options= Enum.reduce resolved_unit["options"], [], fn (option, new_options) ->
          if String.contains?(option["value"], "<%=") do
            updated_option_value = EEx.eval_string(option["value"], [dst_port: port])
            updated_option = Map.put(option, "value", updated_option_value)
          else
            updated_option = option
          end

          new_options ++ [updated_option]
        end
        resolved_unit = Map.put(resolved_unit, "options", new_options)
      end
      
      #spin up the new unit
      case SystemdUnit.create(resolved_unit) do
        {:ok, deployed_unit} ->
          case SystemdUnit.spinup_unit(deployed_unit, etcd_token) do
            true ->
              SystemdUnit.set_etcd_token(deployed_unit, etcd_token)
              SystemdUnit.set_assigned_port(deployed_unit, port)
              newly_deployed_units = newly_deployed_units ++ [deployed_unit]
            false ->
              Logger.error("Unable to monitor instance #{resolved_unit["name"]}")
          end
        {:error, reason} -> Logger.error("Failed to create systemd unit for #{resolved_unit["name"]}:  #{reason}")
      end

      #continue to spin up new units
      cycle_single_unit(unit, instance_id + 1, max_instances, available_ports, etcd_token, {remaining_units, newly_deployed_units, available_ports})
    end
  end

  defp teardown_units([unit | remaining_units], etcd_token) do
    case SystemdUnit.create(unit) do
      {:ok, deployed_unit} -> 
        SystemdUnit.set_etcd_token(deployed_unit, etcd_token)
        SystemdUnit.teardown_unit(deployed_unit, etcd_token)
      {:error, reason} -> Logger.error("Unable to teardown unit #{unit["name"]}:  #{reason}")
    end
    
    teardown_units(remaining_units, etcd_token)
  end

  defp teardown_units([], etcd_token) do
    Logger.info "Finished tearing down all previous units in cluster #{etcd_token}"
    :ok
  end
end