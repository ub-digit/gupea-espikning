defmodule Espikning.DSpaceAPI do
  alias Espikning.DSpaceAPI.Client

  @policy_actions ["ADD", "READ", "WRITE", "DELETE", "REMOVE"]

  def search_eperson_policies(eperson_uuid, resource_uuid) do
    #TODO: Currently does not handle pagination
    case Client.get("/authz/resourcepolicies/search/eperson", [uuid: eperson_uuid, resource: resource_uuid]) do
      {:ok, %{"_embedded" => %{"resourcepolicies" => policies}}} -> {:ok, policies}
      {:ok, _data} -> {:ok, []}
      error -> error
    end
  end

  def find_eperson_by_email(email) do
    # Returns 204, would have been better with 200 and empty list
    # Handle this in Client as a general case?
    case Client.get("/eperson/epersons/search/byEmail", [email: email]) do
      {:ok, ""} -> {:ok, nil}
      {:ok, data} ->
        {:ok, data}
      error -> error
    end
  end

  def create_eperson(%{
    email: email,
    firstname: firstname,
    lastname: lastname,
    password: _password
  }) do
    eperson_data =  %{
      "name" => email,
      "metadata" => %{
        "eperson.firstname" => [
          %{
            "value" => firstname,
            "language" => nil,
            "authority" => "",
            "confidence" => -1 #?
          }
        ],
        "eperson.lastname" => [
          %{
            "value" => lastname,
            "language" => nil,
            "authority" => "",
            "confidence" => -1 #?
          }
        ]
      },
      "canLogIn" => true,
      "email" => email,
      "requireCertificate" => false,
      "selfRegistered" => false,
      "type" => "eperson"
    }

    with {:ok, %{"uuid" => uuid} = eperson} <- Client.post("/eperson/epersons", eperson_data),
      {:ok, _registration} <- Client.post("/eperson/registrations", %{
        "user" => uuid,
        "email" => email,
        "type" => "registration"},
        [accountRequestType: "forgot"]
      )
    do
      {:ok, eperson}
    else
      err -> err #TODO: Determine which failed and rollback creation?
    end
  end

  def create_eperson_policy(eperson_uuid, resource_uuid, action) do
    if action not in @policy_actions do
      {:error, {:invalid_action, action}}
    else
      policy_data = %{
        "name" => "Espikning",
        "description" =>  "Created by espikning",
        "policyType" => "TYPE_CUSTOM",
        "action" => action,
        "type" => "resourcepolicy"
      };
      Client.post(
        "/authz/resourcepolicies",
        policy_data,
        [resource: resource_uuid, eperson: eperson_uuid]
      )
    end
  end

  def create_eperson_policies(eperson_uuid, resource_uuid, actions \\ @policy_actions) do
    Enum.reduce(
      actions,
      {:ok, []},
      fn action, {:ok, policies} ->
        case create_eperson_policy(eperson_uuid, resource_uuid, action) do
          {:ok, policy} -> {:ok, [policy | policies]}
          {:error, _reason} -> {:error, policies}
        end
      # Don't create more policies if one fail
      _action, {:error, policies} ->
        {:error, policies}
    end
    )
  end

  # TODO: How do I set item name?
  def create_workspace_item(collection_uuid) do
    Client.post("/submission/workspaceitems", %{}, [owningCollection: collection_uuid])
  end

  def get_workspace_item_item(workspace_item_id) do
    Client.get("/submission/workspaceitems/#{workspace_item_id}/item")
  end
  # entries (better name?) is on the format %{ "<field>" => "<value", ... }
  #: TODO: validate op?
  def set_item_metadata(item_uuid, values, op) do
    values = values 
      |> Map.to_list()
      |> Enum.map(fn {field, value} ->
        {"/metadata/#{field}", [%{"value" => value}]}
      end)
      |> Enum.into(%{})
    set_item_data(item_uuid, values, op)
  end

  def set_item_data(item_uuid, values, op) do
    operations = values
      |> Map.to_list()
      |> Enum.map(fn {path, value} ->
        %{"op" => op, "path" => path, "value" => value}
      end)
    Client.patch("/core/items/#{item_uuid}", operations)
  end

end
