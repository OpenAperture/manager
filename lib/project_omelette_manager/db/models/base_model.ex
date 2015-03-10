defmodule ProjectOmeletteManager.DB.Models.BaseModel do

  defmacro __using__(_opts) do
  	quote do
	  	use Ecto.Model

      def changeset(model_or_changeset, params \\ %{}) do
        ret =  cast(model_or_changeset, params, @required_fields, @optional_fields)
	    	validate_member_of(ret, params, @member_of_fields)
  		end

  		defp validate_member_of(model_or_changeset, params, []), do: model_or_changeset
  		defp validate_member_of(model_or_changeset, params, [{member_of_field, allowed_values} | tail]) do
        IO.puts "validating #{member_of_field} is one of #{inspect allowed_values}"
  			ret = validate_inclusion(model_or_changeset, member_of_field, allowed_values)
        IO.inspect ret
  			validate_member_of(ret, params, tail)
  		end

      def vinsert(model) do
        my_changeset = changeset(model)
        case my_changeset.valid? do
          true ->  {:ok, ProjectOmeletteManager.Repo.insert(model)}
          false -> {:error, my_changeset.errors}
        end
      end
  	end
  end
end