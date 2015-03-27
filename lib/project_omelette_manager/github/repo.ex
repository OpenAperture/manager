defmodule ProjectOmeletteManager.GitHub.Repo do
  defstruct local_repo_path: nil, remote_url: nil, branch: nil

  alias ProjectOmeletteManager.GitHub

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

  @spec get_github_repo_url(String.t) :: String.t
  def get_github_repo_url(relative_repo) do
    GitHub.get_github_url <> relative_repo <> ".git"
  end
end