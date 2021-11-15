defmodule EspikningWeb.EspikningHTML do
  @moduledoc """
  This module contains espikningar rendered by EspikningController.

  See the `espikning_html` directory for all templates available.
  """
  use EspikningWeb, :html

  embed_templates "espikning_html/*"
end
