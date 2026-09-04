defmodule Granola.Webhooks.EventTest do
  use ExUnit.Case, async: true

  doctest Granola.Webhooks.Event

  alias Granola.Webhooks.Event

  @payload %{
    "event_id" => "8f1c2a4e-6b3d-4e8f-9a2b-1c5d7e9f0a3b",
    "event_type" => "note.generated",
    "note_id" => "not_1d3tmYTlCICgjy",
    "occurred_at" => "2026-01-27T15:30:00Z"
  }

  describe "types/0" do
    test "lists every documented event name" do
      assert Event.types() == ["note.access_granted", "note.edited", "note.generated"]
    end
  end

  describe "parse/1" do
    test "parses a note.generated delivery" do
      assert {:ok, event} = Event.parse(Jason.encode!(@payload))

      assert event.event_id == "8f1c2a4e-6b3d-4e8f-9a2b-1c5d7e9f0a3b"
      assert event.event_type == :note_generated
      assert event.note_id == "not_1d3tmYTlCICgjy"
      assert event.occurred_at == ~U[2026-01-27 15:30:00Z]
      assert event.changed_fields == []
      assert event.data == %{}
    end

    test "parses a note.edited delivery with changed fields" do
      payload =
        @payload
        |> Map.put("event_type", "note.edited")
        |> Map.put("data", %{"changed_fields" => ["summary"]})

      assert {:ok, event} = Event.parse(Jason.encode!(payload))
      assert event.event_type == :note_edited
      assert event.changed_fields == ["summary"]
      assert event.data == %{"changed_fields" => ["summary"]}
    end

    test "parses a note.access_granted delivery" do
      payload = Map.put(@payload, "event_type", "note.access_granted")

      assert {:ok, %Event{event_type: :note_access_granted}} = Event.parse(Jason.encode!(payload))
    end

    test "keeps an unknown event type as a string" do
      payload = Map.put(@payload, "event_type", "note.exploded")

      assert {:ok, %Event{event_type: "note.exploded"}} = Event.parse(Jason.encode!(payload))
    end

    test "does not create atoms from payload keys" do
      payload = Map.put(@payload, "granola_no_such_atom_should_exist", true)

      assert {:ok, event} = Event.parse(Jason.encode!(payload))
      assert Map.has_key?(event.data, "changed_fields") == false

      assert_raise ArgumentError, fn ->
        String.to_existing_atom("granola_no_such_atom_should_exist")
      end
    end

    test "returns an error for invalid JSON" do
      assert Event.parse("{not json") == {:error, :invalid_json}
    end

    test "returns an error for a non object payload" do
      assert Event.parse("[]") == {:error, :invalid_payload}
    end

    test "returns an error for a missing field" do
      assert Event.parse(Jason.encode!(Map.delete(@payload, "note_id"))) ==
               {:error, {:missing_field, "note_id"}}
    end

    test "returns an error for a field of the wrong type" do
      assert Event.parse(Jason.encode!(Map.put(@payload, "event_id", 42))) ==
               {:error, {:invalid_field, "event_id"}}
    end

    test "returns an error for an unparseable timestamp" do
      assert Event.parse(Jason.encode!(Map.put(@payload, "occurred_at", "not a date"))) ==
               {:error, {:invalid_field, "occurred_at"}}
    end
  end

  describe "from_map/1" do
    test "ignores a non map data field" do
      assert {:ok, event} = Event.from_map(Map.put(@payload, "data", "nope"))
      assert event.data == %{}
      assert event.changed_fields == []
    end

    test "ignores non string entries in changed_fields" do
      payload = Map.put(@payload, "data", %{"changed_fields" => ["summary", 1, nil]})

      assert {:ok, event} = Event.from_map(payload)
      assert event.changed_fields == ["summary"]
    end

    test "ignores a non list changed_fields" do
      payload = Map.put(@payload, "data", %{"changed_fields" => "summary"})

      assert {:ok, event} = Event.from_map(payload)
      assert event.changed_fields == []
    end
  end
end
