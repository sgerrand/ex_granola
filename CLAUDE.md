# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
mix deps.get        # Install dependencies
mix compile         # Compile the project
mix test            # Run all tests
mix test test/granola/notes_test.exs:15  # Run a single test by file:line
mix format          # Format code
mix format --check-formatted  # Check formatting without modifying
```

## Architecture

Elixir HTTP client library for the [Granola API](https://docs.granola.ai/introduction) (`https://public-api.granola.ai/v1`).

**Entry point:** `Granola.new/1` returns a `%Granola.Client{}` containing a configured `Req.Request`. All public API functions accept this struct as their first argument.

**Module layout:**

- `lib/granola.ex` — `new/1` entry point, delegates to `Granola.Client`
- `lib/granola/client.ex` — `%Granola.Client{}` struct; wraps `Req.new/1` with base URL, bearer auth, and atom-key JSON decoding
- `lib/granola/notes.ex` — `list/2`, `get/3`, `stream/2`
- `lib/granola/folders.ex` — `list/2`, `stream/1`
- `lib/granola/webhook_endpoints.ex` — `create/2`, `list/1`, `update/3`, `delete/2`
- `lib/granola/webhooks.ex` — receiving side: `verify_and_parse/4`, `verify/4`, `parse/1`, `event_types/0`
- `lib/granola/webhooks/signature.ex` — Standard Webhooks HMAC-SHA256 verification (`verify/4`, `sign/4`); no HTTP, no `Client`
- `lib/granola/webhooks/event.ex` — `%Granola.Webhooks.Event{}`; decodes delivery payloads with **string** keys (never atoms — payloads are remote input)

**HTTP layer:** Uses [`req`](https://hexdocs.pm/req) (~> 0.5). `plug` is a test-only dependency required by `Req.Test`.

**Testing:** Tests use `Req.Test` stubs (no real HTTP). Pass `plug: {Req.Test, __MODULE__}` in `Granola.new/1` to wire the stub. JSON fixtures live in `test/support/fixtures/`.

**API summary:**

- `GET /v1/notes` — list notes with optional `created_before`, `created_after`, `updated_after`, `cursor`, `page_size` filters
- `GET /v1/notes/{note_id}` — get a single note; pass `include: :transcript` for full transcript
- `stream/2` — lazy `Stream` that auto-paginates via cursor
- `GET /v1/folders` — list folders with optional `cursor`, `page_size`
- `POST /v1/webhook-endpoints` — returns **201**; `signing_secret` is returned once only
- `GET /v1/webhook-endpoints`, `PATCH`/`DELETE /v1/webhook-endpoints/{id}`

The full OpenAPI spec is at `https://docs.granola.ai/api-reference/openapi.json`.

**Webhook deliveries** follow [Standard Webhooks](https://www.standardwebhooks.com): headers `webhook-id`, `webhook-timestamp`, `webhook-signature` (`v1,<base64>`); HMAC-SHA256 over `"{id}.{timestamp}.{raw body}"` keyed with the base64-decoded secret (minus the `whsec_` prefix). Verify the raw body before decoding. Retries reuse `event_id`, so consumers should dedupe on it.
