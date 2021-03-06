defmodule DB.Models.MessagingExchangeBroker.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.DB.Models.MessagingExchangeBroker
  alias OpenAperture.Manager.Repo

  setup _context do
    on_exit _context, fn ->
      Repo.delete_all(MessagingExchangeBroker)
    end
  end

  test "required fields" do
    changeset = MessagingExchangeBroker.new(%{})

    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :messaging_exchange_id)
    assert Keyword.has_key?(changeset.errors, :messaging_broker_id)
  end
end