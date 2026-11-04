# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Added
- Tests over real HTTP connections: a client that reads slowly receives every byte,
  a client that disconnects part-way leaves no evaluation holding a slot, and the
  server keeps serving after dropped connections (hokusai#126).

## [2.0.0] - 2026-11-03

### Changed
- Built on Hokusai 2.0 and its streaming output. `Hokusai.response(status:headers:chunkSize:)` streams the encoded image through Vapor's body writer with backpressure; the encoder is chosen on the pipeline (`.webp(quality: 82).response()`) instead of by a format string.
- `Request.hokusaiImage(options:maximumSize:)` is async, collects the body within a size limit (`413` over it, `400` when empty) and takes Hokusai's `InputOptions`. `hokusaiImage(field:options:)` takes the same options.
- `app.hokusai.configure(_:)` accepts Hokusai's `RuntimeConfiguration`; `capabilities()` and `runtimeStatus` expose the runtime.
- The text route uses Hokusai's generated text sources and `Placement`.

### Added
- `HokusaiError.httpStatus` and `.abort`, and `HokusaiErrorMiddleware`, to map Hokusai errors to HTTP statuses by case.
- Tests that run a Vapor application: streamed responses, limits, error statuses and the sample routes.
- CI on Linux (Swift 6.4) and macOS.

### Requirements
- Hokusai 2.0.0, Vapor 4.89+, libvips 8.16+ and Cairo with PDF support.

## [1.0.0] - 2026-08-05

### Changed
- **Breaking:** migrate the Vapor integration to the immutable Hokusai 1.0
  pipeline and its async output terminals.
- `Request.hokusaiImage(field:)` now returns `Hokusai`; image response output
  is asynchronous and supports JPEG, PNG, WebP, AVIF, and PDF.
- Application configuration relies on Hokusai's process-safe automatic runtime
  initialization; it no longer registers a per-application libvips shutdown.

### Requirements
- Hokusai 1.0.0 and Cairo PDF support are required.

## [0.2.0] - 2026-04-20

### Changed
- Migrated to libvips dependency expectations and removed ImageMagick requirements from docs/workflows.
- Updated dependency floor to `hokusai` `0.2.0`.
- Updated Docker and troubleshooting documentation to remove ImageMagick-specific setup.

### Compatibility
- Preserved public API shape for `Application.hokusai.magickVersion` as a deprecated compatibility shim.

## [0.1.2] - Previous

- Previous release.
