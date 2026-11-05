# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

## [2.1.0] - 2026-11-05

Requires Hokusai 2.2.

### Changed
- `hokusaiImage` reads the body with `Hokusai(spooling:)` (hokusai#112). A small upload stays in
  memory; one larger than `memoryLimit` (default 1 MiB) is spooled to a private temporary file that the
  pipeline removes when it is released, so the encoded upload no longer has to fit in memory and
  `maximumSize` can be raised. New parameters `memoryLimit` and `spoolDirectory`; the limits, statuses
  (`413` over the limit, `400` for an empty body) and the early `Content-Length` check are unchanged.
  The byte limit is the smaller of `options.limits.maxBytes` and `maximumSize`.
- Requires Hokusai 2.2 (`from: "2.2.0"`).

### Added
- Overload and failure tests over real connections (hokusai#126): with one slot and no queue a
  second request gets a `503`, the busy request is not disturbed and the server serves again once the
  slot is free; a pipeline that fails after output began ends the body without the terminating chunk,
  so the client can tell the image is incomplete, and frees its slot. They run in a process of their
  own (`HOKUSAI_OVERLOAD_TESTS=1 swift test --filter OverloadTests`).
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
