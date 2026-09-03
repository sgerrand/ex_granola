defmodule Granola.Webhooks do
  @moduledoc """
  Receive and verify Granola webhook deliveries.

  This module is the front door for handling an incoming delivery. It is
  framework agnostic: give it the raw request body, the request headers and your
  signing secret, and it hands back a `Granola.Webhooks.Event`.

  Register the endpoint that receives these deliveries with
  `Granola.WebhookEndpoints`.

  ## Handling a delivery

      def create(conn, _params) do
        {:ok, raw_body, conn} = Plug.Conn.read_body(conn)
        secret = Application.fetch_env!(:my_app, :granola_signing_secret)

        case Granola.Webhooks.verify_and_parse(raw_body, conn.req_headers, secret) do
          {:ok, event} ->
            # Respond within 15 seconds, then do the work in the background.
            MyApp.Granola.enqueue(event)
            send_resp(conn, 200, "")

          {:error, _reason} ->
            send_resp(conn, 401, "")
        end
      end

  Two things matter:

    * **Verify the raw body.** Signatures are over the exact bytes Granola
      sent. In Phoenix, `Plug.Parsers` consumes the body before your controller
      runs, so either mount the webhook route before the parser or use a custom
      `:body_reader` that stashes the raw body on the connection.
    * **Reply with a `2xx` inside 15 seconds.** Anything slower is treated as a
      failed delivery and retried. Do the real work after responding.

  ## Retries and duplicates

  Granola retries `408`, `429`, `5xx`, timeouts and network errors with
  exponential backoff for up to four days, then disables the endpoint and emails
  its creator. Retries reuse the same `event_id`, so record the IDs you have
  processed and treat repeats as no-ops. Missed events are never replayed.

  Redirects and other `4xx` responses are permanent failures - no retry.
  """

  alias Granola.Webhooks.Event
  alias Granola.Webhooks.Signature

  @doc """
  Verifies a delivery signature and parses the body in one step.

  Accepts the same options as `Granola.Webhooks.Signature.verify/4`.

  ## Examples

      iex> secret = "whsec_" <> Base.encode64("hunter2")
      iex> body = ~s({"event_id":"evt_1","event_type":"note.generated","note_id":"not_1d3tmYTlCICgjy","occurred_at":"2026-01-27T15:30:00Z"})
      iex> {:ok, signature} = Granola.Webhooks.Signature.sign(body, "evt_1", 1_769_527_800, secret)
      iex> headers = [
      ...>   {"webhook-id", "evt_1"},
      ...>   {"webhook-timestamp", "1769527800"},
      ...>   {"webhook-signature", signature}
      ...> ]
      iex> {:ok, event} = Granola.Webhooks.verify_and_parse(body, headers, secret, now: 1_769_527_800)
      iex> event.note_id
      "not_1d3tmYTlCICgjy"

  """
  @spec verify_and_parse(binary(), Signature.headers(), binary(), keyword()) ::
          {:ok, Event.t()} | {:error, Signature.error() | Event.error()}
  def verify_and_parse(raw_body, headers, signing_secret, opts \\ []) do
    with :ok <- Signature.verify(raw_body, headers, signing_secret, opts) do
      Event.parse(raw_body)
    end
  end

  @doc """
  Verifies a delivery signature without parsing the body.

  See `Granola.Webhooks.Signature.verify/4`.
  """
  @spec verify(binary(), Signature.headers(), binary(), keyword()) ::
          :ok | {:error, Signature.error()}
  def verify(raw_body, headers, signing_secret, opts \\ []),
    do: Signature.verify(raw_body, headers, signing_secret, opts)

  @doc """
  Parses a raw delivery body without verifying its signature.

  Prefer `verify_and_parse/4`. See `Granola.Webhooks.Event.parse/1`.
  """
  @spec parse(binary()) :: {:ok, Event.t()} | {:error, Event.error()}
  def parse(raw_body), do: Event.parse(raw_body)

  @doc """
  Returns the event type names Granola can send.

  ## Examples

      iex> Granola.Webhooks.event_types()
      ["note.access_granted", "note.edited", "note.generated"]

  """
  @spec event_types() :: [String.t()]
  def event_types, do: Event.types()
end
