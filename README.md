# Granola

[![Test Status](https://github.com/sgerrand/ex_granola/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/sgerrand/ex_granola/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/sgerrand/ex_granola/badge.svg?branch=main)](https://coveralls.io/github/sgerrand/ex_granola?branch=main)
[![Hex Version](https://img.shields.io/hexpm/v/granola.svg)](https://hex.pm/packages/granola)
[![Hex Docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/granola/)

Elixir client for the [Granola API](https://docs.granola.ai/introduction).

## Installation

<!-- x-release-please-start-version -->

```elixir
def deps do
  [
    {:granola, "~> 1.0.4"}
  ]
end
```

<!-- x-release-please-end -->

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

### List folders

```elixir
{:ok, result} = Granola.Folders.list(client)

for folder <- result.folders do
  IO.puts("#{folder.id} #{folder.name}")
end
```

Takes `:cursor` and `:page_size` (1–30, default 10). `Granola.Folders.stream/1`
pages through all of them lazily.

Each folder has `:id`, `:object`, `:name` and `:parent_folder_id` (`nil` for a
top-level folder).

### Webhooks

Webhooks tell your app when notes change, so you don't have to poll. They are
available on Business and Enterprise plans.

#### Register an endpoint

```elixir
{:ok, endpoint} =
  Granola.WebhookEndpoints.create(client,
    url: "https://example.com/granola-webhooks",
    scopes: ["personal", "public"]
  )

endpoint.id             # "whe_2mKr8fQxLp7Ta3"
endpoint.signing_secret # "whsec_..." — returned once, store it now
```

The signing secret is only in this one response. If you lose it, delete the
endpoint and make a new one.

Options: `:url` (required, HTTPS), `:scopes` (required), `:events` (defaults to
all of them) and `:folder_ids` (limit deliveries to notes in those folders and
their subfolders).

Scopes:

- `"personal"` — notes you own, notes shared with you directly, and notes in
  private folders shared with you
- `"public"` — notes everyone in the workspace can see
- `"workspace"` — the only scope a workspace API key can use

Events: `"note.generated"` (first AI summary written), `"note.edited"` (summary
edited or regenerated) and `"note.access_granted"` (a note was shared with you).

#### Handle a delivery

```elixir
{:ok, raw_body, conn} = Plug.Conn.read_body(conn)
secret = Application.fetch_env!(:my_app, :granola_signing_secret)

case Granola.Webhooks.verify_and_parse(raw_body, conn.req_headers, secret) do
  {:ok, event} ->
    MyApp.Granola.enqueue(event)  # do the work after replying
    send_resp(conn, 200, "")

  {:error, _reason} ->
    send_resp(conn, 401, "")
end
```

An event has `:event_id`, `:event_type` (`:note_generated`, `:note_edited` or
`:note_access_granted`), `:note_id`, `:occurred_at` (a `DateTime`),
`:changed_fields` and `:data`.

Payloads carry no note content. Use `Granola.Notes.get/3` with `event.note_id`
to fetch the note itself.

Three things to get right:

1. **Verify the raw body.** The signature covers the exact bytes Granola sent.
   In Phoenix, `Plug.Parsers` reads the body before your controller runs, so
   either mount the webhook route before the parser or use a `:body_reader` that
   keeps a copy of the raw body.
1. **Reply with a `2xx` within 15 seconds.** Anything slower counts as a failed
   delivery. Queue the work and respond straight away.
1. **Expect repeats.** Retries reuse the same `event_id`, so record the IDs
   you've handled and ignore ones you've seen.

Failed deliveries are retried with backoff for four days. After that Granola
turns the endpoint off and emails whoever created it. Missed events are never
sent again.

`Granola.Webhooks.Signature.sign/4` builds a valid `webhook-signature` header so
you can test your handler without a live delivery.

#### Manage endpoints

```elixir
{:ok, result} = Granola.WebhookEndpoints.list(client)

# Pause deliveries
{:ok, endpoint} =
  Granola.WebhookEndpoints.update(client, "whe_2mKr8fQxLp7Ta3", enabled: false)

# Remove the folder filter
{:ok, endpoint} =
  Granola.WebhookEndpoints.update(client, "whe_2mKr8fQxLp7Ta3", folder_ids: [])

{:ok, _} = Granola.WebhookEndpoints.delete(client, "whe_2mKr8fQxLp7Ta3")
```

`update/3` only changes the fields you pass, and lists replace rather than add
to what's there. If you didn't create an endpoint you can only change
`:enabled`, and its `url` comes back cut down to the origin with
`url_redacted: true`.

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
