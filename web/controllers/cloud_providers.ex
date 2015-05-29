defmodule OpenAperture.Manager.Controllers.CloudProviders do
  require Logger
  use OpenAperture.Manager.Web, :controller

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Controllers.FormatHelper
  alias OpenAperture.Manager.DB.Models.CloudProvider
  alias OpenAperture.Manager.DB.Queries.EtcdCluster, as: EtcdClusterQuery

  @sendable_fields [:id, :name, :type, :configuration, :inserted_at, :updated_at]

  plug :action

  @doc """
  List all Cloud Providers the system knows about.
  """
  def index(conn, _params) do
    providers = CloudProvider
        |> Repo.all
        |> Enum.map &Map.from_struct/1

    #IO.puts("clusters:  #{inspect clusters}")
    conn
    |> json providers
  end

  @doc """
  Retrieve a specific Cloud Provider instance, specified by its id.
  """
  @spec show(term, [any]) :: term
  def show(conn, %{"id" => id}) do
    case Repo.get(CloudProvider, id) do
      nil -> resp(conn, :not_found, "")
      cloud_provider -> json conn, cloud_provider |> FormatHelper.to_sendable(@sendable_fields)
    end
  end

  # POST "/"
  def create(conn, params) do
    changeset = CloudProvider.new(params)

    if changeset.valid? do
      cloud_provider = Repo.insert(changeset)

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
  def update(conn, %{"id" => id} = params) do
    Repo.get(CloudProvider, id)
    |> case do
      nil ->
        conn
        |> resp :not_found, ""
      provider ->
        changeset = CloudProvider.update(provider, params)
        if changeset.valid? do
          product = Repo.update(changeset)
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

  def destroy(conn, %{"id" => id}) do
    Repo.get(CloudProvider, id)
    |> case do
      nil ->
        conn
        |> resp :not_found, ""
      provider ->
        Repo.delete(provider)
        conn
        |> resp :no_content, ""
    end
  end

  def clusters(conn, %{"id" => id}) do
    clusters = EtcdClusterQuery.get_by_cloud_provider(id)
    |> Repo.all
    |> Enum.map &Map.from_struct/1 

    conn
    |> json clusters
  end
  
end