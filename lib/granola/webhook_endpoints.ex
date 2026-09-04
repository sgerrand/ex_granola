defmodule Granola.WebhookEndpoints do
  @moduledoc """
  Manage the HTTPS endpoints Granola delivers webhook events to.

  Webhooks are available on Business and Enterprise plans. Endpoints can also be
  managed in the Granola app under **Settings -> Connectors -> Webhooks**.

  To verify and handle the deliveries themselves, see `Granola.Webhooks`.
  """

  alias Granola.Client

  @create_fields [:url, :scopes, :events, :folder_ids]
  @update_fields [:url, :scopes, :events, :folder_ids, :enabled]

  @doc """
  Registers a new webhook endpoint.

  The `signing_secret` in the response is returned **once only**. Store it
  before discarding the response - you cannot fetch it again.

  ## Options

    * `:url` - Required. A publicly reachable HTTPS URL to deliver events to.
    * `:scopes` - Required. Which notes to receive events for, at least one of:
      * `"personal"` - notes you own, notes shared directly with you, and notes
        in private folders shared with you
      * `"public"` - notes visible to everyone in the workspace
      * `"workspace"` - the only accepted scope for a workspace API key: public
        workspace notes plus notes in spaces with Granola API access enabled
    * `:events` - Event names to subscribe to, from
      `Granola.Webhooks.event_types/0`. Omit to subscribe to all of them.
    * `:folder_ids` - Restrict delivery to notes in these folders or their
      subfolders (1-100 IDs from `Granola.Folders.list/2`). Omit for every note
      matching `:scopes`.

  Scopes and event names may be given as strings or atoms.

  ## Examples

      iex> client = Granola.new(api_key: "grn_xxx")
      iex> Granola.WebhookEndpoints.create(client,
      ...>   url: "https://example.com/granola-webhooks",
      ...>   scopes: ["personal", "public"]
      ...> )
      {:ok, %{id: "whe_2mKr8fQxLp7Ta3", signing_secret: "whsec_...", ...}}

  """
  @spec create(Client.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def create(%Client{req: req}, opts) do
    body = opts |> Keyword.take(@create_fields) |> Map.new()

    req
    |> Req.post(url: "/webhook-endpoints", json: body)
    |> handle_response([200, 201])
  end

  @doc """
  Lists the webhook endpoints visible to the API key.

  A personal key sees the endpoints it created. An Enterprise workspace admin
  key sees every endpoint in the workspace.

  Signing secrets are never included. A `url` you did not create is reduced to
  its origin, and `url_redacted` is then `true`.

  ## Examples

      iex> client = Granola.new(api_key: "grn_xxx")
      iex> Granola.WebhookEndpoints.list(client)
      {:ok, %{webhook_endpoints: [%{id: "whe_2mKr8fQxLp7Ta3", enabled: true, ...}]}}

  """
  @spec list(Client.t()) :: {:ok, map()} | {:error, term()}
  def list(%Client{req: req}) do
    req
    |> Req.get(url: "/webhook-endpoints")
    |> handle_response([200])
  end

  @doc """
  Updates a webhook endpoint.

  Only the fields you pass are changed. Lists replace their current value rather
  than being added to.

  ## Options

    * `:url` - A new HTTPS delivery URL.
    * `:scopes` - Replaces the current scopes. A workspace-managed endpoint's
      scope is fixed at `["workspace"]`.
    * `:events` - Replaces the current event subscriptions.
    * `:folder_ids` - Replaces the current folder filter. Pass `[]` to remove
      the filter entirely.
    * `:enabled` - `false` pauses deliveries, `true` resumes them. A paused
      endpoint keeps its configuration and signing secret, but events that occur
      while it is paused are not delivered later.

  If you did not create the endpoint you can only change `:enabled`.

  ## Examples

      iex> client = Granola.new(api_key: "grn_xxx")
      iex> Granola.WebhookEndpoints.update(client, "whe_2mKr8fQxLp7Ta3", enabled: false)
      {:ok, %{id: "whe_2mKr8fQxLp7Ta3", enabled: false, ...}}

  """
  @spec update(Client.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def update(%Client{req: req}, webhook_endpoint_id, opts) do
    body = opts |> Keyword.take(@update_fields) |> Map.new()

    req
    |> Req.patch(url: "/webhook-endpoints/#{webhook_endpoint_id}", json: body)
    |> handle_response([200])
  end

  @doc """
  Deletes a webhook endpoint.

  Deliveries stop immediately and the signing secret is invalidated.

  ## Examples

      iex> client = Granola.new(api_key: "grn_xxx")
      iex> Granola.WebhookEndpoints.delete(client, "whe_2mKr8fQxLp7Ta3")
      {:ok, %{id: "whe_2mKr8fQxLp7Ta3", object: "webhook_endpoint", deleted: true}}

  """
  @spec delete(Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def delete(%Client{req: req}, webhook_endpoint_id) do
    req
    |> Req.delete(url: "/webhook-endpoints/#{webhook_endpoint_id}")
    |> handle_response([200])
  end

  defp handle_response({:ok, %{status: status, body: body}}, expected) do
    if status in expected, do: {:ok, body}, else: {:error, {status, body}}
  end

  defp handle_response({:error, reason}, _expected), do: {:error, reason}
end
