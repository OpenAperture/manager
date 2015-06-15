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
      record = Repo.insert(new_user)
      Logger.info("New user created: #{inspect record}")
      conn
      |> put_status(:created)
      |> json "Created user #{new_user.changes.email}"
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
          record = Repo.update(changeset)
          Logger.info("User has been updates: #{inspect record}")
          resp(conn, :no_content, "")
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
