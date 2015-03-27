defmodule ProjectOmeletteManager.GitHub.Repo do
  @moduledoc """
  This module represents a Git repository, and is used to track the local
  repository's path, the remote repository's URL, and the current
  branch/tag/commit.
  """
  defstruct local_repo_path: nil, remote_url: nil, branch: nil

  @type t :: %__MODULE__{local_repo_path: String.t, remote_url: String.t, branch: String.t}

  alias ProjectOmeletteManager.GitHub

  @doc """
  Extracts the project name from a GitHub repo URL.

  ## Examples

    iex> ProjectOmeletteManager.GitHub.Repo.get_project_name("https://github.com/test_user/test_project")
    "test_project"
  """
  @spec get_project_name(String.t) :: String.t
  def get_project_name(repo_url) when is_binary(repo_url) do
    uri = URI.parse(repo_url)

    uri.path
    |> String.split("/")
    |> List.last
  end

  @spec get_project_name(Repo.t) :: String.t
  def get_project_name(repo) when is_map(repo) do
    repo.remote_url
    |> get_project_name
  end

  @doc """
  Given a [user|org]/project_name string, builds a GitHub URL. Prepends OAuth
  access credentials to the URL (if configured for the application.)

  ## Examples

    iex> ProjectOmeletteManager.GitHub.Repo.get_github_repo_url("test_user/test_project")
    "https://github.com/test_user/test_project.git"
  """
  @spec get_github_repo_url(String.t) :: String.t
  def get_github_repo_url(relative_repo) do
    GitHub.get_github_url <> relative_repo <> ".git"
  end
end