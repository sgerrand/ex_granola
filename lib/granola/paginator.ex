defmodule Granola.Paginator do
  @moduledoc false

  # Shared cursor pagination for the Granola API. Every list endpoint returns
  # the same envelope: a list under an endpoint-specific key, plus `hasMore`
  # and `cursor`.

  @doc """
  Returns a `Stream` that lazily follows `cursor` until `hasMore` is false.

  `key` is the atom the page's items live under (e.g. `:notes`). `fetch` is
  called with a keyword list containing `:cursor` (absent on the first page)
  and must return the same shape as a `list/2` function.

  Mirrors the error handling of the list functions by throwing the
  `{:error, reason}` tuple, since a `Stream` cannot return one.
  """
  @spec stream(atom(), (keyword() -> {:ok, map()} | {:error, term()})) :: Enumerable.t()
  def stream(key, fetch) when is_atom(key) and is_function(fetch, 1) do
    Stream.resource(
      fn -> nil end,
      fn
        :done ->
          {:halt, :done}

        cursor ->
          page_opts = if cursor, do: [cursor: cursor], else: []

          case fetch.(page_opts) do
            {:ok, %{^key => items, hasMore: true, cursor: next_cursor}}
            when not is_nil(next_cursor) ->
              {items, next_cursor}

            {:ok, %{^key => items}} ->
              {items, :done}

            {:error, _} = err ->
              throw(err)
          end
      end,
      fn _ -> :ok end
    )
  end
end
