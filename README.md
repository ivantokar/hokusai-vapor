<p align="center">
<img src="./hokusai-vapor-logo-v3.png" alt="Hokusai for Vapor" width="500">
</p>

# Hokusai Vapor

Vapor integration for [Hokusai 1.0](https://github.com/ivantokar/hokusai): decode an upload into an immutable image pipeline, transform it, then asynchronously return an HTTP response.

## Requirements

- Swift 6.0+, Vapor 4, and Hokusai 1.0.
- libvips and Cairo with PDF support.

```bash
# macOS
brew install vips cairo pkg-config

# Ubuntu/Debian
sudo apt install libvips-dev libcairo2-dev pkg-config
```

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
    .package(url: "https://github.com/ivantokar/hokusai-vapor.git", from: "1.0.0")
]
```

Add `HokusaiVapor` to the target that defines your routes.

## Configure once

```swift
import Vapor
import HokusaiVapor

func configure(_ app: Application) throws {
    try app.hokusai.configure()
    try routes(app)
}
```

`configure()` initializes Hokusai's native image runtime. Do not add a Vapor lifecycle shutdown hook: Hokusai owns ordinary process teardown safely.

## Raw request body

```swift
import HokusaiVapor

app.post("resize") { req async throws -> Response in
    let image = try req.hokusaiImage()
    let resized = try image.resize(width: 800, height: 600, fit: .cover)
    return try await resized.response(format: "jpeg", quality: 85)
}
```

```bash
curl -X POST http://localhost:8080/resize \
  --data-binary "@photo.jpg" \
  -o output.jpg
```

## Multipart upload

```swift
app.post("upload") { req async throws -> Response in
    let image = try req.hokusaiImage(field: "image")
    let thumbnail = try image.resize(width: 200, height: 200, fit: .cover)
    return try await thumbnail.response(format: "png", compression: 6)
}
```

## Text and metadata

```swift
app.post("watermark") { req async throws -> Response in
    let image = try req.hokusaiImage()
    let metadata = try image.metadata()

    let text = try image.drawText(
        "© MyCompany",
        x: metadata.width / 2,
        y: metadata.height / 2,
        options: TextOptions(font: "sans Bold", fontSize: 36, color: [255, 255, 255, 255])
    )

    return try await text.response(format: "webp", quality: 82)
}
```

## Output responses

`Hokusai.response` evaluates the pipeline asynchronously and sets the matching content type.

```swift
try await image.response(format: "jpeg", quality: 85)
try await image.response(format: "png", compression: 6)
try await image.response(format: "webp", quality: 82)
try await image.response(format: "avif", quality: 50)
try await image.response(format: "pdf")
```

PDF output is a Cairo-backed PDF containing Hokusai's evaluated raster page. It is appropriate for image documents; it does not currently preserve selectable vector text. See [Hokusai issue #13](https://github.com/ivantokar/hokusai/issues/13) for the planned vector-PDF API.

## Included routes

`ImageProcessingRoutes.register(to:)` provides two optional examples under any route group:

```swift
try ImageProcessingRoutes.register(to: app.grouped("api", "images"))
```

- `POST /api/images/text?text=Hello&fontSize=48`
- `POST /api/images/convert?format=webp&quality=82`

Both accept the source image as the raw request body.

## 0.x migration

HokusaiVapor 1.0 is a breaking release.

| 0.x | 1.0 |
| --- | --- |
| `try await req.hokusaiImage()` | `try req.hokusaiImage()` |
| `HokusaiImage` | `Hokusai` |
| `try image.response(...)` | `try await image.response(...)` |
| Per-app runtime shutdown | No ordinary shutdown hook |

## Related projects

- [Hokusai](https://github.com/ivantokar/hokusai)
- [Archived example application](https://github.com/ivantokar/hokusai-vapor-example)
