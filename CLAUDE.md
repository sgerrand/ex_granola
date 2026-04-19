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

**HTTP layer:** Uses [`req`](https://hexdocs.pm/req) (~> 0.5). `plug` is a test-only dependency required by `Req.Test`.

**Testing:** Tests use `Req.Test` stubs (no real HTTP). Pass `plug: {Req.Test, __MODULE__}` in `Granola.new/1` to wire the stub. JSON fixtures live in `test/support/fixtures/`.

**API summary:**

- `GET /v1/notes` — list notes with optional `created_before`, `created_after`, `updated_after`, `cursor`, `page_size` filters
- `GET /v1/notes/{note_id}` — get a single note; pass `include: :transcript` for full transcript
- `stream/2` — lazy `Stream` that auto-paginates via cursor
