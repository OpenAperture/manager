defmodule ProjectOmeletteManager.DB.Models.BaseModel do

  defmacro __using__(_opts) do
    quote do
      use Ecto.Model
      use Behaviour

      @type params :: %{binary => any} | %{atom => any} | nil

      @spec new(params) :: Ecto.Changeset.t
      def new(params) do
        validate_changes(struct(__MODULE__), params)
      end

      @spec update(Ecto.Model.t, params) :: Ecto.Changeset.t
      def update(model, params) do
        validate_changes(model, params)
      end

      @doc "validates changes for insert or update"
      defcallback validate_changes(Ecto.Model.t | Ecto.Changeset.t, params) :: Ecto.Changeset.t

    end
  end
end