# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2](https://github.com/sgerrand/ex_granola/compare/v1.0.1...v1.0.2) (2026-06-29)


### Bug Fixes

* **deps:** bump req from 0.5.18 to 0.6.1 ([#15](https://github.com/sgerrand/ex_granola/issues/15)) ([b5569a7](https://github.com/sgerrand/ex_granola/commit/b5569a7b5f719337cdd6494f7e6fc405fcad49f2))
* **deps:** bump req from 0.6.1 to 0.6.2 ([#18](https://github.com/sgerrand/ex_granola/issues/18)) ([0990909](https://github.com/sgerrand/ex_granola/commit/09909093dd046e06109d174450eb568c42d6ccdb))

## [1.0.1](https://github.com/sgerrand/ex_granola/compare/v1.0.0...v1.0.1) (2026-06-14)


### Bug Fixes

* **deps:** bump req from 0.5.17 to 0.5.18 ([#11](https://github.com/sgerrand/ex_granola/issues/11)) ([9744feb](https://github.com/sgerrand/ex_granola/commit/9744feb00c0e9bab25b3dcd67654545f8d0ac00a))

## 1.0.0 (2026-04-19)

Initial release.

### Features

* support for listing and fetching notes from the Granola API ([fc97899](https://github.com/sgerrand/ex_granola/commit/fc978996078179032a0278e03041a894fbc1c95b))

#### Added

- `Granola.new/1` — creates a configured API client
- `Granola.Notes.list/2` — lists notes with optional `created_before`, `created_after`, `updated_after`, `cursor`, and `page_size` filters
- `Granola.Notes.get/3` — fetches a single note by ID, with optional transcript via `include: :transcript`
- `Granola.Notes.stream/2` — lazily paginates through all notes as a `Stream`
