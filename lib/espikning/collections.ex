defmodule Espikning.Collections do
  import Ecto.Query

  def query() do
    from c in "collection",
    join: mv in "metadatavalue", on: c.uuid == mv.dspace_object_id,
    join: mr in "metadatafieldregistry", on: mv.metadata_field_id == mr.metadata_field_id,
    join: cm2c in "community2collection", on: c.uuid == cm2c.collection_id,
    join: cm in "community", on: cm2c.community_id == cm.uuid,
    join: mv2 in "metadatavalue", on: cm.uuid == mv2.dspace_object_id,
    join: mr2 in "metadatafieldregistry", on: mv2.metadata_field_id == mr2.metadata_field_id,
    join: h in "handle", on: c.uuid == h.resource_id,
    where: mr.element == "title",
    where: mr2.element == "title",
    where: like(mv.text_value, "Doctoral%"),

    select: {c.collection_id, c.uuid, h.handle, mv.text_value, mv2.text_value}
  end

  def all() do
    query()
    |> Espikning.Repo.all()
    |> Enum.map(fn {id, uuid, handle, title, parent_title} -> {id, UUID.binary_to_string!(uuid), handle, title, parent_title} end)
  end

  def options() do
    all()
    |> Enum.map(fn {_id, uuid, handle, title, parent_title} -> {option_text(handle, title, parent_title), "#{uuid}|#{option_text(handle, title, parent_title)}"} end)
    |> Enum.sort()
  end

  # def truncate(<<head :: binary-size(40)>> <> _), do: "#{head}..."
  def truncate(text), do: text

  def option_text(handle, title, _) do
    "#{truncate(title)} (handle: #{handle})"
  end
end
