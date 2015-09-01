defmodule OpenAperture.Manager.Controllers.CloudProviders do
  require Logger
  use OpenAperture.Manager.Web, :controller

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Controllers.FormatHelper
  alias OpenAperture.Manager.DB.Models.CloudProvider
  alias OpenAperture.Manager.DB.Queries.EtcdCluster, as: EtcdClusterQuery

  @sendable_fields [:id, :name, :type, :configuration, :inserted_at, :updated_at]

  @sendable_fields_cluster [:id, :etcd_token, :name, :hosting_provider_id, :allow_docker_builds, :messaging_exchange_id, :inserted_at, :updated_at]

  @doc """
  List all Cloud Providers the system knows about.
  """
  def swaggerdoc_index, do: %{
    description: "Retrieve all CloudProviders",
    response_schema: %{"type": "array", "items": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.CloudProvider"}},
    parameters: []
  }    
  @spec index(Plug.Conn.t, [any]) :: Plug.Conn.t
  def index(conn, _params) do
    json conn, FormatHelper.to_sendable(Repo.all(CloudProvider), @sendable_fields)
  end

  @doc """
  Retrieve a specific Cloud Provider instance, specified by its id.
  """
  def swaggerdoc_show, do: %{
    description: "Retrieve a specific CloudProvider",
    response_schema: %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.CloudProvider"},
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "CloudProvider identifier",
      "required" => true,
      "type" => "integer"
    }]
  }    
  @spec show(Plug.Conn.t, [any]) :: Plug.Conn.t
  def show(conn, %{"id" => id}) do
    case Repo.get(CloudProvider, id) do
      nil -> resp(conn, :not_found, "")
      cloud_provider ->
        cloud_provider = case cloud_provider.configuration do
          nil -> cloud_provider
          ""  -> %{cloud_provider | configuration: nil}
          config -> %{cloud_provider | configuration: Poison.decode!(config)}
        end
        json conn, cloud_provider |> FormatHelper.to_sendable(@sendable_fields)
    end
  end

  # POST "/"
  def swaggerdoc_create, do: %{
    description: "Create a CloudProvider" ,
    parameters: [%{
      "name" => "type",
      "in" => "body",
      "description" => "The new CloudProvider",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.CloudProvider"}
    }]
  }
  @spec create(Plug.Conn.t, [any]) :: Plug.Conn.t
  def create(conn, params) do
    params = case params["configuration"] do
      nil -> params
      "" -> Map.update(params, "configuration", "", fn _ -> nil end)
      _ -> Map.update(params, "configuration", "", fn _ -> Poison.encode!(params["configuration"]) end)
    end

    changeset = CloudProvider.new(params)
    if changeset.valid? do
      cloud_provider = Repo.insert!(changeset)

      conn
      |> put_resp_header("location", cloud_providers_path(Endpoint, :show, cloud_provider.id))
      |> resp :created, ""
    else
      conn
      |> put_status(:bad_request)
      |> json inspect(changeset.errors)
    end      
  end

  # PUT "/:id"
  def swaggerdoc_update, do: %{
    description: "Update a CloudProvider" ,
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "CloudProvider identifier",
      "required" => true,
      "type" => "integer"
    },
    %{
      "name" => "type",
      "in" => "body",
      "description" => "The updated CloudProvider",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.CloudProvider"}
    }]
  }  
  @spec update(Plug.Conn.t, [any]) :: Plug.Conn.t
  def update(conn, %{"id" => id} = params) do
    case Repo.get(CloudProvider, id) do
      nil ->
        conn
        |> resp :not_found, ""
      provider ->
        params = case params["configuration"] do
          nil -> params
          "" -> params
          _ -> Map.update(params, "configuration", provider.configuration, fn _ -> Poison.encode!(params["configuration"]) end)
        end

        changeset = CloudProvider.update(provider, params)
        if changeset.valid? do
          Repo.update!(changeset)
          conn
          |> put_resp_header("location", cloud_providers_path(Endpoint, :show, provider.id))
          |> resp :no_content, ""
        else
          conn
          |> put_status(:bad_request)
          |> json inspect(changeset.errors)
        end
    end
  end

  def swaggerdoc_destroy, do: %{
    description: "Delete a CloudProvider" ,
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "CloudProvider identifier",
      "required" => true,
      "type" => "integer"
    }]
  }  
  @spec destroy(Plug.Conn.t, [any]) :: Plug.Conn.t
  def destroy(conn, %{"id" => id}) do
    case Repo.get(CloudProvider, id) do
      nil ->
        conn
        |> resp :not_found, ""
      provider ->
        CloudProvider.destroy(provider)
        conn
        |> resp :no_content, ""
    end
  end

  def swaggerdoc_clusters, do: %{
    description: "Retrieve any associated EtcdClusters",
    response_schema: %{"type": "array", "items": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.EtcdCluster"}},
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "CloudProvider identifier",
      "required" => true,
      "type" => "integer"
    }]
  }    
  @spec clusters(Plug.Conn.t, [any]) :: Plug.Conn.t
  def clusters(conn, %{"id" => id}) do
    json conn, FormatHelper.to_sendable(Repo.all(EtcdClusterQuery.get_by_cloud_provider(id)), @sendable_fields_cluster)
  end  
end
