defmodule DB.Models.MessagingExchange.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.DB.Models.MessagingExchange
  alias OpenAperture.Manager.Repo

  setup _context do
    on_exit _context, fn ->
      Repo.delete_all(MessagingExchange)
    end
  end

  test "name is required" do
    changeset = MessagingExchange.new(%{})

    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :name)
  end
end