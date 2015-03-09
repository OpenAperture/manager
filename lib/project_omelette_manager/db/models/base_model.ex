defmodule ProjectOmeletteManager.DB.Models.BaseModel do

  defmacro __using__(_opts) do
  	quote do
	  	use Ecto.Model
		
      def new(params \\ nil) do
        changeset(%__MODULE__{}, params)
      end

  		def changeset(model_or_changeset, params \\ nil) do
	    	ret =  cast(model_or_changeset, params, @required_fields, @optional_fields)
	    	validate_member_of(ret, params, @member_of_fields)
  		end

  		defp validate_member_of(model_or_changeset, params, []), do: model_or_changeset
  		defp validate_member_of(model_or_changeset, params, [{member_of_field, allowed_values} | tail]) do
  			ret = validate_inclusion(model_or_changeset, member_of_field, allowed_values)
  			validate_member_of(ret, params, tail)
  		end
  	end
  end
end