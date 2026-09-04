defmodule Granola.Client do
  @moduledoc """
  Holds configuration for the Granola API client.

  Create one with `Granola.new/1` and pass it to functions in `Granola.Notes`
  or `Granola.Audit`.
  """

  @base_url "https://public-api.granola.ai/v1"

  @keys [:atoms, :strings]

  defstruct [:req, :keys]

  @type keys :: :atoms | :strings

  @type t :: %__MODULE__{req: Req.Request.t(), keys: keys()}

  @spec new(keyword()) :: t()
  def new(opts) do
    {api_key, opts} = Keyword.pop!(opts, :api_key)
    {keys, req_opts} = Keyword.pop(opts, :keys, :atoms)

    unless keys in @keys do
      raise ArgumentError,
            "expected :keys to be one of #{inspect(@keys)}, got: #{inspect(keys)}"
    end

    req =
      Req.new(
        [
          base_url: @base_url,
          auth: {:bearer, api_key},
          decoders: [json: &Jason.decode(&1, keys: keys)],
          retry: false
        ] ++ req_opts
      )

    %__MODULE__{req: req, keys: keys}
  end
end
