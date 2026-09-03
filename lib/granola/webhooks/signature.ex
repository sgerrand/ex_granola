defmodule Granola.Webhooks.Signature do
  @moduledoc """
  Verifies the signature on an incoming Granola webhook delivery.

  Granola signs every delivery following the
  [Standard Webhooks](https://www.standardwebhooks.com) specification. Three
  headers are sent with each request:

    * `webhook-id` - the event ID, matching `event_id` in the payload
    * `webhook-timestamp` - Unix timestamp (seconds) of the delivery attempt
    * `webhook-signature` - a space separated list of `v1,<base64 signature>`

  The signature is an HMAC-SHA256 of `"{webhook-id}.{webhook-timestamp}.{body}"`
  keyed with the base64 decoded signing secret (the part after `whsec_`).

  Always verify the **raw request body**, byte for byte, before decoding it as
  JSON. Re-encoding a decoded body changes the bytes and the signature will no
  longer match.

  ## Example

      def handle(conn, raw_body) do
        secret = Application.fetch_env!(:my_app, :granola_signing_secret)

        case Granola.Webhooks.Signature.verify(raw_body, conn.req_headers, secret) do
          :ok -> Granola.Webhooks.Event.parse(raw_body)
          {:error, reason} -> {:error, reason}
        end
      end

  """

  @secret_prefix "whsec_"
  @version "v1"
  @default_tolerance 300

  @typedoc """
  Request headers, as a map or a list of `{name, value}` pairs.

  Header names are matched case insensitively. Values may be binaries or lists
  of binaries, so both `Plug.Conn` and `Req` header shapes work.
  """
  @type headers :: Enumerable.t()

  @type error ::
          :missing_id
          | :missing_timestamp
          | :missing_signature
          | :invalid_timestamp
          | :timestamp_too_old
          | :timestamp_in_future
          | :invalid_signing_secret
          | :no_matching_signature

  @doc """
  Verifies a delivery signature.

  Returns `:ok` when the signature matches and the timestamp is within
  tolerance, otherwise `{:error, reason}`.

  ## Options

    * `:tolerance` - how many seconds the `webhook-timestamp` may differ from
      now, in either direction, before the delivery is rejected as a replay.
      Defaults to `300`. Pass `nil` to skip the check.
    * `:now` - the current Unix timestamp in seconds. Defaults to
      `System.system_time(:second)`. Useful in tests.

  ## Examples

      iex> secret = "whsec_" <> Base.encode64("hunter2")
      iex> {:ok, signature} = Granola.Webhooks.Signature.sign("{}", "evt_1", 1_769_527_800, secret)
      iex> headers = %{
      ...>   "webhook-id" => "evt_1",
      ...>   "webhook-timestamp" => "1769527800",
      ...>   "webhook-signature" => signature
      ...> }
      iex> Granola.Webhooks.Signature.verify("{}", headers, secret, now: 1_769_527_800)
      :ok

  """
  @spec verify(binary(), headers(), binary(), keyword()) :: :ok | {:error, error()}
  def verify(raw_body, headers, signing_secret, opts \\ [])
      when is_binary(raw_body) and is_binary(signing_secret) do
    tolerance = Keyword.get(opts, :tolerance, @default_tolerance)
    now = Keyword.get_lazy(opts, :now, fn -> System.system_time(:second) end)

    with {:ok, id} <- fetch_header(headers, "webhook-id", :missing_id),
         {:ok, timestamp} <- fetch_header(headers, "webhook-timestamp", :missing_timestamp),
         {:ok, provided} <- fetch_header(headers, "webhook-signature", :missing_signature),
         {:ok, seconds} <- parse_timestamp(timestamp),
         :ok <- check_tolerance(seconds, now, tolerance),
         {:ok, key} <- decode_secret(signing_secret) do
      expected = mac(key, id, timestamp, raw_body)

      if matches?(provided, expected),
        do: :ok,
        else: {:error, :no_matching_signature}
    end
  end

  @doc """
  Builds a `webhook-signature` header value for a body.

  Useful for testing your own webhook handler without a live delivery.

  ## Examples

      iex> secret = "whsec_" <> Base.encode64("hunter2")
      iex> Granola.Webhooks.Signature.sign("{}", "evt_1", 1_769_527_800, secret)
      {:ok, "v1,GXCeJ0pLjnq8b4SlDWlIt9f2VRZsVWGlQrrSy7TKTuo="}

  """
  @spec sign(binary(), binary(), binary() | integer(), binary()) ::
          {:ok, binary()} | {:error, :invalid_signing_secret}
  def sign(raw_body, id, timestamp, signing_secret)
      when is_binary(raw_body) and is_binary(id) and is_binary(signing_secret) do
    with {:ok, key} <- decode_secret(signing_secret) do
      {:ok, @version <> "," <> mac(key, id, to_string(timestamp), raw_body)}
    end
  end

  defp mac(key, id, timestamp, body) do
    :crypto.mac(:hmac, :sha256, key, [id, ".", timestamp, ".", body])
    |> Base.encode64()
  end

  defp matches?(provided, expected) do
    provided
    |> String.split(" ", trim: true)
    |> Enum.any?(fn versioned ->
      case String.split(versioned, ",", parts: 2) do
        [@version, signature] -> secure_compare(signature, expected)
        _other -> false
      end
    end)
  end

  # Signature length is not secret, so comparing it up front is safe.
  defp secure_compare(left, right) when byte_size(left) == byte_size(right),
    do: :crypto.hash_equals(left, right)

  defp secure_compare(_left, _right), do: false

  defp decode_secret(signing_secret) do
    stripped = String.replace_prefix(signing_secret, @secret_prefix, "")

    with :error <- Base.decode64(stripped),
         :error <- Base.decode64(stripped, padding: false) do
      {:error, :invalid_signing_secret}
    end
  end

  defp parse_timestamp(timestamp) do
    case Integer.parse(timestamp) do
      {seconds, ""} -> {:ok, seconds}
      _other -> {:error, :invalid_timestamp}
    end
  end

  defp check_tolerance(_seconds, _now, nil), do: :ok

  defp check_tolerance(seconds, now, tolerance) do
    cond do
      seconds < now - tolerance -> {:error, :timestamp_too_old}
      seconds > now + tolerance -> {:error, :timestamp_in_future}
      true -> :ok
    end
  end

  defp fetch_header(headers, name, error) do
    case find_header(headers, name) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _other -> {:error, error}
    end
  end

  defp find_header(headers, name) do
    Enum.find_value(headers, fn
      {key, value} -> if downcase(key) == name, do: header_value(value)
      _other -> nil
    end)
  end

  defp downcase(key) when is_binary(key), do: String.downcase(key)
  defp downcase(key) when is_atom(key), do: key |> Atom.to_string() |> String.downcase()
  defp downcase(_key), do: nil

  defp header_value(value) when is_binary(value), do: value
  defp header_value([value | _rest]) when is_binary(value), do: value
  defp header_value(_value), do: nil
end
