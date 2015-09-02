defmodule OpenAperture.Manager.Controllers.Users do
  require Logger
  use     OpenAperture.Manager.Web, :controller
  alias   OpenAperture.Manager.DB.Models.User

  @sendable_fields [:id, :first_name, :last_name, :email, :inserted_at, :updated_at]

  @no_user_error "No user with such ID found"

  # GET /users
  def swaggerdoc_index, do: %{
    description: "Retrieve all Users",
    response_schema: %{"title" => "Users", "type": "array", "items": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.User"}},
    parameters: []
  }    
  @spec index(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def index(conn, _params) do
    json conn, FormatHelper.to_sendable(Repo.all(User), @sendable_fields)
  end

  # GET /users/:id
  def swaggerdoc_show, do: %{
    description: "Retrieve a specific User",
    response_schema: %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.User"},
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "User identifier",
      "required" => true,
      "type" => "integer"
    }]
  }    
  @spec show(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def show(conn, %{"id" => id}) do
    if id == "me" do
      json conn, FormatHelper.to_sendable(conn.private[:auth_user], @sendable_fields)
    else
      user = Repo.get(User, id)

      if user do
        json conn, FormatHelper.to_sendable(user, @sendable_fields)
      else
        conn
        |> put_status(:not_found)
        |> json @no_user_error
      end
    end
  end

  # POST /users
  def swaggerdoc_create, do: %{
    description: "Create a User" ,
    parameters: [%{
      "name" => "type",
      "in" => "body",
      "description" => "The new User",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.User"}
    }]
  }
  @spec create(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def create(conn, params) do
    new_user = User.new(params)

    if new_user.valid? do
      user = Repo.insert!(new_user)
      path = users_path(Endpoint, :show, user.id)
      Logger.debug("New user created: #{inspect user}")

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

  # PUT /users/:id
  def swaggerdoc_update, do: %{
    description: "Update a User" ,
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "User identifier",
      "required" => true,
      "type" => "integer"
    },
    %{
      "name" => "type",
      "in" => "body",
      "description" => "The updated User",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.User"}
    }]
  }  
  @spec update(Plug.Conn.t, [any]) :: Plug.Conn.t  
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
          user = Repo.update!(changeset)
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
  def swaggerdoc_delete, do: %{
    description: "Delete a User" ,
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "User identifier",
      "required" => true,
      "type" => "integer"
    }]
  }  
  @spec delete(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def delete(conn, %{"id" => id}) do
    user = Repo.get(User, id)

    if user do
      Repo.delete!(user)
      Logger.info("User has been deleted: #{inspect user}")
      resp(conn, :no_content, "")
    else
      conn
      |> put_status(:not_found)
      |> json @no_user_error
    end
  end
end
