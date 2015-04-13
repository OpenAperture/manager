defmodule OpenAperture.Manager.GitHub do
  @moduledoc """
  This module contains functions used for interacting with a git repository,
  specifically in the context of one cloned from GitHub.
  """

  require Logger
  alias OpenAperture.Manager.GitHub.Repo

  @doc """
  Retrieves the base GitHub URL, including an OAuth credential if one is set
  in the application's configuration.
  """
  @spec get_github_url :: String.t
  def get_github_url() do
    case Application.get_env(:github, :user_credentials) do
      nil -> "https://github.com/"
      creds -> "https://" <> creds <> "@github.com/"
    end
  end

  @doc """
  Clones a remote git repository to a local path.
  """
  @spec clone(Repo.t) :: :ok | {:error, String.t}
  def clone(repo) do
    Logger.debug "Attempting to clone GitHub repo: #{repo.remote_url} into #{repo.local_repo_path}"

    clone_command = "git clone " <> repo.remote_url <> " " <> repo.local_repo_path

    case System.cmd("/bin/bash", ["-c", clone_command], [{:stderr_to_stdout, true}]) do
      {message, 0} ->
        Logger.debug "Successfully cloned repository\n#{message}"
        :ok
      {message, code} ->
        error_message = "An error occurred performing  `git clone` (returned #{code}):\n#{message}"
        Logger.error(error_message)
        {:error, error_message}
    end
  end

  @doc """
  Executes a `git checkout` against a specific branch, tag, or hash.
  """
  @spec checkout(Repo.t) :: :ok | {:error, String.t}
  def checkout(repo) do
    Logger.info("Switching to branch/tag #{repo.branch} in directory #{repo.local_repo_path}...")
    checkout_command = "git checkout " <> repo.branch
    case System.cmd("/bin/bash", ["-c", checkout_command], [{:cd, repo.local_repo_path}, {:stderr_to_stdout, true}]) do
      {message, 0} ->
        Logger.debug "Successfully performed `git checkout`\n#{message}"
        :ok
      {message, code} ->
        error_message = "An error occurred performing `git checkout` (returned #{code}):\n#{message}"
        Logger.error(error_message)
        {:error, error_message}
    end
  end

  @doc """
  Stages a file to the local git repository.
  """
  @spec add(Repo.t, String.t) :: :ok | {:error, String.t}
  def add(repo, path) do
    Logger.info("Staging file #{path} for commit...")
    add_command = "git add " <> path
    case System.cmd("/bin/bash", ["-c", add_command], [{:cd, repo.local_repo_path}, {:stderr_to_stdout, true}]) do
      {message, 0} ->
        Logger.debug "Successfully performed `git add`\n#{message}"
        :ok
      {message, code} ->
        error_message = "An error occurred performing `git add` (returned #{code}):\n#{message}"
        Logger.error(error_message)
        {:error, error_message}
    end
  end

  @doc """
  Executes a git add -A for a directory.
  """
  @spec add_all(Repo.t, String.t) :: :ok | {:error, String.t}
  def add_all(repo, path) do
    add_command = "git add -A " <> path
    case System.cmd("/bin/bash", ["-c", add_command], [{:cd, repo.local_repo_path}, {:stderr_to_stdout, true}]) do
      {message, 0} ->
        Logger.debug "Successfully performed `git add all`\n#{message}"
        :ok
      {message, code} ->
        error_message = "An error occurred performing  `git add all` (returned #{code}):\n#{message}"
        Logger.error(error_message)
        {:error, error_message}
    end
  end

  @doc """
  Executes a git commit for the local repository.
  """
  @spec commit(Repo.t, String.t) :: :ok | {:error, String.t}
  def commit(repo, message) do
    commit_command = "git commit -m \"" <> message <> "\""
    case System.cmd("/bin/bash", ["-c", commit_command], [{:cd, repo.local_repo_path}, {:stderr_to_stdout, true}]) do
      {message, 0} ->
        Logger.debug "Successfully performed `git commit`\n#{message}"
        :ok
      {message, code} ->
        error_message = "An error occurred performing `git commit` (returned #{code}):\n#{message}"
        Logger.error(error_message)
        {:error, error_message}
    end
  end

  @doc """
  Executes a git push for a local repository. Uses the default remote.
  """
  @spec push(Repo.t) :: :ok | {:error, String.t}
  def push(repo) do
    case System.cmd("/bin/bash", ["-c", "git push"], [{:cd, repo.local_repo_path}, {:stderr_to_stdout, true}]) do
      {message, 0} ->
        Logger.debug "Successfully performed `git push`\n#{message}"
        :ok
      {message, code} ->
        error_message = "An error occurred performing `git push` (returned #{code}):\n#{message}"
        Logger.error(error_message)
        {:error, error_message}
    end
  end
end