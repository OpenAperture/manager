defmodule ProjectOmeletteManager.GitHub do
  require Logger
  alias ProjectOmeletteManager.GitHub.Repo

  @spec get_github_url :: String.t
  def get_github_url() do
    case Application.get_env(:github, :user_credentials) do
      nil -> "https://github.com/"
      creds -> "https://" <> creds <> "@github.com/"
    end
  end

  @spec clone(Repo.t) :: :ok | {:error, String.t}
  def clone(repo) do
    Logger.debug "Attempting to clone GitHub repo: #{repo.remote_url} into #{repo.local_repo_path}"

    clone_command = "git clone " <> repo.remote_url <> " " <> repo.local_repo_path

    case System.cmd("/bin/bash", ["-c", clone_command], [{:stderr_to_stdout, true}]) do
      {message, 0} ->
        Logger.debug "Successfully cloned repository\n#{message}"
        :ok
      {message, code} ->
        error_message = "`git clone` returned #{code}.\n#{message}"
        Logger.error(error_message)
        {:error, error_message}
    end
  end

  @spec add_all(Repo.t, String.t) :: :ok | {:error, String.t}
  def add_all(repo, path) do
    add_command = "git add -A " <> path
    case System.cmd("/bin/bash", ["-c", add_command], [{:cd, repo.local_repo_path}, {:stderr_to_stdout, true}]) do
      {message, 0} ->
        Logger.debug "Successfully performed `git add all`\n#{message}"
        :ok
      {message, code} ->
        error_message = "`git add all` returned #{code}.\n#{message}"
        Logger.error(error_message)
        {:error, error_message}
    end
  end

  @spec commit(Repo.t, String.t) :: :ok | {:error, String.t}
  def commit(repo, message) do
    commit_command = "git commit -m \"" <> message <> "\""
    case System.cmd("/bin/bash", ["-c", commit_command], [{:cd, repo.local_repo_path}, {:stderr_to_stdout, true}]) do
      {message, 0} ->
        Logger.debug "Successfully performed `git commit`\n#{message}"
        :ok
      {message, code} ->
        error_message = "`git commit` returned #{code}.\n#{message}"
        Logger.error(error_message)
        {:error, error_message}
    end
  end

  @spec push(Repo.t) :: :ok | {:error, String.t}
  def push(repo) do
    case System.cmd("/bin/bash", ["-c", "git push"], [{:cd, repo.local_repo_path}, {:stderr_to_stdout, true}]) do
      {message, 0} ->
        Logger.debug "Successfully performed `git push`\n#{message}"
        :ok
      {message, code} ->
        error_message = "`git push` returned #{code}.\n#{message}"
        Logger.error(error_message)
        {:error, error_message}
    end
  end
end