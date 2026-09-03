defmodule Granola.WebhooksTest do
  use ExUnit.Case, async: true

  doctest Granola.Webhooks

  alias Granola.Webhooks
  alias Granola.Webhooks.Signature

  @secret "whsec_" <> Base.encode64("granola-test-signing-key")
  @id "8f1c2a4e-6b3d-4e8f-9a2b-1c5d7e9f0a3b"
  @timestamp 1_769_527_800

  @body Jason.encode!(%{
          "event_id" => "8f1c2a4e-6b3d-4e8f-9a2b-1c5d7e9f0a3b",
          "event_type" => "note.edited",
          "note_id" => "not_1d3tmYTlCICgjy",
          "occurred_at" => "2026-01-27T15:30:00Z",
          "data" => %{"changed_fields" => ["summary"]}
        })

  defp headers(body \\ @body) do
    {:ok, signature} = Signature.sign(body, @id, @timestamp, @secret)

    [
      {"content-type", "application/json"},
      {"webhook-id", @id},
      {"webhook-timestamp", to_string(@timestamp)},
      {"webhook-signature", signature}
    ]
  end

  describe "verify_and_parse/4" do
    test "returns the parsed event for a valid delivery" do
      assert {:ok, event} =
               Webhooks.verify_and_parse(@body, headers(), @secret, now: @timestamp)

      assert event.event_type == :note_edited
      assert event.changed_fields == ["summary"]
    end

    test "stops at the signature check for a tampered body" do
      tampered = String.replace(@body, "not_1d3tmYTlCICgjy", "not_0000000000000")

      assert Webhooks.verify_and_parse(tampered, headers(), @secret, now: @timestamp) ==
               {:error, :no_matching_signature}
    end

    test "surfaces a stale timestamp" do
      assert Webhooks.verify_and_parse(@body, headers(), @secret, now: @timestamp + 3600) ==
               {:error, :timestamp_too_old}
    end

    test "surfaces a parse error for a correctly signed but invalid body" do
      body = "{}"

      assert Webhooks.verify_and_parse(body, headers(body), @secret, now: @timestamp) ==
               {:error, {:missing_field, "event_id"}}
    end
  end

  describe "verify/4" do
    test "delegates to the signature module" do
      assert Webhooks.verify(@body, headers(), @secret, now: @timestamp) == :ok
    end
  end

  describe "parse/1" do
    test "delegates to the event module" do
      assert {:ok, event} = Webhooks.parse(@body)
      assert event.note_id == "not_1d3tmYTlCICgjy"
    end
  end

  describe "event_types/0" do
    test "returns the documented event names" do
      assert Webhooks.event_types() == ["note.access_granted", "note.edited", "note.generated"]
    end
  end
end
