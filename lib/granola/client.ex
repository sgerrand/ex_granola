defmodule Granola.Client do
  @moduledoc false

  @base_url "https://public-api.granola.ai/v1"

  defstruct [:req]

  @type t :: %__MODULE__{req: Req.Request.t()}

  @spec new(keyword()) :: t()
  def new(opts) do
    {api_key, req_opts} = Keyword.pop!(opts, :api_key)

    req =
      Req.new(
        [
          base_url: @base_url,
          auth: {:bearer, api_key},
          decode_json: [keys: :atoms],
          retry: false
        ] ++ req_opts
      )

    %__MODULE__{req: req}
  end
end
