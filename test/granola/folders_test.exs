defmodule Granola.FoldersTest do
  use ExUnit.Case, async: true

  setup do
    client = Granola.new(api_key: "grn_test_key", plug: {Req.Test, __MODULE__})
    %{client: client}
  end

  defp fixture(name) do
    path = Path.join([__DIR__, "../support/fixtures", name])
    File.read!(path)
  end

  describe "list/2" do
    test "returns folders on success", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/v1/folders"
        Req.Test.json(conn, Jason.decode!(fixture("list_folders.json")))
      end)

      assert {:ok, result} = Granola.Folders.list(client)
      assert [top, child] = result.folders
      assert top.name == "Top secret recipes"
      assert top.parent_folder_id == nil
      assert child.parent_folder_id == "fol_4y6LduVdwSKC27"
      assert result.hasMore == false
    end

    test "passes query params", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.query_string =~ "page_size=30"
        assert conn.query_string =~ "cursor=abc"
        Req.Test.json(conn, Jason.decode!(fixture("list_folders.json")))
      end)

      assert {:ok, _result} = Granola.Folders.list(client, page_size: 30, cursor: "abc")
    end

    test "returns error tuple on 401", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{error: "Unauthorized - Invalid API key"})
      end)

      assert {:error, {401, _body}} = Granola.Folders.list(client)
    end

    test "returns error tuple on transport error", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, %Req.TransportError{reason: :econnrefused}} = Granola.Folders.list(client)
    end
  end

  describe "stream/1" do
    test "emits all folders across pages", %{client: client} do
      page1 = %{
        "folders" => [
          %{
            "id" => "fol_aaaaaaaaaaaaaa",
            "object" => "folder",
            "name" => "First",
            "parent_folder_id" => nil
          }
        ],
        "hasMore" => true,
        "cursor" => "cursor_abc"
      }

      page2 = %{
        "folders" => [
          %{
            "id" => "fol_bbbbbbbbbbbbbb",
            "object" => "folder",
            "name" => "Second",
            "parent_folder_id" => nil
          }
        ],
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

      folders = client |> Granola.Folders.stream() |> Enum.to_list()
      assert Enum.map(folders, & &1.id) == ["fol_aaaaaaaaaaaaaa", "fol_bbbbbbbbbbbbbb"]
    end

    test "stops when hasMore is true but no cursor is returned", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "folders" => [
            %{
              "id" => "fol_aaaaaaaaaaaaaa",
              "object" => "folder",
              "name" => "Only",
              "parent_folder_id" => nil
            }
          ],
          "hasMore" => true,
          "cursor" => nil
        })
      end)

      assert [%{id: "fol_aaaaaaaaaaaaaa"}] =
               client |> Granola.Folders.stream() |> Enum.to_list()
    end

    test "raises on transport error during iteration", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert catch_throw(client |> Granola.Folders.stream() |> Enum.to_list()) ==
               {:error, %Req.TransportError{reason: :econnrefused}}
    end
  end
end
