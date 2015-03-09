#
# == product_cluster.ex
#
# This module contains the queries associated with ProjectOmeletteManager.DB.Models.ProductCluster
#
# == Contact
#
# Author::    Trantor (trantordevonly@perceptivesoftware.com)
# Copyright:: 2014 Lexmark International Technology S.A.  All rights reserved.
# License::   n/a
#
defmodule ProjectOmeletteManager.DB.Queries.ProductCluster do
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.EtcdCluster
  alias ProjectOmeletteManager.DB.Models.ProductCluster

  import Ecto.Query

  @doc """
  Method to retrieve the DB.Models.EtcdClusters associated with the product

  ## Options

  The `product_id` option is the integer identifier of the product
      
  ## Return values
   
  db query
  """
  @spec get_etcd_clusters(term) :: term
  def get_etcd_clusters(product_id) do
    from pc in ProductCluster,
      join: c in EtcdCluster, on: pc.etcd_cluster_id == c.id,
      where: pc.product_id == ^product_id,
      select: c
  end

  @doc """
  Method to retrieve the DB.Models.ProductClusters associated with the product

  ## Options

  The `product_id` option is the integer identifier of the product
      
  ## Return values
   
  db query
  """
  @spec get_product_clusters(term) :: term
  def get_product_clusters(product_id) do
    from pc in ProductCluster,
      where: pc.product_id == ^product_id,
      select: pc
  end

  @doc """
  Method to retrieve the DB.Models.EtcdClusters associated with the product

  ## Options

  The `product_id` option is the integer identifier of the product
      
  ## Return values
   
  db query
  """
  @spec get_products_for_cluster(term) :: term
  def get_products_for_cluster(etcd_cluster_id) do
    from pc in ProductCluster,
      join: p in Product, on: pc.product_id == p.id,
      where: pc.etcd_cluster_id == ^etcd_cluster_id,
      select: p
  end
end