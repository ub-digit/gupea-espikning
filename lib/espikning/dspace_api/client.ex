defmodule Espikning.DSpaceAPI.Client do
  use GenServer

  @connect_timeout 100000

  @impl true
  def init(:ok) do
    {:ok, %{}}
  end

  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def post(endpoint, data, params \\ []), do: do_request({:post, endpoint, data, params, :json})
  def post(endpoint, data, params, format), do: do_request({:post, endpoint, data, params, format})

  def patch(endpoint, data, params \\ []), do: do_request({:patch, endpoint, data, params, :json})
  def patch(endpoint, data, params, format), do: do_request({:patch, endpoint, data, params, format})
  
  def put(endpoint, data, params \\ []), do: do_request({:put, endpoint, data, params, :json})
  def put(endpoint, data, params, format), do: do_request({:put, endpoint, data, params, format})
  
  def get(endpoint, params \\ []), do: do_request({:get, endpoint, params})

  defp do_request(request, try_authenticate \\ true) do
    case GenServer.call(__MODULE__, request) do
      {:ok, response_json} -> {:ok, response_json}
      {:error, :unauthenticated} when try_authenticate  ->
        case GenServer.call(__MODULE__, :authenticate) do
          {:ok, _jwt, _csrf} -> 
            do_request(request, false)
          {:error, reason} -> {:error, reason}
        end
      {:error, %Req.Response{status: status}} ->
        {:error, {:invalid_status, status}} #??
      {:error, reason} ->
        {:error, reason} # TODO: Handle, logging?
    end
  end

  defp auth_headers(csrf_token, jwt) do
    [
      {"X-XSRF-TOKEN", csrf_token},
      {"COOKIE", "DSPACE-XSRF-COOKIE=#{csrf_token}"},
      {"AUTHORIZATION", "Bearer #{jwt}"}
    ]
  end

  @impl true
  def handle_call(:authenticate, _from, _state) do
    response = Req.get!(base_req(), url: "/security/csrf")
    [csrf_token] = response.headers["dspace-xsrf-token"]

    response = Req.post!(
      base_req(),
      url: "/authn/login",
      headers: [
        {"X-XSRF-TOKEN", csrf_token},
        {"DSPACE-XSRF-TOKEN", csrf_token}, # DEnna tas bort
        {"COOKIE", "DSPACE-XSRF-COOKIE=#{csrf_token};XSRF-TOKEN=#{csrf_token};"}
      ],
      form: [
        user: config(:username),
        password: config(:password)
      ]
    )

    case response.headers["authorization"] do
      ["Bearer " <> jwt] ->
        {:reply, {:ok, csrf_token, jwt}, %{csrf: csrf_token, jwt: jwt}}
      _ -> {:reply, {:error, :invalid_credentials}, %{}}
    end
  end

  def handle_call({method, endpoint, data, params, format}, _from, state) when method in [:post, :put, :patch] do
    case state do
      %{csrf: csrf_token, jwt: jwt} ->
        headers = auth_headers(csrf_token, jwt)
        opts = [url: endpoint, params: params, connect_options: [timeout: @connect_timeout]]
        opts = case format do
          :json -> [{:json, data}, {:headers, headers} | opts]
          :uri_list -> [{:body, data}, {:headers, [{"Content-Type", "text/uri-list"} | headers]} | opts]
        end
        case method do
          :post ->
            Req.post(base_req(), opts)
          :put ->
            Req.put(base_req(), opts)
          :patch ->
            Req.patch(base_req(), opts)
        end
        |> handle_request_call_response(state)
      %{} -> {:reply, {:error, :unauthenticated}, %{}}
    end
  end

  def handle_call({:get, endpoint, params}, _from, state) do
    case state do
      %{csrf: csrf_token, jwt: jwt} ->
        Req.get(
          base_req(),
          url: endpoint,
          params: params,
          headers: auth_headers(csrf_token, jwt),
          connect_options: [timeout: @connect_timeout]
        )
        |> handle_request_call_response(state)
      %{} -> {:reply, {:error, :unauthenticated}, %{}}
    end
  end

  defp handle_request_call_response(response, state) do
    state = case response do
      %Req.Response{headers: %{"dspace-xsrf-token" => csrf_token}} ->
        %{state | csrf: csrf_token}
      _ -> state
    end
    case response do
      {
        :ok,
        %Req.Response{
          status: status,
          body: data
        }
      } when status >= 200 and status <= 299  ->
        {:reply, {:ok, data}, state}
      {:ok, %Req.Response{status: 401}} ->
        {:reply, {:error, :unauthenticated}, %{}}
      {:ok, %Req.Response{} = response} ->
        {:reply, {:error, response}, state} #TODO: Logging
      {:error, exception} ->
        {:reply, {:error, exception}, state}  # TODO: Log exception
    end
  end

  def base_req_debug() do
    Req.new(base_url: "http://localhost:8080")
  end

  def base_req() do
    Req.new(base_url: config(:api_base_url))
  end

  def config(key) do
    Application.fetch_env!(:espikning, __MODULE__)
    |> Keyword.get(key)
  end
end
