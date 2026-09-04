defmodule Granola.AuditTest do
  use ExUnit.Case, async: true

  setup do
    client = Granola.new(api_key: "grn_test_key", keys: :strings, plug: {Req.Test, __MODULE__})
    %{client: client}
  end

  defp fixture(name) do
    path = Path.join([__DIR__, "../support/fixtures", name])
    File.read!(path)
  end

  describe "list/2" do
    test "returns audit events on success", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/v1/audit"
        Req.Test.json(conn, Jason.decode!(fixture("list_audit_events.json")))
      end)

      assert {:ok, result} = Granola.Audit.list(client)
      assert [event] = result["events"]
      assert event["id"] == "aud_7Kq2mXbT9vRp3L"
      assert event["action"] == "workspace.member_added"
      assert event["actor"]["email"] == "oat@granola.ai"
      assert event["data"]["role"] == "member"
      assert event["context"]["client_version"] == "7.400.0"
      assert result["hasMore"] == false
      assert result["cursor"] == nil
    end

    test "does not create atoms for unknown event fields", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "events" => [%{"data" => %{"an_action_specific_field_granola_added_later" => 1}}],
          "hasMore" => false,
          "cursor" => nil
        })
      end)

      assert {:ok, _} = Granola.Audit.list(client)

      assert_raise ArgumentError, fn ->
        String.to_existing_atom("an_action_specific_field_granola_added_later")
      end
    end

    test "returns atom keys when the client asks for them" do
      client = Granola.new(api_key: "grn_test_key", plug: {Req.Test, __MODULE__})

      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, Jason.decode!(fixture("list_audit_events.json")))
      end)

      assert {:ok, result} = Granola.Audit.list(client)
      assert [event] = result.events
      assert event.id == "aud_7Kq2mXbT9vRp3L"
    end

    test "passes query params", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.query_string =~ "action=auth"
        assert conn.query_string =~ "page_size=30"
        assert conn.query_string =~ "occurred_after="
        assert conn.query_string =~ "occurred_before="
        Req.Test.json(conn, Jason.decode!(fixture("list_audit_events.json")))
      end)

      assert {:ok, _} =
               Granola.Audit.list(client,
                 action: "auth",
                 page_size: 30,
                 occurred_after: ~D[2026-01-01],
                 occurred_before: ~D[2026-02-01]
               )
    end

    test "ignores unsupported options", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.query_string == ""
        Req.Test.json(conn, Jason.decode!(fixture("list_audit_events.json")))
      end)

      assert {:ok, _} = Granola.Audit.list(client, created_after: ~D[2026-01-01])
    end

    test "returns error tuple on non-200", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{error: "Unauthorized - Invalid API key"})
      end)

      assert {:error, {401, _body}} = Granola.Audit.list(client)
    end

    test "returns error tuple on transport error", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, %Req.TransportError{reason: :econnrefused}} = Granola.Audit.list(client)
    end
  end

  describe "stream/2" do
    test "emits all events across pages", %{client: client} do
      page1 = %{
        "events" => [%{"id" => "aud_aaaaaaaaaaaaaa", "action" => "auth.login"}],
        "hasMore" => true,
        "cursor" => "cursor_abc"
      }

      page2 = %{
        "events" => [%{"id" => "aud_bbbbbbbbbbbbbb", "action" => "auth.logout"}],
        "hasMore" => false,
        "cursor" => nil
      }

      Req.Test.stub(__MODULE__, fn conn ->
        if conn.query_string =~ "cursor=cursor_abc" do
          Req.Test.json(conn, page2)
        else
          Req.Test.json(conn, page1)
        end
      end)

      events = Granola.Audit.stream(client) |> Enum.to_list()
      assert Enum.map(events, & &1["id"]) == ["aud_aaaaaaaaaaaaaa", "aud_bbbbbbbbbbbbbb"]
    end

    test "pages envelopes decoded with atom keys" do
      client = Granola.new(api_key: "grn_test_key", plug: {Req.Test, __MODULE__})

      Req.Test.stub(__MODULE__, fn conn ->
        if conn.query_string =~ "cursor=cursor_abc" do
          Req.Test.json(conn, %{
            "events" => [%{"id" => "aud_bbbbbbbbbbbbbb"}],
            "hasMore" => false,
            "cursor" => nil
          })
        else
          Req.Test.json(conn, %{
            "events" => [%{"id" => "aud_aaaaaaaaaaaaaa"}],
            "hasMore" => true,
            "cursor" => "cursor_abc"
          })
        end
      end)

      events = Granola.Audit.stream(client) |> Enum.to_list()
      assert Enum.map(events, & &1.id) == ["aud_aaaaaaaaaaaaaa", "aud_bbbbbbbbbbbbbb"]
    end

    test "keeps filters on every page", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.query_string =~ "action=auth"

        if conn.query_string =~ "cursor=cursor_abc" do
          Req.Test.json(conn, %{"events" => [], "hasMore" => false, "cursor" => nil})
        else
          Req.Test.json(conn, %{
            "events" => [%{"id" => "aud_aaaaaaaaaaaaaa"}],
            "hasMore" => true,
            "cursor" => "cursor_abc"
          })
        end
      end)

      assert [%{"id" => "aud_aaaaaaaaaaaaaa"}] =
               Granola.Audit.stream(client, action: "auth") |> Enum.to_list()
    end

    test "stops when hasMore is true but no cursor is returned", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "events" => [%{"id" => "aud_aaaaaaaaaaaaaa"}],
          "hasMore" => true,
          "cursor" => nil
        })
      end)

      assert [%{"id" => "aud_aaaaaaaaaaaaaa"}] = Granola.Audit.stream(client) |> Enum.to_list()
    end

    test "raises when a page has no events key", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"hasMore" => false, "cursor" => nil})
      end)

      assert_raise KeyError, fn -> Granola.Audit.stream(client) |> Enum.to_list() end
    end

    test "raises on transport error during iteration", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert catch_throw(Granola.Audit.stream(client) |> Enum.to_list()) ==
               {:error, %Req.TransportError{reason: :econnrefused}}
    end
  end
end
