defmodule ProjectOmeletteManager.DB.Models.BaseModel do

  defmacro __using__(_opts) do
  	quote do
	  	use Ecto.Model
		
      def new(params \\ %{}) do
        changeset(struct(__MODULE__), params)
      end

  		def changeset(model_or_changeset, params \\ %{}) do
	    	IO.puts ""
        IO.inspect model_or_changeset
        IO.puts ""
        ret =  cast(model_or_changeset, params, @required_fields, @optional_fields)
        IO.puts ""
        IO.inspect ret
        IO.puts ""
	    	ret = validate_member_of(ret, params, @member_of_fields)
        IO.puts ""
        IO.inspect ret
        IO.puts ""
        ret
  		end

  		defp validate_member_of(model_or_changeset, params, []), do: model_or_changeset
  		defp validate_member_of(model_or_changeset, params, [{member_of_field, allowed_values} | tail]) do
  			ret = validate_inclusion(model_or_changeset, member_of_field, allowed_values)
  			validate_member_of(ret, params, tail)
  		end
  	end
  end
end