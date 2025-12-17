defmodule Espikning.Email do
  import Swoosh.Email
  require EEx
require EEx
  @template_path Path.expand("templates/welcome_email.text.eex", __DIR__)
  EEx.function_from_file(:defp, :welcome_email_body, @template_path, [:espikning, :eperson_exists, :handle, :espikning_gupea_url])

  def welcome(espikning, eperson_exists, handle, espikning_gupea_url) do
    body = welcome_email_body(espikning, eperson_exists, handle, espikning_gupea_url)
    new()
    |> to({espikning.firstname <> espikning.lastname, espikning.email})
    |> bcc({"gup@ub.gu.se", "gup@ub.gu.se"})
    |> from({"gupea@ub.gu.se", "gupea@ub.gu.se"})
    |> subject("GUPEA: E-spikning av doktorsavhandling / E-publishing of doctoral thesis")
    |> text_body(body)
  end

end
