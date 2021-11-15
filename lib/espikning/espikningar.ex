defmodule Espikning.Espikningar do
  alias Espikning.Espikningar.Espikning, as: ES
  alias Espikning.DSpaceAPI

  def change_espikning(%ES{} = espikning, attrs \\ %{}) do
    ES.changeset(espikning, attrs)
  end

  def create_espikning(
    %{
      collection_uuid: collection_uuid,
      title: title,
      firstname: firstname,
      lastname: lastname,
      email: _email
    } = params
  ) do
    with {:ok, %{"uuid" => eperson_uuid}, eperson_exists} <- find_or_create_eperson(params),
      {:ok, _policy} <- find_or_create_eperson_policy(
        eperson_uuid,
        collection_uuid,
        "ADD"
      ),
      {:ok, %{"id" => workspace_item_id}} <- DSpaceAPI.create_workspace_item(collection_uuid),
      {:ok, %{"uuid" => item_uuid, "handle" => item_handle}} <- DSpaceAPI.get_workspace_item_item(workspace_item_id), 
      {:ok, _hmmm} <- DSpaceAPI.set_item_metadata(
        item_uuid, %{
          "dc.title" => title,
          "dc.contributor.author" => "#{firstname}, #{lastname}",
        },
        "add"
      ),
      #{:ok, hmm2} <- DSpaceAPI.set_item_data(item_uuid, %{"/submitter" => eperson_uuid}, "replace"),
      {:ok, _policies} <- DSpaceAPI.create_eperson_policies(eperson_uuid, item_uuid)
    do
      {:ok, item_handle, eperson_exists}
    else
      {:error, reason} ->
        IO.puts("error")
        IO.inspect(reason)
    end
  end

  def find_or_create_eperson(%{email: email} = params) do
    case DSpaceAPI.find_eperson_by_email(email) do
      {:ok, nil} ->
        case DSpaceAPI.create_eperson(params) do
          {:ok, eperson} -> {:ok, eperson, false}
          error -> error
        end
      {:ok, eperson} -> {:ok, eperson, true}
    end
  end

  def find_or_create_eperson_policy(eperson_uuid, resource_uuid, action) do
    case DSpaceAPI.search_eperson_policies(eperson_uuid, resource_uuid) do
      {:ok, policies} ->
        case Enum.find(policies, nil, fn policy -> policy["action"] === action end) do 
          nil -> 
            DSpaceAPI.create_eperson_policy(eperson_uuid, resource_uuid, action)
          policy ->
            {:ok, policy}
        end
    end
  end
end
