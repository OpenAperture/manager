defmodule ProjectOmeletteManager.DB.Models.BaseModel do

  defmacro __using__(_opts) do
    quote do
      use Ecto.Model
      use Behaviour

      def new(params) do
        validate_changes(struct(__MODULE__), params)
      end

      @doc "validates changes for insert or update"
      defcallback validate_changes(Ecto.Model.t | Ecto.Changeset.t, %{binary => term} | %{atom => term} | nil) :: Ecto.Changeset.t

    end
  end
end