require Logger

defmodule OpenAperture.Manager.DB.Models.ProductDeploymentPlanStep do
  @required_fields [:product_deployment_plan_id, :type]
  @optional_fields [:on_success_step_id, :on_failure_step_id]
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models


  schema "product_deployment_plan_steps" do
    belongs_to :product_deployment_plan,            Models.ProductDeploymentPlan
    has_many :product_deployment_plan_step_options, Models.ProductDeploymentPlanStepOption
    field :type,                                    :string
    field :on_success_step_id,                      :integer
    field :on_failure_step_id,                      :integer
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
      |> validate_inclusion(:type, ~w(build_component deploy_component build_deploy_component component_script deploy_script execute_plan))
  end

  def destroy_for_deployment_plan(pdp), do: destroy_for_association(pdp, :product_deployment_plan_steps)

  def destroy(pdps) do
    Repo.transaction(fn ->
      Models.ProductDeploymentPlanStepOption.destroy_for_deployment_plan_step(pdps)
      Repo.delete(pdps)
    end)
    |> transaction_return
  end

  @doc """
  Method to convert a flattened array of OpenAperture.Manager.DB.Models.ProductDeploymentPlanSteps into
  a hierarchical Map

  ## Options

  The `raw_steps` option is a List of OpenAperture.Manager.DB.Models.ProductDeploymentPlanSteps

  ## Return values

  Single root object
  """
  @spec to_hierarchy(List) :: Map
  def to_hierarchy(steps_to_convert, is_raw \\ false) do
    if (steps_to_convert == nil || length(steps_to_convert) == 0) do
      nil
    else
      #first pass - convert the struct into a map and identify dependencies
      {map_steps, map_child_ids, map_node_links} = Enum.reduce steps_to_convert, {%{}, %{}, %{}}, fn(step, {map_steps, map_child_ids, map_node_links}) ->
        if (is_raw) do
          map_step = Map.from_struct(step)
        else
          map_step = step
        end

        map_steps = Map.put(map_steps, map_step[:id], map_step)

        #find all of the child ids required by this step
        if (map_step[:on_success_step_id] != nil) do
          map_child_ids = Map.put(map_child_ids, map_step[:on_success_step_id], true)

          #update the array of who is using the nodes
          node_links = map_node_links[map_step[:on_success_step_id]]
          if (node_links == nil) do
            node_links = []
          end
          node_links = node_links ++ [map_step.id]
          map_node_links = Map.put(map_node_links, map_step[:on_success_step_id], node_links)      
        end

        if (map_step[:on_failure_step_id] != nil) do
          map_child_ids = Map.put(map_child_ids, map_step[:on_failure_step_id], true)

          #update the array of who is using the nodes
          node_links = map_node_links[map_step[:on_failure_step_id]]
          if (node_links == nil) do
            node_links = []
          end
          node_links = node_links ++ [map_step.id]
          map_node_links = Map.put(map_node_links, map_step[:on_failure_step_id], node_links)
        end



        {map_steps, map_child_ids, map_node_links}
      end

      {map_steps, _map_node_links, root_step_id} = Enum.reduce Map.keys(map_steps), {map_steps, map_node_links, nil}, fn(key, {map_steps, map_node_links, root_step_id}) ->
        map_step = map_steps[key]

        #if this step isn't used as a child step, we found the root
        if (!Map.has_key?(map_child_ids, key)) do
          root_step_id = key
        end

        #check to see if this node has any dependencies to flush out
        changes_made = false
        if (map_step[:on_success_step_id] != nil) do
          map_step = Map.put(map_step, :on_success_step, map_steps[map_step[:on_success_step_id]])
          changes_made = true
        end

        if (map_step[:on_failure_step_id] != nil) do
          map_step = Map.put(map_step, :on_failure_step, map_steps[map_step[:on_failure_step_id]])
          changes_made = true
        end

        #we've made changes, so update anyone who currently links to this node (yeah for immutability!)
        if (changes_made) do
          map_steps = update_node_links(map_steps, map_node_links, map_step)
        end

        {map_steps, map_node_links, root_step_id}
      end

      if (root_step_id == nil) do
        nil
      else
        map_steps[root_step_id]
      end
    end
  end

  @doc false
  # Method to update all related nodes, given a specific node
  #
  ## Option Values
  #
  # The `map_steps` option is the master Map of step definitions
  #
  # The `map_node_links` option is the master Map of link definitions
  #
  # The `map_step` option is the currently modified step definition
  #
  # Map, the updated Map of step definitions
  #
  @spec update_node_links(Map, Map, term) :: Map
  defp update_node_links(map_steps, map_node_links, map_step) do
    #update the current node
    map_steps = Map.put(map_steps, map_step[:id], map_step)

    #find nodes that depend on me
    linked_nodes = map_node_links[map_step[:id]]
    if (linked_nodes != nil && length(linked_nodes) > 0) do
      map_steps = Enum.reduce linked_nodes, map_steps, fn(linked_node_id, map_steps) ->
        linked_node = map_steps[linked_node_id]

        changes_made = false
        if (linked_node[:on_success_step_id] == map_step[:id]) do
          linked_node = Map.put(linked_node, :on_success_step, map_step)
          changes_made = true
        end

        if (linked_node[:on_failure_step_id] == map_step[:id]) do
          linked_node = Map.put(linked_node, :on_failure_step, map_step)
          changes_made = true
        end

        #update any of this node's dependencies
        if (changes_made) do
          map_steps = update_node_links(map_steps, map_node_links, linked_node)
        end

        map_steps
      end
    end
    map_steps
  end

  @doc """
  Method to convert a hierarchy of Steps into a flattened array (not raw db model)

  ## Options

  The `node` option is the map representing the OpenAperture.Manager.DB.Models.ProductDeploymentPlanStep

  ## Return values

  Single root object
  """
  @spec flatten_hierarchy(Map) :: List
  def flatten_hierarchy(node) do
    if (node == nil) do
      nil
    else
      Map.values(flatten_node(node, %{}))
    end
  end

  @doc false
  # Method to flatten a specific node
  #
  ## Option Values
  #
  # The `map_steps` option is the master Map of step definitions
  #
  # The `map_node_links` option is the master Map of link definitions
  #
  # The `map_steps` option is the master Map of nodes
  #
  # Map, the updated Map of step definitions
  #
  @spec flatten_node(Map, Map) :: Map
  defp flatten_node(node, map_steps) do
    if node != nil do
      if map_steps[node[:id]] == nil do
        map_steps = Map.put(map_steps, node[:id], node)
      end

      map_steps = flatten_node(node[:on_success_step], map_steps)
      map_steps = flatten_node(node[:on_failure_step], map_steps)
      map_steps
    else
      map_steps
    end
  end
end
