defmodule Espikning.DSpaceDB.Collections do
  import Ecto.Query

  def base_query() do
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

end
