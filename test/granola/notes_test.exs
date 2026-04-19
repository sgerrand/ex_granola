defmodule Granola.NotesTest do
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
    test "returns notes on success", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, Jason.decode!(fixture("list_notes.json")))
      end)

      assert {:ok, result} = Granola.Notes.list(client)
      assert [note] = result.notes
      assert note.id == "not_1d3tmYTlCICgjy"
      assert note.title == "Quarterly yoghurt budget review"
      assert result.hasMore == false
      assert result.cursor == nil
    end

    test "passes query params", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.query_string =~ "page_size=5"
        assert conn.query_string =~ "created_after="
        Req.Test.json(conn, Jason.decode!(fixture("list_notes.json")))
      end)

      assert {:ok, _} = Granola.Notes.list(client, page_size: 5, created_after: ~D[2026-01-01])
    end

    test "returns error tuple on non-200", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{error: "Unauthorized - Invalid API key"})
      end)

      assert {:error, {401, _body}} = Granola.Notes.list(client)
    end

    test "returns error tuple on transport error", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, %Req.TransportError{reason: :econnrefused}} = Granola.Notes.list(client)
    end
  end

  describe "get/3" do
    test "returns a note on success", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, Jason.decode!(fixture("get_note.json")))
      end)

      assert {:ok, note} = Granola.Notes.get(client, "not_1d3tmYTlCICgjy")
      assert note.id == "not_1d3tmYTlCICgjy"
      assert note.summary_text =~ "success"
      assert note.transcript == nil
    end

    test "returns transcript when requested", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.query_string == "include=transcript"
        Req.Test.json(conn, Jason.decode!(fixture("get_note_with_transcript.json")))
      end)

      assert {:ok, note} = Granola.Notes.get(client, "not_1d3tmYTlCICgjy", include: :transcript)
      assert [first | _] = note.transcript
      assert first.text == "Let's get started."
      assert first.speaker.source == "microphone"
    end

    test "returns error tuple on 404", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{error: "Not found"})
      end)

      assert {:error, {404, _body}} = Granola.Notes.get(client, "not_1d3tmYTlCICgjy")
    end

    test "returns error tuple on transport error", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, %Req.TransportError{reason: :econnrefused}} =
               Granola.Notes.get(client, "not_1d3tmYTlCICgjy")
    end
  end

  describe "stream/2" do
    test "emits all notes across pages", %{client: client} do
      page1 = %{
        "notes" => [%{"id" => "not_aaaaaaaaaaaaaa", "object" => "note", "title" => "First"}],
        "hasMore" => true,
        "cursor" => "cursor_abc"
      }

      page2 = %{
        "notes" => [%{"id" => "not_bbbbbbbbbbbbbb", "object" => "note", "title" => "Second"}],
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

      notes = Granola.Notes.stream(client) |> Enum.to_list()
      assert length(notes) == 2
      assert Enum.map(notes, & &1.id) == ["not_aaaaaaaaaaaaaa", "not_bbbbbbbbbbbbbb"]
    end

    test "raises on transport error during iteration", %{client: client} do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert catch_throw(Granola.Notes.stream(client) |> Enum.to_list()) ==
               {:error, %Req.TransportError{reason: :econnrefused}}
    end
  end
end
