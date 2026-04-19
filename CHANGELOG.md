# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.0 (2026-04-19)


### Features

* automate release management with Release Please ([7704d42](https://github.com/sgerrand/ex_granola/commit/7704d42c64b4894dc0fef793343240814d8dd186))
* support for listing and fetching notes from the Granola API ([fc97899](https://github.com/sgerrand/ex_granola/commit/fc978996078179032a0278e03041a894fbc1c95b))


### Bug Fixes

* **build:** rename asdf configuration file ([c83c410](https://github.com/sgerrand/ex_granola/commit/c83c41010b93bf902a761b72ae75ceea92da5115))
* expose Granola.Client moduledoc to resolve ExDoc warnings ([9a62528](https://github.com/sgerrand/ex_granola/commit/9a625284fe48381ae66a4b86528bafb80a75c6cd))

## [Unreleased]

## [0.1.0] - 2026-04-19

### Added

- `Granola.new/1` — creates a configured API client
- `Granola.Notes.list/2` — lists notes with optional `created_before`, `created_after`, `updated_after`, `cursor`, and `page_size` filters
- `Granola.Notes.get/3` — fetches a single note by ID, with optional transcript via `include: :transcript`
- `Granola.Notes.stream/2` — lazily paginates through all notes as a `Stream`

[Unreleased]: https://github.com/sgerrand/ex_granola/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/sgerrand/ex_granola/releases/tag/v0.1.0
