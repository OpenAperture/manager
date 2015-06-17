defmodule OpenAperture.Manager.DB.Queries.User do
  alias OpenAperture.Manager.DB.Models.User
  import Ecto.Query

  def get_by_email(address) do
    from u in User,
      where:  fragment("lower(?) = lower(?)", u.email, ^address),
      select: u
  end
end
