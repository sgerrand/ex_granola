# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.0 (2026-04-19)

Initial release.

### Features

* support for listing and fetching notes from the Granola API ([fc97899](https://github.com/sgerrand/ex_granola/commit/fc978996078179032a0278e03041a894fbc1c95b))

#### Added

- `Granola.new/1` — creates a configured API client
- `Granola.Notes.list/2` — lists notes with optional `created_before`, `created_after`, `updated_after`, `cursor`, and `page_size` filters
- `Granola.Notes.get/3` — fetches a single note by ID, with optional transcript via `include: :transcript`
- `Granola.Notes.stream/2` — lazily paginates through all notes as a `Stream`
