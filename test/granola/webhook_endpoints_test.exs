defmodule Granola.WebhookEndpointsTest do
  use ExUnit.Case, async: true

  setup do
    client = Granola.new(api_key: "grn_test_key", plug: {Req.Test, __MODULE__})
    %{client: client}
  end

  defp fixture(name) do
    path = Path.join([__DIR__, "../support/fixtures", name])
    File.read!(path)
  end

  defp read_json_body(conn) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    {Jason.decode!(body), conn}
  end

  describe "create/2" do
    test "returns the endpoint and signing secret on 201", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/webhook-endpoints"

        {body, conn} = read_json_body(conn)

        assert body == %{
                 "url" => "https://example.com/granola-webhooks",
                 "scopes" => ["personal", "public"]
               }

        conn
        |> Plug.Conn.put_status(201)
        |> Req.Test.json(Jason.decode!(fixture("create_webhook_endpoint.json")))
      end)

      assert {:ok, endpoint} =
               Granola.WebhookEndpoints.create(client,
                 url: "https://example.com/granola-webhooks",
                 scopes: ["personal", "public"]
               )

      assert endpoint.id == "whe_2mKr8fQxLp7Ta3"
      assert endpoint.enabled == true
      assert endpoint.signing_secret =~ "whsec_"
    end

    test "sends events and folder_ids when given", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        {body, conn} = read_json_body(conn)

        assert body["events"] == ["note.generated"]
        assert body["folder_ids"] == ["fol_4y6LduVdwSKC27"]

        conn
        |> Plug.Conn.put_status(201)
        |> Req.Test.json(Jason.decode!(fixture("create_webhook_endpoint.json")))
      end)

      assert {:ok, _endpoint} =
               Granola.WebhookEndpoints.create(client,
                 url: "https://example.com/granola-webhooks",
                 scopes: [:personal],
                 events: [:"note.generated"],
                 folder_ids: ["fol_4y6LduVdwSKC27"]
               )
    end

    test "drops unknown options", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        {body, conn} = read_json_body(conn)
        refute Map.has_key?(body, "enabled")

        conn
        |> Plug.Conn.put_status(201)
        |> Req.Test.json(Jason.decode!(fixture("create_webhook_endpoint.json")))
      end)

      assert {:ok, _endpoint} =
               Granola.WebhookEndpoints.create(client,
                 url: "https://example.com/granola-webhooks",
                 scopes: ["personal"],
                 enabled: true
               )
    end

    test "returns error tuple on 403", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(403)
        |> Req.Test.json(%{error: "Forbidden"})
      end)

      assert {:error, {403, _body}} =
               Granola.WebhookEndpoints.create(client,
                 url: "https://example.com/granola-webhooks",
                 scopes: ["personal"]
               )
    end

    test "returns error tuple on transport error", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, %Req.TransportError{reason: :econnrefused}} =
               Granola.WebhookEndpoints.create(client,
                 url: "https://example.com/granola-webhooks",
                 scopes: ["personal"]
               )
    end
  end

  describe "list/1" do
    test "returns endpoints on success", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v1/webhook-endpoints"
        Req.Test.json(conn, Jason.decode!(fixture("list_webhook_endpoints.json")))
      end)

      assert {:ok, result} = Granola.WebhookEndpoints.list(client)
      assert [first, second] = result.webhook_endpoints
      assert first.id == "whe_2mKr8fQxLp7Ta3"
      assert first.url_redacted == false
      assert second.created_by == nil
      assert second.enabled == false
    end

    test "returns error tuple on 404", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{error: "Not found"})
      end)

      assert {:error, {404, _body}} = Granola.WebhookEndpoints.list(client)
    end
  end

  describe "update/3" do
    test "sends a PATCH with only the given fields", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/v1/webhook-endpoints/whe_2mKr8fQxLp7Ta3"

        {body, conn} = read_json_body(conn)
        assert body == %{"enabled" => false}

        Req.Test.json(conn, %{
          "id" => "whe_2mKr8fQxLp7Ta3",
          "object" => "webhook_endpoint",
          "enabled" => false
        })
      end)

      assert {:ok, endpoint} =
               Granola.WebhookEndpoints.update(client, "whe_2mKr8fQxLp7Ta3", enabled: false)

      assert endpoint.enabled == false
    end

    test "sends an empty folder_ids list to clear the filter", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        {body, conn} = read_json_body(conn)
        assert body == %{"folder_ids" => []}

        Req.Test.json(conn, %{"id" => "whe_2mKr8fQxLp7Ta3", "folder_ids" => []})
      end)

      assert {:ok, _endpoint} =
               Granola.WebhookEndpoints.update(client, "whe_2mKr8fQxLp7Ta3", folder_ids: [])
    end

    test "returns error tuple on 403", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(403)
        |> Req.Test.json(%{error: "Forbidden"})
      end)

      assert {:error, {403, _body}} =
               Granola.WebhookEndpoints.update(client, "whe_2mKr8fQxLp7Ta3",
                 url: "https://example.com/new"
               )
    end
  end

  describe "delete/2" do
    test "returns the deletion receipt", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/v1/webhook-endpoints/whe_2mKr8fQxLp7Ta3"

        Req.Test.json(conn, %{
          "id" => "whe_2mKr8fQxLp7Ta3",
          "object" => "webhook_endpoint",
          "deleted" => true
        })
      end)

      assert {:ok, result} = Granola.WebhookEndpoints.delete(client, "whe_2mKr8fQxLp7Ta3")
      assert result.deleted == true
    end

    test "returns error tuple on 404", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{error: "Not found"})
      end)

      assert {:error, {404, _body}} =
               Granola.WebhookEndpoints.delete(client, "whe_2mKr8fQxLp7Ta3")
    end

    test "returns error tuple on transport error", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, %Req.TransportError{reason: :econnrefused}} =
               Granola.WebhookEndpoints.delete(client, "whe_2mKr8fQxLp7Ta3")
    end
  end
end
