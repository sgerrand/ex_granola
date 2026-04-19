defmodule Granola do
  @moduledoc """
  Elixir client for the [Granola API](https://docs.granola.ai/introduction).

  ## Usage

      client = Granola.new(api_key: "grn_YOUR_API_KEY")

      {:ok, result} = Granola.Notes.list(client, page_size: 10)
      {:ok, note}   = Granola.Notes.get(client, "not_1d3tmYTlCICgjy")
      {:ok, note}   = Granola.Notes.get(client, "not_1d3tmYTlCICgjy", include: :transcript)

  """

  alias Granola.Client

  @doc """
  Creates a new API client.

  ## Options

    * `:api_key` - Required. Your Granola API key (e.g. `"grn_xxx"`).

  Any additional options are passed through to `Req.new/1`, which is useful for
  configuring test stubs via `plug: {Req.Test, name}`.

  """
  @spec new(keyword()) :: Client.t()
  def new(opts), do: Client.new(opts)
end
