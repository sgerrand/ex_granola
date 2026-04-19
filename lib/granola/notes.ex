defmodule Granola.Notes do
  @moduledoc """
  Functions for interacting with Granola notes.
  """

  alias Granola.Client

  @doc """
  Lists notes for the authenticated workspace.

  ## Options

    * `:created_before` - Return notes created before this date (`Date` or `DateTime`)
    * `:created_after` - Return notes created after this date (`Date` or `DateTime`)
    * `:updated_after` - Return notes updated after this date (`Date` or `DateTime`)
    * `:cursor` - Pagination cursor from a previous response
    * `:page_size` - Number of results per page (1–30, default 10)

  ## Examples

      iex> client = Granola.new(api_key: "grn_xxx")
      iex> Granola.Notes.list(client, page_size: 5)
      {:ok, %{notes: [...], hasMore: false, cursor: nil}}

  """
  @spec list(Client.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def list(%Client{req: req}, opts \\ []) do
    params =
      Keyword.take(opts, [:created_before, :created_after, :updated_after, :cursor, :page_size])

    case Req.get(req, url: "/notes", params: params) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetches a single note by ID.

  ## Options

    * `:include` - Set to `:transcript` to include the full meeting transcript

  ## Examples

      iex> client = Granola.new(api_key: "grn_xxx")
      iex> Granola.Notes.get(client, "not_1d3tmYTlCICgjy")
      {:ok, %{id: "not_1d3tmYTlCICgjy", title: "...", ...}}

      iex> Granola.Notes.get(client, "not_1d3tmYTlCICgjy", include: :transcript)
      {:ok, %{id: "not_1d3tmYTlCICgjy", transcript: [...], ...}}

  """
  @spec get(Client.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get(%Client{req: req}, note_id, opts \\ []) do
    params =
      case Keyword.get(opts, :include) do
        nil -> []
        value -> [include: value]
      end

    case Req.get(req, url: "/notes/#{note_id}", params: params) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns a `Stream` that lazily pages through all notes matching the given filters.

  Accepts the same options as `list/2`, except `:cursor` and `:page_size`.

  ## Examples

      iex> client = Granola.new(api_key: "grn_xxx")
      iex> Granola.Notes.stream(client) |> Enum.take(3)
      [%{id: "not_...", ...}, ...]

  """
  @spec stream(Client.t(), keyword()) :: Enumerable.t()
  def stream(%Client{} = client, opts \\ []) do
    base_opts = Keyword.drop(opts, [:cursor, :page_size])

    Stream.resource(
      fn -> nil end,
      fn
        :done ->
          {:halt, :done}

        cursor ->
          params = if cursor, do: Keyword.put(base_opts, :cursor, cursor), else: base_opts

          case list(client, params) do
            {:ok, %{notes: notes, hasMore: true, cursor: next_cursor}} ->
              {notes, next_cursor}

            {:ok, %{notes: notes}} ->
              {notes, :done}

            {:error, _} = err ->
              throw(err)
          end
      end,
      fn _ -> :ok end
    )
  end
end
