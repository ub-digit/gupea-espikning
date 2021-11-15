defmodule Espikning.Espikningar.Espikning do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :email, :string
    field :firstname, :string
    field :lastname, :string
    field :title, :string
    field :collection_id, :string
    field :password, :string
  end

  def changeset(espikning, params \\ %{}) do
    espikning
    |> cast(params, [:email, :firstname, :lastname, :title, :collection_id, :password])
    |> validate_required([:email, :firstname, :lastname, :title, :collection_id, :password], message: "Obligatorisk uppgift")
    |> validate_format(:email, ~r/@/, message: "Felaktigt format")
  end

  def validated_changeset(espikning, params \\ %{}) do
    changeset(espikning, params) |> apply_action(:update)
  end
end
