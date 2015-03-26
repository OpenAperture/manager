defmodule ProjectOmeletteManager.GitHub.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.GitHub.Repo
  import ProjectOmeletteManager.GitHub

  setup do
    :meck.new System, [:unstick, :passthrough]

    repo = %Repo{
      local_repo_path: "/tmp/some_random_path",
      remote_url: "https://github.com/test_org/test_project",
      branch: "master"
    }

    on_exit fn -> :meck.unload end

    {:ok, repo: repo}
  end

  test "clone -- success", context do
    repo = context[:repo]
    :meck.expect(System, :cmd, fn command, args, _opts ->
      assert command == "/bin/bash"
      assert "git clone #{repo.remote_url} #{repo.local_repo_path}" in args
      {"cool test message", 0}
    end)

    assert clone(repo) == :ok
  end

  test "clone -- error", context do
    repo = context[:repo]

    :meck.expect(System, :cmd, 3, {"oh no!", 1})
    {result, _msg} = clone(repo)
    assert :error == result
  end

  test "add_all -- success", context do
    repo = context[:repo]
    path = "cool_folder"

    :meck.expect(System, :cmd, fn command, args, _opts ->
      assert command == "/bin/bash"
      assert "git add -A #{path}" in args
      {"cool success message", 0}
    end)

    assert add_all(repo, path) == :ok
  end

  test "add_all -- failure", context do
    repo = context[:repo]
    path = "cool_folder"

    :meck.expect(System, :cmd, 3, {"oh no!", 1})

    {result, _msg} = add_all(repo, path)
    assert result == :error
  end

  test "commit -- sucess", context do
    repo = context[:repo]
    message = "cool commit message"
    :meck.expect(System, :cmd, fn command, args, _opts ->
      assert command == "/bin/bash"
      assert "git commit -m \"#{message}\"" in args
      {"cool success message", 0}
    end)

    assert commit(repo, message) == :ok
  end

  test "commit -- failure", context do
    repo = context[:repo]

    :meck.expect(System, :cmd, 3, {"oh no!", 1})

    {result, _msg} = commit(repo, "cool commit message")
    assert :error == result
  end

  test "push -- success", context do
    repo = context[:repo]

    :meck.expect(System, :cmd, fn command, args, _opts ->
      assert command == "/bin/bash"
      assert "git push" in args
      {"cool success message", 0}
    end)

    assert push(repo) == :ok
  end

  test "push -- failure", context do
    repo = context[:repo]
    :meck.expect(System, :cmd, 3, {"oh no!", 1})

    {result, _msg} = push(repo)
    assert :error == result
  end

  test "get_project_name from repo", context do
    repo = context[:repo]

    assert get_project_name(repo) == "test_project"
  end

  test "get_project_name from https url" do
    assert get_project_name("https://github.com/some_user/test_project") == "test_project"
  end

  test "get_project_name from ssh url" do
    assert get_project_name("git@github.com:some_user/test_project.git") == "test_project.git"
  end
end