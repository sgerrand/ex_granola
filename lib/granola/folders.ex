defmodule Granola.Folders do
  @moduledoc """
  Functions for interacting with Granola folders.

  Folder IDs from here can be passed as `:folder_ids` to
  `Granola.WebhookEndpoints.create/2` to limit which notes trigger events.
  """

  alias Granola.Client

  @doc """
  Lists folders visible to the authenticated API key.

  ## Options

    * `:cursor` - Pagination cursor from a previous response
    * `:page_size` - Number of results per page (1-30, default 10)

  ## Examples

      iex> client = Granola.new(api_key: "grn_xxx")
      iex> Granola.Folders.list(client)
      {:ok, %{folders: [...], hasMore: false, cursor: nil}}

  """
  @spec list(Client.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def list(%Client{req: req}, opts \\ []) do
    params = Keyword.take(opts, [:cursor, :page_size])

    case Req.get(req, url: "/folders", params: params) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns a `Stream` that lazily pages through all folders.

  ## Examples

      iex> client = Granola.new(api_key: "grn_xxx")
      iex> Granola.Folders.stream(client) |> Enum.map(& &1.name)
      ["Top secret recipes", ...]

  """
  @spec stream(Client.t()) :: Enumerable.t()
  def stream(%Client{} = client) do
    Stream.resource(
      fn -> nil end,
      fn
        :done ->
          {:halt, :done}

        cursor ->
          params = if cursor, do: [cursor: cursor], else: []

          case list(client, params) do
            {:ok, %{folders: folders, hasMore: true, cursor: next_cursor}}
            when is_binary(next_cursor) ->
              {folders, next_cursor}

            {:ok, %{folders: folders}} ->
              {folders, :done}

            {:error, _reason} = error ->
              throw(error)
          end
      end,
      fn _state -> :ok end
    )
  end
end
