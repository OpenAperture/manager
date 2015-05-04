defmodule Mix.Tasks.Swagger do
  use Mix.Task

  @shortdoc "Generates Swagger JSON"

  @moduledoc """	
	Generates Swagger JSON
  """  

  def run(args) do
    Mix.shell.info "Generating Swagger documentation..."
    router = get_router(args)
    json = build_swagger_response(router)

    output_path = System.cwd!() <> "/swagger"
    File.mkdir_p!(output_path)
    File.write!("#{output_path}/api.json", Poison.encode!(json))
    Mix.shell.info "Finished generating Swagger documentation!"
  end

  defp get_router(args) do
    cond do
      router = Enum.at(args, 0) ->
        Module.concat("Elixir", router)
      Mix.Project.umbrella? ->
        Mix.raise "Umbrella applications require an explicit router to be given to phoenix.routes"
      true ->
        Module.concat(Mix.Phoenix.base(), "Router")
    end
  end  

  defp build_swagger_response(router) do
 	  	swagger = %{
  		swagger: "2.0",
  		info: %{
    		version: "1.0.0",
    		title: "OpenAperture Manager",
    		description: "The REST API for the OpenAperture Manager",
    		termsOfService: "https://github.com/OpenAperture/manager/blob/master/LICENSE",
    		contact: %{
      		name: "",
      		email: "",
      		url: "http://openaperture.io"
    		},
    		license: %{
      	name: "Mozilla Public License, v. 2.0",
      	url: "https://github.com/OpenAperture/manager/blob/master/LICENSE"
    		}
  		},
  		host: "openaperture.io",
  		basePath: "/",
  		schemes: [
  		  "https"
  	  ],
  	  consumes: [
    		"application/json"
  		],
  		produces: [
    		"application/json"
  		],
  		paths: %{}
  	}

  	routes = router.__routes__
  	if routes == nil do
  		swagger
  	else
  		Enum.reduce routes, swagger, fn (route, swagger) ->
  			path = swagger[:paths][route.path]
  			if path == nil do
  				path = %{}
  			end

  			verb_string = String.downcase(route.verb)
  			verb = %{
  				description: ""	,
  				operationId: "",
  				produces: [
  					"application/json"
  				],
  				parameters: [
  				],
  				responses: [
  				]
  			}
  			path = Map.put(path, verb_string, verb)
  			paths = Map.put(swagger[:paths], route.path, path)
  			Map.put(swagger, :paths, paths)
  		end
  	end
  end
end