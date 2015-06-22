defmodule DB.Models.User.Test do
  use ExUnit.Case, async: false
  use ExCheck

  alias OpenAperture.Manager
  alias Manager.Repo
  alias Manager.DB.Queries.User, as: UserQuery
  alias Manager.DB.Models.User

  @user_params %{first_name: "Jennifer", last_name: "Dee", email: "jdee@mail.com"}

  setup do
    on_exit fn -> Repo.delete_all(User) end
  end

  defp insert_user(params) do
    if UserQuery.get_by_email(params.email) |> Repo.one do
      true
    else
      User.new(params)
      |> Repo.insert
      |> is_map
    end
  end

  property :inserts_users_fine do
    for_all x in int do
      address = to_string(x) <> "test@mail.com"
      insert_user(%{@user_params | email: address})
    end
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

  def fails_with_invalid_email do
    for_all x in int do
      invalid_email = @user_params.email <> to_string(x)
      insert_user(%{@user_params | email: invalid_email})
      when_fail nil, do: true
    end
  end

  test "insertion fails with invalid email in changeset" do
    error_msg = "error raised: (Elixir.ArgumentError) cannot insert/update an invalid changeset"
    assert_raise ExCheck.Error, error_msg, fn ->
      ExCheck.check(fails_with_invalid_email)
    end
  end

  test "emails must be unique" do
    changeset = User.new(@user_params)
    Repo.insert(changeset)

    assert_raise Postgrex.Error,
    "ERROR (unique_violation): duplicate key value violates unique constraint \"users_email_index\"",
    fn -> Repo.insert(changeset) end
  end
end
