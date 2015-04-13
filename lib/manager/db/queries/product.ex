defmodule OpenAperture.Manager.DB.Queries.Product do
  alias OpenAperture.Manager.DB.Models.Product
  import Ecto.Query  

  def get_by_name(name) do
    from p in Product,
      where: fragment("lower(?) = lower(?)", p.name, ^name),
      select: p
  end
end