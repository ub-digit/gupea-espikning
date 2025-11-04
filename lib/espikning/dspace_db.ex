defmodule Espikning.DSpaceDB do
  @moduledoc """
  Espikning.DSpaceDB handles all workaounds requireing writing to
  or reading from the DSpace database
  """

  import Ecto.Query
  alias Espikning.DSpaceDB.Collections
  alias Espikning.Repo

  @resource_type_item 2

  def list_collections() do
    Collections.base_query()
    |> Repo.all()
    |> Enum.map(fn {id, uuid, handle, title, parent_title} -> {id, UUID.binary_to_string!(uuid), handle, title, parent_title} end)
  end

  def collections_options() do
    list_collections()
    |> Enum.map(fn {_id, uuid, handle, title, parent_title} -> {collection_option_text(handle, title, parent_title), "#{uuid}|#{collection_option_text(handle, title, parent_title)}"} end)
    |> Enum.sort()
  end

  # def truncate(<<head :: binary-size(40)>> <> _), do: "#{head}..."
  def truncate(text), do: text

  def collection_option_text(handle, title, _) do
    "#{truncate(title)} (handle: #{handle})"
  end

  def set_item_submitter(item_uuid, eperson_uuid) do
    item_uuid = UUID.string_to_binary!(item_uuid)
    eperson_uuid = UUID.string_to_binary!(eperson_uuid)
    result = from(i in "item", where: i.uuid == ^item_uuid)
    |> Repo.update_all(set: [submitter_id: eperson_uuid])
    case result do
      {count, result} when count == 1 -> {:ok, result}
      {0, _result} ->
        # TODO: Logger not found
        {:error, :set_item_submitter_not_found}
      _ ->
        #TODO: Logger wtf
        {:error, :set_item_submitter_mutliple_found}
    end
  end

  def create_item_handle(item_uuid) do
    Repo.transact(fn ->
      handle_id = from("handle_id_seq", select: fragment("nextval('handle_id_seq')"))
        |> Repo.one!()
      handle_value = from("handle_seq", select: fragment("nextval('handle_seq')"))
        |> Repo.one!()
      handle_string = "2077/#{handle_value}"
      handle = %{
        handle_id: handle_id,
        handle: handle_string,
        resource_type_id: @resource_type_item,
        resource_id: UUID.string_to_binary!(item_uuid)
      }
      Repo.insert_all("handle", [handle])
      {:ok, handle_string}
    end)
  end
end
