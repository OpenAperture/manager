defmodule DB.Queries.User.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager
  alias Manager.Repo
  alias Manager.DB.Models.User

  @user_params %{first_name: "Jennifer", last_name: "Dee", email: "jdee@mail.com"}

  setup do
    on_exit fn -> Repo.delete_all(User) end
  end

  test "user can be created fine" do
    users_before = Repo.all(User) |> Enum.count
    User.new(@user_params) |> Repo.insert!
    users_after = Repo.all(User) |> Enum.count

    assert users_after == (users_before + 1)
  end

  test "first_name and last_name are required" do
    changeset = User.new %{email: "jdee@mail.com"}

    refute changeset.valid?
    assert changeset.errors[:first_name] == "can't be blank"
    assert changeset.errors[:last_name]  == "can't be blank"
  end

  test "first_name and last_name can't be blank" do
    changeset = User.new %{first_name: "", last_name: "", email: "jdee@mail.com"}

    refute changeset.valid?
    assert changeset.errors[:first_name] == {"should be at least %{count} characters", 1}
    assert changeset.errors[:last_name]  == {"should be at least %{count} characters", 1}
  end

  test "email must be valid" do
    changeset = User.new %{@user_params | email: "jdee&mail.com"}

    refute changeset.valid?
    assert changeset.errors[:email] == "has invalid format"
  end

  test "emails must be unique" do
    changeset = User.new(@user_params)
    Repo.insert!(changeset)

    assert_raise Postgrex.Error,
    "ERROR (unique_violation): duplicate key value violates unique constraint \"users_email_index\"",
    fn -> Repo.insert!(changeset) end
  end
end
