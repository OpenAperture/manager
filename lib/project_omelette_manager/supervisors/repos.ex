#
# == repo_supervisor.ex
#
# This module contains the supervisor logic for the ecto repository.
#
# == Contact
#
# Author::    Trantor (trantordevonly@perceptivesoftware.com)
# Copyright:: 2014 Lexmark International Technology S.A.  All rights reserved.
# License::   n/a
#
require Logger

defmodule ProjectOmeletteManager.Supervisors.Repos do
  use Supervisor

  def start_link do
    Logger.info("Starting Repos supervisor...")
    :supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    import Supervisor.Spec

    children = [
      # Define workers and child supervisors to be supervised
      worker(ProjectOmeletteManager.Repo, []),
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    supervise(children, opts)
  end
end