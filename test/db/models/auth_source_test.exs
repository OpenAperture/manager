defmodule DB.Models.AuthSource.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.DB.Models.AuthSource
  alias OpenAperture.Manager.DB.Models.AuthSourceUserRelation
  alias OpenAperture.Manager.DB.Models.User
  alias OpenAperture.Manager.Repo

  setup do
    on_exit fn ->
      Repo.delete_all(AuthSourceUserRelation)
      Repo.delete_all(AuthSource)
      Repo.delete_all(User)
    end
  end

  test "can load associated users through has_many relation" do
    auth_source = AuthSource.new(%{token_info_url: "http://test/token", email_field_name: "email"})
                  |> Repo.insert

    user1 = User.new(%{first_name: "test", last_name: "user", email: "test.user@test.com"})
            |> Repo.insert

    user2 = User.new(%{first_name: "test2", last_name: "user2", email: "test2.user2@test.com"})
            |> Repo.insert

    _relation1 = AuthSourceUserRelation.new(%{auth_source_id: auth_source.id, user_id: user1.id})
                |> Repo.insert

    _relation2 = AuthSourceUserRelation.new(%{auth_source_id: auth_source.id, user_id: user2.id})
                |> Repo.insert

    users = Ecto.Model.assoc(auth_source, :users)
            |> Repo.all

    assert length(users) == 2
    assert user1 in users
    assert user2 in users
  end
end