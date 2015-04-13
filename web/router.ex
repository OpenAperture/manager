defmodule OpenAperture.Manager.Router do
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
    plug OpenAperture.Manager.Plugs.Authentication
  end

  scope "/", OpenAperture.Manager.Controllers do
    pipe_through :browser # Use the default browser stack
    #Server Statuses
    get "/status", Status, :index

  end

  scope "/clusters", OpenAperture.Manager.Controllers do
    pipe_through :api
    pipe_through :secure
    get "/", EtcdClusters, :index
    post "/", EtcdClusters, :register

    get "/:etcd_token", EtcdClusters, :show
    delete "/:etcd_token", EtcdClusters, :destroy
    get "/:etcd_token/products", EtcdClusters, :products
    get "/:etcd_token/machines", EtcdClusters, :machines
    get "/:etcd_token/units", EtcdClusters, :units
    get "/:etcd_token/state", EtcdClusters, :units_state
    get "/:etcd_token/machines/:machine_id/units/:unit_name/logs", EtcdClusters, :unit_logs
  end

  scope "/messaging", OpenAperture.Manager.Controllers do
    pipe_through :api
    pipe_through :secure

    scope "/brokers" do
      get "/", MessagingBrokers, :index
      post "/", MessagingBrokers, :create

      get "/:id", MessagingBrokers, :show
      put "/:id", MessagingBrokers, :update
      delete "/:id", MessagingBrokers, :destroy

      get "/:id/connections", MessagingBrokers, :get_connections
      post "/:id/connections", MessagingBrokers, :create_connection
      delete "/:id/connections", MessagingBrokers, :destroy_connections
    end

    scope "/exchanges" do
      get "/", MessagingExchanges, :index
      post "/", MessagingExchanges, :create

      get "/:id", MessagingExchanges, :show
      put "/:id", MessagingExchanges, :update
      delete "/:id", MessagingExchanges, :destroy

      get "/:id/brokers", MessagingExchanges, :get_broker_restrictions
      post "/:id/brokers", MessagingExchanges, :create_broker_restriction
      delete "/:id/brokers", MessagingExchanges, :destroy_broker_restrictions

      get "/:id/clusters", MessagingExchanges, :show_clusters
    end
  end

  scope "/products", OpenAperture.Manager.Controllers do
    pipe_through :api
    pipe_through :secure

    get "/", Products, :index
    post "/", Products, :create

    scope "/:product_name" do
      get "/", Products, :show
      delete "/", Products, :destroy
      put "/", Products, :update

      scope "/clusters" do
        get "/", ProductClusters, :index
        post "/", ProductClusters, :create
        delete "/", ProductClusters, :destroy
      end

      scope "/components" do
        get "/", ProductComponents, :index
        post "/", ProductComponents, :create
        delete "/", ProductComponents, :destroy

        get "/:component_name", ProductComponents, :show
        put "/:component_name", ProductComponents, :update
        delete "/:component_name", ProductComponents, :destroy_component
      end

      scope "/deployment_plans" do
        get "/", ProductDeploymentPlans, :index
        post "/", ProductDeploymentPlans, :create
        delete "/", ProductDeploymentPlans, :destroy_all_plans

        scope "/:plan_name" do
          get "/", ProductDeploymentPlans, :show
          put "/", ProductDeploymentPlans, :update
          delete "/", ProductDeploymentPlans, :destroy_plan

          scope "/steps" do
            get "/", ProductDeploymentPlanSteps, :index
            post "/", ProductDeploymentPlanSteps, :create
            delete "/", ProductDeploymentPlanSteps, :destroy
          end
        end
      end

      scope "/environments" do
        get "/", ProductEnvironments, :index
        post "/", ProductEnvironments, :create

        scope "/:environment_name" do
          get "/", ProductEnvironments, :show
          put "/", ProductEnvironments, :update
          delete "/", ProductEnvironments, :destroy

          scope "/variables" do
            get "/", ProductEnvironmentalVariables, :index_environment
            post "/", ProductEnvironmentalVariables, :create_environment

            get "/:variable_name", ProductEnvironmentalVariables, :show_environment
            put "/:variable_name", ProductEnvironmentalVariables, :update_environment
            delete "/:variable_name", ProductEnvironmentalVariables, :destroy_environment
          end
        end
      end

      scope "/environmental_variables" do
        get "/", ProductEnvironmentalVariables, :index_default
        post "/", ProductEnvironmentalVariables, :create_default

        get "/:variable_name", ProductEnvironmentalVariables, :show_default
        put "/:variable_name", ProductEnvironmentalVariables, :update_default
        delete "/:variable_name", ProductEnvironmentalVariables, :destroy_default
      end

      scope "/deployments" do
        get "/", ProductDeployments, :index
        post "/", ProductDeployments, :create

        get "/:deployment_id", ProductDeployments, :show
        get "/:deployment_id/steps", ProductDeployments, :index_steps
        delete "/:deployment_id", ProductDeployments, :destroy
      end
    end
  end

  scope "/workflows", OpenAperture.Manager.Controllers do
    pipe_through :api
    pipe_through :secure

    get "/", Workflows, :index
    post "", Workflows, :create

    get "/:id", Workflows, :show
    put "/:id", Workflows, :update
    delete "/:id", Workflows, :destroy
  end  
end
