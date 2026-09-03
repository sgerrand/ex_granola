defmodule Granola.Webhooks.Event do
  @moduledoc """
  A webhook event delivered by Granola.

  Payloads carry metadata only - no note content. Fetch the note with
  `Granola.Notes.get/3` using `note_id` when you need the summary or transcript.

  Retries of the same delivery reuse the same `event_id`, so store it and skip
  events you have already handled.
  """

  @event_types %{
    "note.generated" => :note_generated,
    "note.edited" => :note_edited,
    "note.access_granted" => :note_access_granted
  }

  @enforce_keys [:event_id, :event_type, :note_id, :occurred_at]
  defstruct [:event_id, :event_type, :note_id, :occurred_at, changed_fields: [], data: %{}]

  @typedoc """
  A known event type as an atom, or the raw string for an event type this
  version of the library does not know about yet.
  """
  @type event_type :: :note_generated | :note_edited | :note_access_granted | String.t()

  @type t :: %__MODULE__{
          event_id: String.t(),
          event_type: event_type(),
          note_id: String.t(),
          occurred_at: DateTime.t(),
          changed_fields: [String.t()],
          data: map()
        }

  @type error ::
          :invalid_json
          | :invalid_payload
          | {:missing_field, String.t()}
          | {:invalid_field, String.t()}

  @doc """
  Returns the event type names Granola can send.

  ## Examples

      iex> Granola.Webhooks.Event.types()
      ["note.access_granted", "note.edited", "note.generated"]

  """
  @spec types() :: [String.t()]
  def types, do: @event_types |> Map.keys() |> Enum.sort()

  @doc """
  Parses a raw JSON request body into a `t:t/0`.

  The body is decoded with string keys, so a malicious payload cannot create
  atoms in your node.

  ## Examples

      iex> body = ~s({"event_id":"8f1c2a4e","event_type":"note.generated","note_id":"not_1d3tmYTlCICgjy","occurred_at":"2026-01-27T15:30:00Z"})
      iex> {:ok, event} = Granola.Webhooks.Event.parse(body)
      iex> event.event_type
      :note_generated

  """
  @spec parse(binary()) :: {:ok, t()} | {:error, error()}
  def parse(raw_body) when is_binary(raw_body) do
    case Jason.decode(raw_body) do
      {:ok, payload} when is_map(payload) -> from_map(payload)
      {:ok, _other} -> {:error, :invalid_payload}
      {:error, _reason} -> {:error, :invalid_json}
    end
  end

  @doc """
  Builds a `t:t/0` from an already decoded, string keyed payload.

  ## Examples

      iex> payload = %{
      ...>   "event_id" => "8f1c2a4e",
      ...>   "event_type" => "note.edited",
      ...>   "note_id" => "not_1d3tmYTlCICgjy",
      ...>   "occurred_at" => "2026-01-27T15:30:00Z",
      ...>   "data" => %{"changed_fields" => ["summary"]}
      ...> }
      iex> {:ok, event} = Granola.Webhooks.Event.from_map(payload)
      iex> event.changed_fields
      ["summary"]

  """
  @spec from_map(map()) :: {:ok, t()} | {:error, error()}
  def from_map(payload) when is_map(payload) do
    with {:ok, event_id} <- fetch_string(payload, "event_id"),
         {:ok, event_type} <- fetch_string(payload, "event_type"),
         {:ok, note_id} <- fetch_string(payload, "note_id"),
         {:ok, occurred_at} <- fetch_datetime(payload, "occurred_at") do
      data = data(payload)

      {:ok,
       %__MODULE__{
         event_id: event_id,
         event_type: Map.get(@event_types, event_type, event_type),
         note_id: note_id,
         occurred_at: occurred_at,
         changed_fields: changed_fields(data),
         data: data
       }}
    end
  end

  defp fetch_string(payload, key) do
    case Map.get(payload, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      nil -> {:error, {:missing_field, key}}
      _other -> {:error, {:invalid_field, key}}
    end
  end

  defp fetch_datetime(payload, key) do
    with {:ok, value} <- fetch_string(payload, key) do
      case DateTime.from_iso8601(value) do
        {:ok, datetime, _offset} -> {:ok, datetime}
        {:error, _reason} -> {:error, {:invalid_field, key}}
      end
    end
  end

  defp data(payload) do
    case Map.get(payload, "data") do
      data when is_map(data) -> data
      _other -> %{}
    end
  end

  defp changed_fields(data) do
    case Map.get(data, "changed_fields") do
      fields when is_list(fields) -> Enum.filter(fields, &is_binary/1)
      _other -> []
    end
  end
end
