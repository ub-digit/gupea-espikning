defmodule EspikningWeb.EspikningController do
  use EspikningWeb, :controller
  alias Espikning.Espikningar
  alias Espikning.Espikningar.Espikning, as: ES
  alias Espikning.DSpaceDB

  alias Espikning.Email
  alias Espikning.Mailer

  def new(conn, params) do
    changeset = Espikningar.change_espikning(%ES{}, Map.get(params, "espikning", %{}))
    collections = DSpaceDB.collections_options()
    render(conn, :new, collections: collections, changeset: changeset)
  end

  def confirm(conn, %{"espikning" => espikning_params}) do
    case Espikningar.validate_espikning(%ES{}, espikning_params) do
      {:ok, _changes} ->
        changeset = Espikningar.change_espikning(%ES{}, espikning_params) # Hack
        [_collection_uuid, collection_name] = changeset.changes.collection_id |> String.split("|", parts: 2)
        render(
          conn,
          :confirm,
          changeset: changeset,
          collection_name: collection_name
        )
      {:error, changeset} ->
        collections = DSpaceDB.collections_options()
        render(conn, :new, collections: collections, changeset: changeset)
    end
  end

  def create(
    conn, %{
      "espikning" => %{
        "collection_id" => collection_id,
        "firstname" => _firstname,
        "lastname" => _lastname,
        "email" => _email
      } = espikning_params
    }
  ) do
    changeset = Espikningar.change_espikning(%ES{}, espikning_params)
    collections = DSpaceDB.collections_options()
    if changeset.valid? do
      espikning = Map.new(espikning_params, fn
        {k,v} when is_nil(v) -> {String.to_atom(k), nil}
        {k,v} -> {String.to_atom(k), String.trim(v)}
      end)
      # TODO: collection_uuid could be manipulated I guess? Validate?
      [collection_uuid, collection_name] = collection_id |> String.split("|", parts: 2)
      espikning = Map.put(espikning, :collection_uuid, collection_uuid)
      case Espikningar.create_espikning(espikning) do
        {:ok, item_handle, eperson_exists} ->
          Email.welcome(espikning, eperson_exists, item_handle) |> Mailer.deliver()
          render(
            conn,
            :create,
            espikning: espikning,
            eperson_exists: eperson_exists,
            collection_name: collection_name,
            handle: item_handle
          )
        {:error, _error} ->
          conn
          |> put_flash(:error, "Något gick fel när försökte skapa espikning, var god försök igen") # TODO: Fix flash
          |> render(:new, collections: collections, changeset: changeset)
      end
    else
      render(conn, :new, collections: collections, changeset: changeset)
    end
  end
end
