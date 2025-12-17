defmodule EspikningWeb.EspikningController do
  use EspikningWeb, :controller

  require Logger

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

  def frontend_url(path) do
    System.get_env("DSPACE_FRONTEND_BASE_URL", System.get_env("DSPACE_FRONTEND_BASE_URL"))
    |> URI.parse()
    |> Map.take([:scheme, :host, :port])
    |> then(fn uri ->
      %URI{uri | path: path}
    end)
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
      espikning_gupea_url = frontend_url("mydspace")

      with {:ok, item_handle, eperson_exists} <- Espikningar.create_espikning(espikning),
        {:ok, _response} <- Email.welcome(espikning, eperson_exists, item_handle, espikning_gupea_url) |> Mailer.deliver()
      do
        Logger.info("Espikning successfullu created: #{inspect(espikning)}")
        render(
          conn,
          :create,
          espikning: espikning,
          eperson_exists: eperson_exists,
          collection_name: collection_name,
          handle: item_handle
        )
      else
        {:error, reason} ->
          reason_message = case reason_extract_message(reason) do
            {:ok, message} -> message
            {:error, reason} ->
              Logger.error("Unkown error while trying to creating espikning: #{inspect(reason)}")
              nil
          end
          error_message = "Något gick fel när försökte skapa espikning, var god försök igen"
          error_message = if reason_message do
            Logger.error("Error while trying to create espikning: #{reason_message}")
            "#{error_message}. Felmeddelandet var: \"#{reason_message}\"."
          else
            "#{error_message}."
          end

          conn
          |> assign(:error_message, error_message)
          |> render(:new, collections: collections, changeset: changeset)
      end
    else
      render(conn, :new, collections: collections, changeset: changeset)
    end
  end

  defp reason_extract_message(reason) do
    case reason do
      reason when is_binary(reason) -> {:ok, reason}
      reason when is_atom(reason) ->
        {
          :ok,
          reason
          |> Atom.to_string()
          |> String.replace("_", " ")
          |> String.capitalize()
        }
      reason when is_exception(reason) -> {:ok, Exception.message(reason)}
      _ ->
        Logger.error("Unkown error while trying to creating espikning: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
