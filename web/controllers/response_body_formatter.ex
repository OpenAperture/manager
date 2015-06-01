defmodule OpenAperture.Manager.Controllers.ResponseBodyFormatter do

	def error_body(type, item_name) when is_atom(type) do
		%{"errors" => [%{"message" => message_for_type(type, item_name)}]}
	end

	def error_body(explicit_error_message, item_name) when is_binary(explicit_error_message) do
		%{"errors" => [%{"message" => "Internal server error for #{item_name}: #{explicit_error_message}"}]}
	end

	def error_body(changeset_errors, item_name) do
		%{"errors" => [%{"message" => "One or more fields for #{item_name} were invalid"} | sanitize_changeset_errors(changeset_errors)]}
	end

	def sanitize_changeset_errors([]), do: []
	def sanitize_changeset_errors([{key, value} | tail]) do
		error = cond do
			is_binary(value) -> value
			true -> inspect(value)
		end
		[Map.put(%{}, key, error) | sanitize_changeset_errors(tail)]
	end

	def message_for_type(:not_found, item_name), do: "#{item_name} was not found"
	def message_for_type(:internal_server_error, item_name), do: "An unexpected error occured with #{item_name}"
	def message_for_type(:conflict, item_name), do: "A #{item_name} already exists with that identifier"
	def message_for_type(:bad_request, item_name), do: "An invalid request was made for #{item_name}"

end