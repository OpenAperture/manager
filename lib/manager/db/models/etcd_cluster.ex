require Logger

defmodule OpenAperture.Manager.DB.Models.EtcdCluster do
  @required_fields [:etcd_token]
  @optional_fields [:name, :hosting_provider_id, :allow_docker_builds, :messaging_exchange_id]
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models.EtcdClusterPort
  alias OpenAperture.Manager.DB.Queries.EtcdClusterPort, as: EctdPortQuery
  alias OpenAperture.Manager.DB.Models.MessagingExchange
  alias OpenAperture.Manager.DB.Models.CloudProvider

  schema "etcd_clusters" do
    has_many :etcd_cluster_ports,   EtcdClusterPort
    field :etcd_token               # defaults to type :string
    field :name                     # defaults to type :string
    belongs_to :hosting_provider,   CloudProvider
    field :allow_docker_builds,     :boolean
    belongs_to :messaging_exchange, MessagingExchange
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    changeset = cast(model_or_changeset, params, @required_fields, @optional_fields)
    changeset = case Map.get(params, :hosting_provider_id, nil) do 
      nil -> 
        changeset
      hosting_provider_id -> 
        case Repo.get(CloudProvider, hosting_provider_id) do 
            nil -> add_error(changeset, :hosting_provider_id, "Invalid Cloud Provider")
            _provider -> changeset
        end
    end
    case Map.get(params, :name, nil) do
      nil -> changeset
      _   -> changeset
             |> validate_length(:name, min: 1)
             |> validate_length(:name, max: 255)
    end
  end

  def destroy(model) do
    Repo.delete model
  end

  def allocate_ports(etcd_cluster, component, port_idx, etcd_ports) do
    if port_idx == 0 do
      etcd_ports
    else
      next_port = OpenAperture.Manager.DB.Models.EtcdCluster.next_available_port(etcd_cluster)

      etcd_port = EtcdClusterPort.new(%{
        etcd_cluster_id: etcd_cluster.id,
        product_component_id: component.id,
        port: next_port,
        inserted_at: Ecto.DateTime.utc,
        updated_at: Ecto.DateTime.utc
      }) |> Repo.insert

      allocate_ports(etcd_cluster, component, port_idx-1, etcd_ports ++ [etcd_port])
    end
  end

  def deallocate_ports_for_component(etcd_cluster, component) do
    raw_ports = Repo.all(EctdPortQuery.get_ports_by_component(etcd_cluster.id, component.id))
    if raw_ports != nil && length(raw_ports) > 0 do
      Enum.reduce raw_ports, [], fn (raw_port, _errors) ->
        Repo.delete(raw_port)
      end
    end
  end  

  def next_available_port(etcd_cluster) do
    used_ports = Repo.all(EctdPortQuery.get_ports_by_cluster(etcd_cluster.id))
    lowest_port = 45000

    if (used_ports != nil && length(used_ports) > 0) do
      used_ports = Enum.sort used_ports, fn (a, b) ->
        a.port < b.port
      end

      find_lowest_available_port(used_ports, lowest_port)
    else
      lowest_port
    end
  end

  defp find_lowest_available_port([raw_port | remaining_ports], current_port) do
    if current_port == raw_port.port do
      find_lowest_available_port(remaining_ports, current_port+1)
    else
      current_port
    end
  end

  defp find_lowest_available_port([], current_port) do
    current_port
  end
end