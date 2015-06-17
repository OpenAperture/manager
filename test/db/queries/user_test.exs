defmodule DB.Queries.User.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager
  alias Manager.Repo
  alias Manager.DB.Models.User
  alias Manager.DB.Queries.User, as: UserQuery

  @user_params %{first_name: "Josh", last_name: "Downey", email: "jdowney@mail.com"}

  setup_all do
    user = User.new(@user_params) |> Repo.insert
    on_exit fn -> Repo.delete_all(User) end

    {:ok, %{user: user}}
  end

  test "get user by email", %{user: user} do
    [result] = UserQuery.get_by_email(user.email) |> Repo.all

    assert result == user
  end
end
