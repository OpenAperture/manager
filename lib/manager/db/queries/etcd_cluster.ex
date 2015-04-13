defmodule OpenAperture.Manager.DB.Queries.EtcdCluster do
  import Ecto.Query

  alias OpenapertureManager.Repo
  alias OpenAperture.Manager.DB.Models.EtcdCluster

  @doc """
  Retrieves the database record for the provided etcd token string.

  If no record is found, returns nil.
  """
  @spec get_by_etcd_token(term) :: EtcdCluster.t | nil
  def get_by_etcd_token(etcd_token) do
    query = from cluster in EtcdCluster,
            where: fragment("lower(?) = lower(?)", cluster.etcd_token, ^etcd_token),
            select: cluster

    case Repo.all(query) do
      [cluster | _] -> cluster
      [] -> nil
    end
  end

  @doc """
  Method to retrieve the DB.Models.EtcdCluster for an id

  ## Options

  The `product_id` option is the integer identifier of the product
      
  ## Return values
   
  db query
  """
  @spec get_by_id(term) :: term
  def get_by_id(cluster_id) do
    from c in EtcdCluster,
      where: c.id == ^cluster_id,
      select: c
  end

  @doc """
  Method to retrieve the DB.Models.EtcdCluster that have the allow_docker_builds set to true
     
  ## Return values
   
  db query
  """
  @spec get_docker_build_clusters :: term
  def get_docker_build_clusters do
    from c in EtcdCluster,
      where: c.allow_docker_builds == true,
      select: c
  end
end