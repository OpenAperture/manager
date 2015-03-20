defmodule ProjectOmeletteManager.Router do
  use Phoenix.Router

  pipeline :browser do
    plug :accepts, ~w(html)
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ProjectOmeletteManager do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    #Server Statuses
    get "/status", StatusController, :index

  end

  scope "/clusters", ProjectOmeletteManager do
    pipe_through :api

    get "/", EtcdClusterController, :index
    post "/", EtcdClusterController, :register

    get "/:etcd_token", EtcdClusterController, :show
    delete "/:etcd_token", EtcdClusterController, :destroy
    get "/:etcd_token/products", EtcdClusterController, :products
    get "/:etcd_token/machines", EtcdClusterController, :machines
    get "/:etcd_token/units", EtcdClusterController, :units
    get "/:etcd_token/state", EtcdClusterController, :units_state
    get "/:etcd_token/machines/:machine_id/units/:unit_name/logs", EtcdClusterController, :unit_logs
  end

  scope "/messaging", ProjectOmeletteManager.Web.Controllers do
    pipe_through :api

    scope "/brokers" do
      get "/", MessagingBrokersController, :index
      post "/", MessagingBrokersController, :create

      get "/:id", MessagingBrokersController, :show
      put "/:id", MessagingBrokersController, :update
      delete "/:id", MessagingBrokersController, :destroy

      get "/:id/connections", MessagingBrokersController, :get_connections
      post "/:id/connections", MessagingBrokersController, :create_connection
      delete "/:id/connections", MessagingBrokersController, :destroy_connections
    end

    scope "/exchanges" do
      get "/", MessagingExchangesController, :index
      post "/", MessagingExchangesController, :create

      get "/:id", MessagingExchangesController, :show
      put "/:id", MessagingExchangesController, :update
      delete "/:id", MessagingExchangesController, :destroy

      get "/:id/brokers", MessagingExchangesController, :get_broker_restrictions
      post "/:id/brokers", MessagingExchangesController, :create_broker_restriction
      delete "/:id/brokers", MessagingExchangesController, :destroy_broker_restrictions

      get "/:id/clusters", MessagingExchangesController, :show_clusters
    end
  end

  scope "/products", ProjectOmeletteManager do
    pipe_through :api

    get "/", ProductsController, :index
    post "/", ProductsController, :create

    get "/:product_name", ProductsController, :show
    delete "/:product_name", ProductsController, :destroy
    put "/:product_name", ProductsController, :update
  end
end
