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
    import OpenAperture.Manager.Plugs.Authentication
    plug :fetch_access_token
    plug :authenticate_user, []
    plug :fetch_user, []
  end

  scope "/", OpenAperture.Manager.Controllers do
    pipe_through :browser # Use the default browser stack
    #Server Statuses
    get "/status", Status, :index

  end

  socket "/ws", OpenAperture.Manager do
    pipe_through :secure
    channel "build_log:*", BuildLogChannel
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

      get    "/:id/modules", MessagingExchangeModules, :index
      post   "/:id/modules", MessagingExchangeModules, :create
      get    "/:id/modules/:hostname", MessagingExchangeModules, :show
      delete "/:id/modules/:hostname", MessagingExchangeModules, :destroy

      get "/:id/system_components", MessagingExchanges, :show_components      
    end

    scope "/rpc_requests" do
      get "/", MessagingRpcRequests, :index
      post "/", MessagingRpcRequests, :create

      get "/:id", MessagingRpcRequests, :show
      put "/:id", MessagingRpcRequests, :update
      delete "/:id", MessagingRpcRequests, :destroy
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

            scope "/:step_id" do 
              put "/", ProductDeploymentPlanSteps, :update
              delete "/", ProductDeploymentPlanSteps, :destroy
            end
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
    post "/", Workflows, :create

    get "/:id", Workflows, :show
    put "/:id", Workflows, :update
    delete "/:id", Workflows, :destroy

    post "/:id/execute", Workflows, :execute
  end

  scope "/router", OpenAperture.Manager.Controllers.Router do
    pipe_through :api
    pipe_through :secure

    get "/routes", RoutesController, :index
    get "/routes/deleted", RoutesController, :index_deleted

    get "/authorities/detailed", AuthorityController, :index_detailed
    get "/authorities/:id/detailed", AuthorityController, :show_detailed
    resources "/authorities", AuthorityController

    delete "/authorities/:parent_id/routes/clear", RouteController, :clear
    resources "/authorities/:parent_id/routes", RouteController
  end

  scope "/cloud_providers", OpenAperture.Manager.Controllers do
    pipe_through :api
    pipe_through :secure

    get "/", CloudProviders, :index
    post "/", CloudProviders, :create

    get "/:id", CloudProviders, :show
    put "/:id", CloudProviders, :update
    delete "/:id", CloudProviders, :destroy

    get "/:id/clusters", CloudProviders, :clusters
  end

  scope "/", OpenAperture.Manager.Controllers do
    pipe_through :api
    pipe_through :secure

    resources "users", Users, except: [:new, :edit]
  end

  scope "/system_component_refs", OpenAperture.Manager.Controllers do
    pipe_through :api
    pipe_through :secure

    get "/", SystemComponentRefs, :index
    post "/", SystemComponentRefs, :create

    get "/:type", SystemComponentRefs, :show
    put "/:type", SystemComponentRefs, :update
    delete "/:type", SystemComponentRefs, :destroy
  end

  scope "/system_components", OpenAperture.Manager.Controllers do
    pipe_through :api
    pipe_through :secure

    get "/", SystemComponents, :index
    post "/", SystemComponents, :create

    get "/:id", SystemComponents, :show
    put "/:id", SystemComponents, :update
    delete "/:id", SystemComponents, :destroy
    post "/:id/upgrade", SystemComponents, :upgrade
  end  
end
