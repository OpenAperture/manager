defmodule DB.Models.MessagingBroker.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.DB.Models.MessagingBroker
  alias OpenapertureManager.Repo

  setup _context do
    on_exit _context, fn ->
      Repo.delete_all(MessagingBroker)
    end
  end

  test "name is required" do
    changeset = MessagingBroker.new(%{id: 1})

    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :name)
  end
end