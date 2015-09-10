defmodule OpenAperture.Manager do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Start the endpoint when the application starts
      supervisor(OpenAperture.Manager.Endpoint, []),
      # Here you could define other workers and supervisors as children
      # worker(OpenAperture.Manager.Worker, [arg1, arg2, arg3]),
      worker(OpenAperture.Manager.Repo, []),
      worker(ConCache, [[], [name: :exchange_models_for_publisher]]),
      worker(OpenAperture.Manager.ResourceCache.Registry, []),
      worker(OpenAperture.Manager.OverseerApi.ModuleRegistration, []),
      worker(OpenAperture.Manager.OverseerApi.Heartbeat, []),
      worker(OpenAperture.Manager.Messaging.RpcRequestsCleanup, []),
      worker(OpenAperture.Manager.Messaging.FleetManagerPublisher, []),
      worker(OpenAperture.Manager.BuildLogMonitor, []),
      #explicilty start just the OverseerApi publisher for publishing SystemComponent upgrades
      worker(OpenAperture.OverseerApi.Publisher, []),
      worker(OpenAperture.Manager.Notifications.Publisher, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OpenAperture.Manager.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    OpenAperture.Manager.Endpoint.config_change(changed, removed)
    :ok
  end
end
