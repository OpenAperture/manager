defmodule ProjectOmeletteManager.DB.Queries.Product do
  alias ProjectOmeletteManager.DB.Models.Product
  import Ecto.Query  

  def get_by_name(name) do
    from p in Product,
      where: fragment("downcase(?) == downcase(?)", p.name, ^name),
      select: p
  end
end