defmodule OpenAperture.Manager.Controllers.ProductClusters do
  require Logger

  use OpenAperture.Manager.Web, :controller

  import OpenAperture.Manager.Controllers.FormatHelper
  alias OpenAperture.Manager.Controllers.ResponseBodyFormatter
  import Ecto.Query

  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductCluster
  alias OpenAperture.Manager.DB.Models.EtcdCluster
  alias OpenAperture.Manager.DB.Queries.Product, as: ProductQuery
  alias OpenAperture.Manager.DB.Queries.ProductCluster, as: ProductClusterQuery

  alias OpenAperture.Manager.Repo

  @sendable_fields [:id, :product_id, :etcd_cluster_id, :primary_ind, :inserted_at, :updated_at]
  @updatable_fields [:product_id, :etcd_cluster_id, :primary_ind]

  # GET "/products/:product_name/clusters"
  def swaggerdoc_index, do: %{
    description: "Retrieve all ProductClusters",
    response_schema: %{"title" => "ProductClusters", "type": "array", "items": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.ProductCluster"}},
    parameters: [%{
      "name" => "product_name",
      "in" => "path",
      "description" => "Name of the Product",
      "required" => true,
      "type" => "string"
    }]
  }    
  @spec index(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def index(conn, %{"product_name" => product_name}) do
    product_name
    |> get_product_by_name
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductCluster")
      product ->
        clusters = product.id
                   |> ProductClusterQuery.get_etcd_clusters
                   |> Repo.all
                   |> Enum.map(&(to_sendable(&1, @sendable_fields)))

        conn
        |> json clusters
    end
  end

  # POST "/products/:product_name/clusters"
  def swaggerdoc_create, do: %{
    description: "Create a ProductCluster" ,
    parameters: [%{
      "name" => "product_name",
      "in" => "path",
      "description" => "Name of the Product",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "type",
      "in" => "body",
      "description" => "The new ProductCluster",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.ProductCluster"}
    }]
  }
  @spec create(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def create(conn, %{"product_name" => product_name, "clusters" => request_clusters}) do
    product_name
    |> get_product_by_name
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductCluster")
      product ->
        ids = Enum.map(request_clusters, &(&1["id"]))
        case find_invalid_etcd_cluster_ids(ids) do
          invalid_ids when length(invalid_ids) > 0 ->
            conn
            |> put_status(:bad_request)
            |> json %{error: "Cluster(s) #{inspect invalid_ids} could not be found."}
          _ ->
            result = Repo.transaction(fn ->
              # blow away the existing ProductCluster records for this product
              ProductCluster.destroy_for_product(product)

              # Now create the new ProductCluster records
              create_new_product_clusters(product.id, ids)
            end)

            case result do
              {:ok, _} ->
                conn
                |> resp :created, ""
              {:error, reason} ->
                Logger.error(reason)
                conn
                |> put_status(:internal_server_error)
                |> json ResponseBodyFormatter.error_body(:internal_server_error, "ProductCluster")
            end            
        end
    end
  end

  # POST "/products/:product_name/clusters"
  # This action matches if the params map doesn't contain a "clusters" key,
  # which means the POSTed JSON object is invalid.
  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json ResponseBodyFormatter.error_body(:bad_request, "ProductCluster")
  end

  # DELETE "/products/:product_name/clusters"
  def swaggerdoc_destroy, do: %{
    description: "Delete all ProductClusters for a Product" ,
    parameters: [%{
      "name" => "product_name",
      "in" => "path",
      "description" => "Name of the Product",
      "required" => true,
      "type" => "string"
    }]
  }  
  @spec destroy(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def destroy(conn, %{"product_name" => product_name}) do
    product_name
    |> get_product_by_name
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductCluster")
      product ->
        ProductCluster.destroy_for_product(product)
        conn
        |> resp :no_content, ""
    end
  end

  # Validate a list of etcd cluster record IDs against what is actually in the
  # database, returning a list of missing ids, or an empty list if all of the
  # specified IDs are valid.
  @spec find_invalid_etcd_cluster_ids([integer]) :: [integer] | []
  defp find_invalid_etcd_cluster_ids(etcd_cluster_ids) do
    valid_ids = EtcdCluster
                |> where([c], c.id in ^etcd_cluster_ids)
                |> select([c], c.id)
                |> Repo.all

    for id <- etcd_cluster_ids, !(id in valid_ids), do: id
  end

  # Create new ProductCluster records for the list of Etcd Cluster IDs, using
  # the specified product id for each.
  @spec create_new_product_clusters(integer, [integer]) :: [ProductCluster.t] | no_return
  defp create_new_product_clusters(product_id, etcd_cluster_ids) do
    etcd_cluster_ids
    |> Enum.map(fn id ->
      params = %{
        product_id: product_id,
        etcd_cluster_id: id
      }

      params
      |> ProductCluster.new
      |> Repo.insert!
    end)
  end

  @spec get_product_by_name(String.t) :: Product.t | nil
  defp get_product_by_name(product_name) do
    product_name
    |> URI.decode
    |> ProductQuery.get_by_name
    |> Repo.one
  end
end