defmodule DB.Models.MessagingBrokerConnection.Test do
  use ExUnit.Case, async: false

  alias ProjectOmeletteManager.DB.Models.MessagingBroker
  alias ProjectOmeletteManager.DB.Models.MessagingBrokerConnection
  alias ProjectOmeletteManager.Repo

  setup _context do
    on_exit _context, fn ->
      Repo.delete_all(MessagingBrokerConnection)
      Repo.delete_all(MessagingBroker)
    end
  end

  test "required fields" do
    changeset = MessagingBrokerConnection.new(%{})

    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :username)
    assert Keyword.has_key?(changeset.errors, :password)
    assert Keyword.has_key?(changeset.errors, :host)
  end
end