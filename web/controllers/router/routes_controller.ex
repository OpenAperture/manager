defmodule OpenAperture.Manager.Controllers.Router.RoutesController do
  use OpenAperture.Manager.Web, :controller

  require Logger

  import Ecto.Query
  import OpenAperture.Manager.Plugs.Params

  alias OpenAperture.Manager.DB.Models.Router.Authority
  alias OpenAperture.Manager.DB.Models.Router.DeletedAuthority
  alias OpenAperture.Manager.DB.Models.Router.Route

  plug :parse_as_integer, {"updated_since", 400}

  # Only fetch routes newer than a particular timestamp
  # GET /router/routes?updated_since=[timestamp]
  def index(conn, %{"updated_since" => updated_since}) do
    ecto_datetime = unix_timestamp_to_ecto_datetime(updated_since)

    routes = Authority
             |> where([a], a.updated_at >= ^ecto_datetime)
             |> join(:inner, [a], r in Route, r.authority_id == a.id)
             |> select([a, r], {a, r})
             |> Repo.all

    json conn, build_response(routes)
  end

  # fetch all routes
  # GET /router/routes
  def index(conn, _params) do
    routes = Authority
             |> join(:inner, [a], r in Route, r.authority_id == a.id)
             |> select([a, r], {a, r})
             |> Repo.all

    json conn, build_response(routes)
  end

  # GET /router/routes/deleted?updated_since=[timestamp]
  def index_deleted(conn, %{"updated_since" => updated_since}) do
    ecto_datetime = unix_timestamp_to_ecto_datetime(updated_since)

    deleted = DeletedAuthority
              |> where([da], da.updated_at >= ^ecto_datetime)
              |> Repo.all

    specs = deleted
            |> Enum.map(fn da -> "#{da.hostname}:#{da.port}" end)
            |> Enum.uniq

    json conn, specs
  end

  # GET /router/routes/deleted
  def index_deleted(conn, _params) do
    deleted = Repo.all(DeletedAuthority)

    specs = deleted
            |> Enum.map(fn da -> "#{da.hostname}:#{da.port}" end)
            |> Enum.uniq

    json conn, specs
  end

  # Converts the list of {authority, route} tuples into a map that can be
  # JSON-encoded for transfer, and then sends the response
  @spec build_response([{Authority.t, Route.t}]) :: Map.t
  defp build_response(routes_list) do
    unix_ts = erlang_timestamp_to_unix(:os.timestamp)

    routes_list
    |> routes_to_map
    |> Map.put(:timestamp, unix_ts)
  end

  @spec routes_to_map([{Authority.t, Route.t}]) :: Map.t
  defp routes_to_map(routes) do
    Enum.reduce(routes, %{}, fn(tup, acc) ->
      authority = elem(tup, 0)
      route = elem(tup, 1)

      spec = "#{authority.hostname}:#{authority.port}"
      Map.merge(
        acc,
        Map.put(%{}, spec, [%{hostname: route.hostname, port: route.port, secure_connection: route.secure_connection}]),
        fn(_key, v1, v2) -> v2 ++ v1 end)
    end)
  end

  @spec unix_timestamp_to_ecto_datetime(integer) :: Ecto.DateTime.t
  defp unix_timestamp_to_ecto_datetime(unix_timestamp) do
    erlang_ts = unix_timestamp_to_erlang(unix_timestamp)
    {date, {hour, min, sec}} = :calendar.now_to_universal_time(erlang_ts)
    {:ok, ecto_datetime} = Ecto.DateTime.load({date, {hour, min, sec, 0}})
    ecto_datetime
  end

  @spec unix_timestamp_to_erlang(integer) :: {integer, integer, integer}
  defp unix_timestamp_to_erlang(ts) do
    # Unix time only counts seconds, disregard microseconds
    {div(ts, 1_000_000), rem(ts, 1_000_000), 0}
  end

  @spec erlang_timestamp_to_unix({integer, integer, integer}) :: integer
  defp erlang_timestamp_to_unix(ts) do
    # Unix time only counds seconds, disregard microseconds
    {megas, secs, _} = ts

    megas * 1_000_000 + secs
  end
end