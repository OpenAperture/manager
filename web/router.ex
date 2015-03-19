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

  scope "/messaging", ProjectOmeletteManager do
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
  end
end
