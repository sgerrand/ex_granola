defmodule Granola.Webhooks.SignatureTest do
  use ExUnit.Case, async: true

  doctest Granola.Webhooks.Signature

  alias Granola.Webhooks.Signature

  @secret "whsec_" <> Base.encode64("granola-test-signing-key")
  @id "8f1c2a4e-6b3d-4e8f-9a2b-1c5d7e9f0a3b"
  @timestamp 1_769_527_800
  @body ~s({"event_id":"8f1c2a4e","event_type":"note.generated"})

  defp headers(overrides \\ %{}) do
    {:ok, signature} = Signature.sign(@body, @id, @timestamp, @secret)

    Map.merge(
      %{
        "webhook-id" => @id,
        "webhook-timestamp" => to_string(@timestamp),
        "webhook-signature" => signature
      },
      overrides
    )
  end

  defp verify(headers, opts \\ []) do
    Signature.verify(@body, headers, @secret, Keyword.put_new(opts, :now, @timestamp))
  end

  describe "verify/4" do
    test "accepts a valid signature" do
      assert verify(headers()) == :ok
    end

    test "matches a known vector" do
      # Independently computed: HMAC-SHA256 over "<id>.<timestamp>.<body>".
      signature = "v1,8GowHFe+FrA7pvfBe+A/hD1bLYwIdRiIGixUcVpUBME="
      assert verify(headers(%{"webhook-signature" => signature})) == :ok
    end

    test "accepts a secret without the whsec_ prefix" do
      bare = Base.encode64("granola-test-signing-key")
      {:ok, signature} = Signature.sign(@body, @id, @timestamp, bare)

      assert Signature.verify(@body, headers(%{"webhook-signature" => signature}), bare,
               now: @timestamp
             ) == :ok
    end

    test "accepts case insensitive header names" do
      assert verify(%{
               "Webhook-Id" => @id,
               "WEBHOOK-TIMESTAMP" => to_string(@timestamp),
               "Webhook-Signature" => headers()["webhook-signature"]
             }) == :ok
    end

    test "accepts a list of header pairs" do
      pairs = headers() |> Enum.to_list()
      assert verify(pairs) == :ok
    end

    test "accepts list wrapped header values" do
      pairs = Enum.map(headers(), fn {key, value} -> {key, [value]} end)
      assert verify(pairs) == :ok
    end

    test "accepts atom header names" do
      assert verify(%{
               :"webhook-id" => @id,
               :"WEBHOOK-TIMESTAMP" => to_string(@timestamp),
               "webhook-signature" => headers()["webhook-signature"]
             }) == :ok
    end

    test "skips header pairs whose name is neither a string nor an atom" do
      pairs = [{123, "ignored"} | Enum.to_list(headers())]
      assert verify(pairs) == :ok
    end

    test "skips header entries that are not name/value pairs" do
      pairs = [:junk | Enum.to_list(headers())]
      assert verify(pairs) == :ok
    end

    test "treats a header value that is neither a string nor a list as missing" do
      assert verify(headers(%{"webhook-id" => 123})) == {:error, :missing_id}
    end

    test "accepts a header carrying several signatures" do
      combined =
        "v1,bm90LXRoZS1yaWdodC1zaWduYXR1cmUtYXQtYWxsLi4uLg== " <> headers()["webhook-signature"]

      assert verify(headers(%{"webhook-signature" => combined})) == :ok
    end

    test "rejects a signature for a different body" do
      assert Signature.verify(@body <> " ", headers(), @secret, now: @timestamp) ==
               {:error, :no_matching_signature}
    end

    test "rejects a signature made with a different secret" do
      other = "whsec_" <> Base.encode64("some-other-signing-key!!")
      {:ok, signature} = Signature.sign(@body, @id, @timestamp, other)

      assert verify(headers(%{"webhook-signature" => signature})) ==
               {:error, :no_matching_signature}
    end

    test "rejects a mismatched webhook-id" do
      assert verify(headers(%{"webhook-id" => "evt_other"})) ==
               {:error, :no_matching_signature}
    end

    test "rejects an unknown signature version" do
      "v1," <> signature = headers()["webhook-signature"]

      assert verify(headers(%{"webhook-signature" => "v2," <> signature})) ==
               {:error, :no_matching_signature}
    end

    test "rejects a malformed signature header" do
      assert verify(headers(%{"webhook-signature" => "nonsense"})) ==
               {:error, :no_matching_signature}
    end

    test "rejects a timestamp outside the tolerance" do
      assert verify(headers(), now: @timestamp + 301) == {:error, :timestamp_too_old}
      assert verify(headers(), now: @timestamp - 301) == {:error, :timestamp_in_future}
    end

    test "accepts a timestamp on the edge of the tolerance" do
      assert verify(headers(), now: @timestamp + 300) == :ok
      assert verify(headers(), now: @timestamp - 300) == :ok
    end

    test "honours a custom tolerance" do
      assert verify(headers(), now: @timestamp + 301, tolerance: 600) == :ok
      assert verify(headers(), now: @timestamp + 10, tolerance: 5) == {:error, :timestamp_too_old}
    end

    test "skips the timestamp check when tolerance is nil" do
      assert verify(headers(), now: @timestamp + 999_999, tolerance: nil) == :ok
    end

    test "rejects a non numeric timestamp" do
      assert verify(headers(%{"webhook-timestamp" => "yesterday"})) ==
               {:error, :invalid_timestamp}
    end

    test "rejects missing headers" do
      assert Signature.verify(@body, %{}, @secret) == {:error, :missing_id}

      assert verify(Map.delete(headers(), "webhook-timestamp")) ==
               {:error, :missing_timestamp}

      assert verify(Map.delete(headers(), "webhook-signature")) ==
               {:error, :missing_signature}
    end

    test "rejects blank headers" do
      assert verify(headers(%{"webhook-id" => ""})) == {:error, :missing_id}
    end

    test "rejects a secret that is not base64" do
      assert Signature.verify(@body, headers(), "whsec_not base64!", now: @timestamp) ==
               {:error, :invalid_signing_secret}
    end

    test "rejects a secret that decodes to fewer than 24 bytes" do
      for secret <- ["", "whsec_", "whsec_" <> Base.encode64("too-short")] do
        assert Signature.verify(@body, headers(), secret, now: @timestamp) ==
                 {:error, :signing_secret_too_short}
      end
    end

    test "accepts a secret of exactly 24 bytes" do
      assert byte_size("granola-test-signing-key") == 24
      assert verify(headers()) == :ok
    end

    test "does not accept a delivery signed with an empty key" do
      # HMAC happily takes a zero-length key, and that key is public knowledge,
      # so anyone could forge this signature against a misconfigured endpoint.
      forged =
        "v1," <>
          Base.encode64(:crypto.mac(:hmac, :sha256, "", "#{@id}.#{@timestamp}.#{@body}"))

      assert Signature.verify(@body, headers(%{"webhook-signature" => forged}), "whsec_",
               now: @timestamp
             ) == {:error, :signing_secret_too_short}
    end

    test "defaults to the current system time" do
      now = System.system_time(:second)
      {:ok, signature} = Signature.sign(@body, @id, now, @secret)

      current =
        headers(%{
          "webhook-timestamp" => to_string(now),
          "webhook-signature" => signature
        })

      assert Signature.verify(@body, current, @secret) == :ok
    end
  end

  describe "sign/4" do
    test "returns a v1 prefixed base64 signature" do
      assert {:ok, "v1," <> signature} = Signature.sign(@body, @id, @timestamp, @secret)
      assert {:ok, digest} = Base.decode64(signature)
      assert byte_size(digest) == 32
    end

    test "accepts an integer or string timestamp" do
      assert Signature.sign(@body, @id, @timestamp, @secret) ==
               Signature.sign(@body, @id, to_string(@timestamp), @secret)
    end

    test "returns an error for an unusable secret" do
      assert Signature.sign(@body, @id, @timestamp, "whsec_not base64!") ==
               {:error, :invalid_signing_secret}
    end

    test "returns an error for a secret that decodes to fewer than 24 bytes" do
      assert Signature.sign(@body, @id, @timestamp, "whsec_") ==
               {:error, :signing_secret_too_short}

      assert Signature.sign(@body, @id, @timestamp, "whsec_" <> Base.encode64("too-short")) ==
               {:error, :signing_secret_too_short}
    end

    test "raises rather than stringifying a timestamp of the wrong type" do
      for timestamp <- [:foo, 1.5, nil] do
        assert_raise FunctionClauseError, fn ->
          Signature.sign(@body, @id, timestamp, @secret)
        end
      end
    end
  end
end
