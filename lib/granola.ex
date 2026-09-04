defmodule Granola do
  @moduledoc """
  Elixir client for the [Granola API](https://docs.granola.ai/introduction).

  ## Usage

      client = Granola.new(api_key: "grn_YOUR_API_KEY")

      {:ok, result} = Granola.Notes.list(client, page_size: 10)
      {:ok, note}   = Granola.Notes.get(client, "not_1d3tmYTlCICgjy")
      {:ok, note}   = Granola.Notes.get(client, "not_1d3tmYTlCICgjy", include: :transcript)

  The workspace audit log uses its own key and lives in `Granola.Audit`:

      audit = Granola.new(api_key: "grn_YOUR_AUDIT_API_KEY", keys: :strings)

      {:ok, result} = Granola.Audit.list(audit, action: "auth")
      result["events"]

  """

  alias Granola.Client

  @doc """
  Creates a new API client.

  ## Options

    * `:api_key` - Required. Your Granola API key (e.g. `"grn_xxx"`). Notes and
      the audit log use separate keys, so create one client per key.
    * `:keys` - How JSON object keys are decoded: `:atoms` (default) or
      `:strings`. `:atoms` creates an atom for every key the API returns, and
      atoms are never garbage collected, so prefer `:strings` for the audit log
      or any long-running process reading open-ended payloads. See
      `Granola.Audit` for details.

  Any additional options are passed through to `Req.new/1`, which is useful for
  configuring test stubs via `plug: {Req.Test, name}`.

  """
  @spec new(keyword()) :: Client.t()
  def new(opts), do: Client.new(opts)
end
