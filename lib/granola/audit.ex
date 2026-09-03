defmodule Granola.Audit do
  @moduledoc """
  Functions for reading the workspace audit log.

  The audit log is an Enterprise feature and uses its own API key, created by a
  workspace admin under **Settings → Connectors → Audit API keys**. An audit key
  is read-only and cannot reach notes, folders, spaces or webhooks, so a key made
  under **Settings → API** will not work here.

      client = Granola.new(api_key: "grn_YOUR_AUDIT_API_KEY")
      {:ok, result} = Granola.Audit.list(client, action: "workspace")

  ## Reading events correctly

    * Events are returned newest first by `collected_at`, which is when Granola
      recorded the event — not by `occurred_at`, which is when it happened. Use
      `occurred_at` for any reasoning about time, and expect an event to be
      collected after later events have already been returned.
    * Page on `hasMore` and `cursor`, never on how many events a page holds. A
      page may contain fewer events than `:page_size`.
    * The set of actions is open and grows over time. Ignore actions and fields
      you do not recognise rather than failing on them.
    * Events are kept for one year. Older events are never returned or
      backfilled.
    * `id` is an opaque stable string (`"aud_..."`), not a UUID. Use it only for
      deduplication.
    * Rate limits are shared across every API key in the workspace, including
      keys used for notes. Pace backfills sequentially.

  """

  alias Granola.Client
  alias Granola.Paginator

  @params [:action, :occurred_before, :occurred_after, :cursor, :page_size]

  @doc """
  Lists audit events for the authenticated workspace.

  ## Options

    * `:action` - Return only events with this exact action, or events whose
      action starts with it followed by a dot. `"auth"` matches `"auth.login"`
      and `"auth.logout"`; `"auth.login"` matches only itself. Accepts a string
      or an atom.
    * `:occurred_after` - Return events that occurred after this date (`Date` or
      `DateTime`, within the one year retention window)
    * `:occurred_before` - Return events that occurred before this date (`Date`
      or `DateTime`, within the one year retention window)
    * `:cursor` - Pagination cursor from a previous response
    * `:page_size` - Number of results per page (1–30, default 10)

  ## Examples

      iex> client = Granola.new(api_key: "grn_xxx")
      iex> Granola.Audit.list(client, action: "workspace", page_size: 10)
      {:ok, %{events: [...], hasMore: true, cursor: "eyJ..."}}

  """
  @spec list(Client.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def list(%Client{req: req}, opts \\ []) do
    params = Keyword.take(opts, @params)

    case Req.get(req, url: "/audit", params: params) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns a `Stream` that lazily pages through all audit events matching the
  given filters.

  Accepts the same options as `list/2`, except `:cursor` and `:page_size`.

  Events arrive newest first by `collected_at`. Bound long runs with
  `:occurred_after` and `:occurred_before` rather than streaming the whole
  retention window in one pass.

  ## Examples

      iex> client = Granola.new(api_key: "grn_xxx")
      iex> Granola.Audit.stream(client, action: "auth") |> Enum.take(3)
      [%{id: "aud_...", action: "auth.login", ...}, ...]

  """
  @spec stream(Client.t(), keyword()) :: Enumerable.t()
  def stream(%Client{} = client, opts \\ []) do
    base_opts = Keyword.drop(opts, [:cursor, :page_size])

    Paginator.stream(:events, fn page_opts ->
      list(client, Keyword.merge(base_opts, page_opts))
    end)
  end
end
