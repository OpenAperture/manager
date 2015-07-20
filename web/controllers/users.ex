defmodule OpenAperture.Manager.Controllers.Users do
  require Logger
  use     OpenAperture.Manager.Web, :controller
  alias   OpenAperture.Manager.DB.Models.User

  plug :action

  @no_user_error "No user with such ID found"

  # GET /users
  def index(conn, _params) do
    users = User
      |> Repo.all
      |> Enum.map &Map.from_struct/1

    json conn, users
  end

  # POST /users
  def create(conn, params) do
    new_user = User.new(params)

    if new_user.valid? do
      user = Repo.insert(new_user)
      path = users_path(Endpoint, :show, user.id)
      Logger.info("New user created: #{inspect user}")

      conn
      |> put_resp_header("location", path)
      |> put_status(:created)
      |> json "Created user #{user.id}"
    else
      conn
      |> put_status(:bad_request)
      |> json inspect(new_user.errors)
    end
  end

  # GET /users/:id
  def show(conn, %{"id" => id}) do
    user = Repo.get(User, id)

    if user do
      json conn, user
    else
      conn
      |> put_status(:not_found)
      |> json @no_user_error
    end
  end

  # PUT /users/:id
  def update(conn, %{"id" => id} = params) do
    user = Repo.get(User, id)

    case user do
      nil ->
        conn
        |> put_status(:not_found)
        |> json @no_user_error
      user ->
        changeset = User.validate_changes(user, params)

        if changeset.valid? do
          user = Repo.update(changeset)
          path = users_path(Endpoint, :show, user.id)
          Logger.info("User has been updates: #{inspect user}")

          conn
          |> put_resp_header("location", path)
          |> resp :no_content, ""
        else
          conn
          |> put_status(:bad_request)
          |> json inspect(changeset.errors)
        end
    end
  end

  # DELETE /users/:id"
  def delete(conn, %{"id" => id}) do
    user = Repo.get(User, id)

    if user do
      Repo.delete(user)
      Logger.info("User has been deleted: #{inspect user}")
      resp(conn, :no_content, "")
    else
      conn
      |> put_status(:not_found)
      |> json @no_user_error
    end
  end
end
