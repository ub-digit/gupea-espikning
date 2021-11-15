defmodule Espikning.Repo do
  use Ecto.Repo,
    otp_app: :espikning,
    adapter: Ecto.Adapters.Postgres
end
