<p align="center">
<img src="./hokusai-vapor-logo-v3.png" alt="Hokusai for Vapor" width="500">
</p>

# Hokusai Vapor

Vapor integration for [Hokusai 2](https://github.com/ivantokar/hokusai): read an upload into an immutable image pipeline, transform it, and stream the encoded result as an HTTP response with backpressure.

## Requirements

- Swift 6.0+ and Vapor 4.
- Hokusai 2.0+, which needs libvips 8.16+ and Cairo with PDF support.

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
    .package(url: "https://github.com/ivantokar/hokusai-vapor.git", from: "2.0.0")
]
```

Add `HokusaiVapor` to the target that defines your routes.

## Configure at startup

```swift
import Hokusai
import HokusaiVapor
import Vapor

func configure(_ app: Application) throws {
    // Optional: freeze Hokusai's process-level settings before the first image.
    try app.hokusai.configure(.init(maxConcurrentEvaluations: .fixed(4), maxQueuedEvaluations: 64))
    try routes(app)
}
```

Without a configuration the defaults apply and the native runtime starts on first use. `app.hokusai.capabilities()` reports which formats this process can read and write, and `app.hokusai.runtimeStatus` the scheduler's running and queued evaluations. Do not add a Vapor shutdown hook: Hokusai owns ordinary process teardown.

## Raw request body

```swift
app.post("resize") { req async throws -> Response in
    try await req.hokusaiImage()
        .resize(width: 800, height: 600, fit: .cover)
        .webp(quality: 82)
        .response()
}
```

```bash
curl -X POST http://localhost:8080/resize \
  --data-binary "@photo.jpg" \
  -o output.webp
```

`hokusaiImage(options:maximumSize:)` collects the body, never beyond `maximumSize` (20 MiB by default): a declared `Content-Length` over the limit is rejected before any byte is read, and a body without one is rejected as soon as it grows past it. Both give `413`, and an empty body gives `400`. Hokusai's own decode limits go in `options`. Vapor's `defaultMaxBodySize` also applies to the route; set it at least as high as `maximumSize`.

## Multipart upload

```swift
app.post("upload") { req async throws -> Response in
    try await req.hokusaiImage(field: "image")
        .resize(width: 200, height: 200, fit: .cover)
        .png()
        .response()
}
```

## Text and metadata

```swift
app.post("watermark") { req async throws -> Response in
    try await req.hokusaiImage()
        .drawText(
            "© MyCompany",
            placement: .gravity(.southEast, offsetX: 16, offsetY: 16),
            style: TextStyle(font: "sans Bold", fontSize: 36, color: .white)
        )
        .webp(quality: 82)
        .response()
}
```

## Responses

Choose the encoder on the pipeline, then call `response()`. `Content-Type` comes from the format the encoder produces.

```swift
try await image.jpeg(quality: 85).response()
try await image.png().response()
try await image.webp(quality: 82).response(headers: ["Cache-Control": "public, max-age=3600"])
try await image.avif(quality: 50).response()
try await image.pdf().response()
```

The body is written as it is encoded, so a response can start before the image is complete and a slow client slows encoding down instead of growing memory. When the client disconnects Vapor cancels the request task, which stops the evaluation. Before the response is committed the source header is read, so a missing or unreadable image becomes a `4xx` instead of a broken `200`; a failure after the first byte can only end the stream early.

PDF output is a Cairo-backed PDF containing Hokusai's evaluated raster page. It does not preserve selectable vector text; see [Hokusai issue #13](https://github.com/ivantokar/hokusai/issues/13).

## Errors

`HokusaiError` maps to a status by its case, never by message text.

| Case | Status |
| --- | --- |
| `invalidInput`, `invalidOption` | 400 |
| `decode` | 422 |
| `resource` for bytes | 413 |
| `resource` for pixels or channels | 422 |
| `resource` for the evaluation queue | 503 |
| `unsupported` | 501 |
| `io`, `transform`, `encode`, `runtime` | 500 |

`response()` and `hokusaiImage` already apply the mapping. For a route that evaluates a pipeline itself with `data()` or `write(to:)`, add the middleware:

```swift
let images = app.grouped(HokusaiErrorMiddleware())
```

## Included routes

`ImageProcessingRoutes.register(to:)` provides two optional examples under any route group, with the source image as the raw request body (up to 20 MB):

```swift
try ImageProcessingRoutes.register(to: app.grouped("api", "images"))
```

- `POST /api/images/text?text=Hello&fontSize=48`: draws centred text and returns a JPEG.
- `POST /api/images/convert?format=webp&quality=82`: converts to `jpeg`, `png`, `webp`, `avif` or `pdf`.

## Related projects

- [Hokusai](https://github.com/ivantokar/hokusai)
- [Archived example application](https://github.com/ivantokar/hokusai-vapor-example)
