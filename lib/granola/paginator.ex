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

  Reads envelopes decoded with either atom or string keys, so it works whichever
  `:keys` the client was built with.

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
            {:ok, page} -> next_page(page, key)
            {:error, _} = err -> throw(err)
          end
      end,
      fn _ -> :ok end
    )
  end

  defp next_page(page, key) do
    items = fetch!(page, key)

    case {get(page, :hasMore), get(page, :cursor)} do
      {true, next_cursor} when is_binary(next_cursor) -> {items, next_cursor}
      _ -> {items, :done}
    end
  end

  defp fetch!(page, key) do
    case get(page, key) do
      nil -> raise KeyError, key: key, term: page
      items -> items
    end
  end

  defp get(page, key) do
    case Map.fetch(page, key) do
      {:ok, value} -> value
      :error -> Map.get(page, Atom.to_string(key))
    end
  end
end
