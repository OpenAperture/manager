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
      		name: "OpenAperture",
      		email: "openaperture@lexmark.com",
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

    add_routes(router.__routes__, swagger)
  end

  def add_routes(nil, swagger), do: swagger
  def add_routes([], swagger), do: swagger
  def add_routes([route | remaining_routes], swagger) do
    swagger_path = path_from_route(String.split(route.path, "/"), nil)
    IO.puts("original :  #{route.path}.  new path:  #{swagger_path}")

    path = swagger[:paths][swagger_path]
    if path == nil do
      path = %{}
    end

    func_name = "swaggerdoc_#{route.opts}"
    verb = if Keyword.has_key?(route.controller.__info__(:functions), String.to_atom(func_name)) do
      apply(route.controller, String.to_atom(func_name), [])
    else
      default_verb(route.path)
    end

    verb_string = String.downcase(route.verb)
    if verb[:responses] == nil do
      verb = Map.put(verb, :responses, default_responses(verb_string))
    end

    if verb[:produces] == nil do
      verb = Map.put(verb, :produces, ["application/json"])
    end

    if verb[:operationId] == nil do
      verb = Map.put(verb, :operationId, "#{route.opts}")
    end

    if verb[:description] == nil do
      verb = Map.put(verb, :description, "")
    end

    path = Map.put(path, verb_string, verb)
    paths = Map.put(swagger[:paths], swagger_path, path)
    add_routes(remaining_routes, Map.put(swagger, :paths, paths))
  end

  #paths must enclose params with braces {var}, rather than :var (http://swagger.io/specification/#pathTemplating)
  def path_from_route([], swagger_path), do: swagger_path
  def path_from_route([path_segment | remaining_segments], swagger_path) do 
    path_from_route(remaining_segments, cond do
      path_segment == nil || String.length(path_segment) == 0 -> swagger_path
      swagger_path == nil -> "/#{path_segment}"
      String.first(path_segment) == ":" -> "#{swagger_path}/{#{String.slice(path_segment, 1..String.length(path_segment))}}"
      true -> "#{swagger_path}/#{path_segment}"
    end)
  end

  def default_verb(path) do
    parameters = Enum.reduce String.split(path, "/"), [], fn(path_segment, parameters) ->
      if String.first(path_segment) == ":" do

        #http://swagger.io/specification/#parameterObject
        parameter = %{
          "name" => String.slice(path_segment, 1..String.length(path_segment)),
          "in" => "path",
          "description" => "",
          "required" => true,
          "type" => "string"
        }

        #assumes all params named "id" are integers
        if parameter["name"] == "id" do
          parameter = Map.put(parameter, "type", "integer")
        end

        parameters ++ [parameter]
      else
        parameters
      end
    end   
   
    %{
       parameters: parameters,
     }
  end

  def default_responses(verb_string) do
    responses = %{
      "404" => %{"description" => "Resource not found"}, 
      "401" => %{"description" => "Request is not authorized"}, 
      "500" => %{"description" => "Internal Server Error"}
    }
    case verb_string do
      "get" -> Map.merge(responses, %{"200" => %{"description" => "Resource Content"}})
      "delete" -> Map.merge(responses, %{"204" => %{"description" => "Resource deleted"}})
      "post" -> Map.merge(responses, %{"201" => %{"description" => "Resource created"}, "400" => %{"description" => "Request contains bad values"}})
      "put" -> Map.merge(responses, %{"204" => %{"description" => "Resource deleted"}, "400" => %{"description" => "Request contains bad values"}})
      _ -> responses
    end    
  end
end