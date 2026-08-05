# Changelog

All notable changes to this project are documented in this file.

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
