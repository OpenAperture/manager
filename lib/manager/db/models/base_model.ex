defmodule OpenAperture.Manager.DB.Models.BaseModel do

  defmacro __using__(_opts) do
    quote do
      use Ecto.Model
      use Behaviour
      alias OpenAperture.Manager.Repo

      @type params :: %{binary => any} | %{atom => any} | nil

      @spec new(params) :: Ecto.Changeset.t
      def new(params \\ %{}) do
        validate_changes(struct(__MODULE__), params)
      end

      @spec update(Ecto.Model.t, params) :: Ecto.Changeset.t
      def update(model, params) do
        validate_changes(model, params)
      end

      @spec destroy_for_association(Ecto.Model.t, atom) :: any | nil
      def destroy_for_association(model, assoc_atom) do
        assoc(model, assoc_atom)
        |> Repo.all
        |> Enum.map &destroy(&1)
        :ok
      end

      def transaction_return(tr) do
        case tr do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
      end
      
      defcallback destroy(Ecto.Model.t)

      @doc "validates changes for insert or update"
      defcallback validate_changes(Ecto.Model.t | Ecto.Changeset.t, params) :: Ecto.Changeset.t
      defcallback validate_changes(Ecto.Model.t | Ecto.Changeset.t, params) :: Ecto.Changeset.t

    end
  end
end