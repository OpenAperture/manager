defmodule ProjectOmeletteManager.DB.Models.BaseModel do

  defmacro __using__(_opts) do
    quote do
      use Ecto.Model

      def changeset(model_or_changeset, params \\ %{}) do
        model_or_changeset
          |> cast(params, @required_fields, @optional_fields)
          |> validate_member_of(params, @member_of_fields)
      end

      defp validate_member_of(model_or_changeset, params, []), do: model_or_changeset
      defp validate_member_of(model_or_changeset, params, [{member_of_field, allowed_values} | tail]) do
        model_or_changeset
          |> validate_inclusion(member_of_field, allowed_values)
          |> validate_member_of(params, tail)
      end

      def vinsert(params) do
        my_changeset = changeset(struct(__MODULE__), params)
        case my_changeset.valid? do
          true ->  {:ok, ProjectOmeletteManager.Repo.insert(my_changeset)}
          false -> {:error, my_changeset.errors}
        end
      end
    end
  end
end