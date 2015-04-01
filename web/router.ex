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

  pipeline :secure do
    plug ProjectOmeletteManager.Plugs.Authentication
  end

  scope "/", ProjectOmeletteManager do
    pipe_through :browser # Use the default browser stack
    get "/", PageController, :index
    #Server Statuses
    get "/status", StatusController, :index

  end

  scope "/clusters", ProjectOmeletteManager do
    pipe_through :api
    pipe_through :secure
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
    pipe_through :secure

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
    pipe_through :secure

    get "/", ProductsController, :index
    post "/", ProductsController, :create

    scope "/:product_name" do
      get "/", ProductsController, :show
      delete "/", ProductsController, :destroy
      put "/", ProductsController, :update

      scope "/clusters" do
        get "/", ProductClustersController, :index
        post "/", ProductClustersController, :create
        delete "/", ProductClustersController, :destroy
      end

      scope "/components" do
        get "/", ProductComponentsController, :index
        post "/", ProductComponentsController, :create
        delete "/", ProductComponentsController, :destroy

        get "/:component_name", ProductComponentsController, :show
        put "/:component_name", ProductComponentsController, :update
        delete "/:component_name", ProductComponentsController, :destroy_component
      end

      scope "/deployment_plans" do
        get "/", ProductDeploymentPlansController, :index
        post "/", ProductDeploymentPlansController, :create
        delete "/", ProductDeploymentPlansController, :destroy_all_plans

        scope "/:plan_name" do
          get "/", ProductDeploymentPlansController, :show
          put "/", ProductDeploymentPlansController, :update
          delete "/", ProductDeploymentPlansController, :destroy_plan

          scope "/steps" do
            get "/", ProductDeploymentPlanStepsController, :index
            post "/", ProductDeploymentPlanStepsController, :create
            delete "/", ProductDeploymentPlanStepsController, :destroy
          end
        end
      end

      scope "/environments" do
        get "/", ProductEnvironmentsController, :index
        post "/", ProductEnvironmentsController, :create

        scope "/:environment_name" do
          get "/", ProductEnvironmentsController, :show
          put "/", ProductEnvironmentsController, :update
          delete "/", ProductEnvironmentsController, :destroy

          scope "/variables" do
            get "/", ProductEnvironmentalVariablesController, :index_environment
            post "/", ProductEnvironmentalVariablesController, :create_environment

            get "/:variable_name", ProductEnvironmentalVariablesController, :show_environment
            put "/:variable_name", ProductEnvironmentalVariablesController, :update_environment
            delete "/:variable_name", ProductEnvironmentalVariablesController, :destroy_environment
          end
        end
      end

      scope "/environmental_variables" do
        get "/", ProductEnvironmentalVariablesController, :index_default
        post "/", ProductEnvironmentalVariablesController, :create_default

        get "/:variable_name", ProductEnvironmentalVariablesController, :show_default
        put "/:variable_name", ProductEnvironmentalVariablesController, :update_default
        delete "/:variable_name", ProductEnvironmentalVariablesController, :destroy_default
      end

      scope "/deployments" do
        get "/", ProductDeploymentsController, :index
        post "/", ProductDeploymentsController, :create

        get "/:deployment_id", ProductDeploymentsController, :show
        get "/:deployment_id/steps", ProductDeploymentsController, :index_steps
        delete "/:deployment_id", ProductDeploymentsController, :destroy
      end
    end
  end

  scope "/workflows", ProjectOmeletteManager.Web.Controllers do
    pipe_through :api
    pipe_through :secure

    get "/", WorkflowController, :index
    post "", WorkflowController, :create

    get "/:id", WorkflowController, :show
    put "/:id", WorkflowController, :update
    delete "/:id", WorkflowController, :destroy
  end  
end
