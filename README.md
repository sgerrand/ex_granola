# Granola

Elixir client for the [Granola API](https://docs.granola.ai/introduction).

## Installation

```elixir
def deps do
  [
    {:granola, "~> 0.0.0"}
  ]
end
```

## Usage

### Create a client

```elixir
client = Granola.new(api_key: "grn_YOUR_API_KEY")
```

API keys can be created in Granola under **Settings → API** (Business/Enterprise
plans).

### List notes

```elixir
{:ok, result} = Granola.Notes.list(client)

result.notes    # list of note summaries
result.hasMore  # true if there are more pages
result.cursor   # pass as :cursor to fetch the next page
```

Filter and paginate:

```elixir
{:ok, result} = Granola.Notes.list(client,
  created_after: ~D[2026-01-01],
  page_size: 30
)

# Next page
{:ok, next} = Granola.Notes.list(client, cursor: result.cursor)
```

Available filters: `:created_before`, `:created_after`, `:updated_after`,
`:cursor`, `:page_size` (1–30, default 10).

### Get a note

```elixir
{:ok, note} = Granola.Notes.get(client, "not_1d3tmYTlCICgjy")

note.id               # "not_1d3tmYTlCICgjy"
note.title            # "Quarterly yoghurt budget review"
note.summary_text     # plain text summary
note.summary_markdown # markdown summary
note.owner            # %{name: "...", email: "..."}
note.attendees        # list of %{name, email}
note.calendar_event   # associated calendar event or nil
note.web_url          # link to note in Granola web app
```

Request the full transcript:

```elixir
{:ok, note} = Granola.Notes.get(client, "not_1d3tmYTlCICgjy", include: :transcript)

for segment <- note.transcript do
  IO.puts("#{segment.speaker.source}: #{segment.text}")
end
```

Each transcript segment has `:speaker` (with `:source` of `"microphone"` or
`"speaker"`), `:text`, `:start_time`, and `:end_time`.

> Notes without a generated AI summary return a 404 error.

### Stream all notes

`Granola.Notes.stream/2` lazily paginates through all notes, fetching the next
page only when needed:

```elixir
Granola.Notes.stream(client, created_after: ~D[2026-01-01])
|> Stream.each(fn note -> IO.puts(note.title) end)
|> Stream.run()
```

Accepts the same filter options as `list/2`, except `:cursor` and `:page_size`.

### Error handling

All functions return `{:ok, result}` on success or `{:error, reason}` on failure:

```elixir
case Granola.Notes.get(client, id) do
  {:ok, note} -> note
  {:error, {404, _body}} -> :not_found
  {:error, {401, _body}} -> :unauthorized
  {:error, %Req.TransportError{} = err} -> {:network_error, err}
end
```

## Testing

Use `Req.Test` to stub HTTP calls without making real requests:

```elixir
client = Granola.new(api_key: "grn_test", plug: {Req.Test, __MODULE__})

Req.Test.stub(__MODULE__, fn conn ->
  Req.Test.json(conn, %{
    "notes" => [],
    "hasMore" => false,
    "cursor" => nil
  })
end)

assert {:ok, result} = Granola.Notes.list(client)
```

## Rate limits

The Granola API allows 25 requests per 5 seconds (burst) or 5 requests/second
sustained. Retries are disabled by default in the client; implement your own
retry/backoff if needed (or pass `retry: :safe_transient` to `Granola.new/1`).
