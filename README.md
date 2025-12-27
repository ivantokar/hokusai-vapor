# Hokusai Vapor

Vapor framework integration for [Hokusai](../hokusai), providing seamless image processing capabilities in your Vapor applications.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Vapor](https://img.shields.io/badge/Vapor-4.0+-blue.svg)](https://vapor.codes)
[![Platform](https://img.shields.io/badge/Platform-macOS%20|%20Linux-lightgrey.svg)](https://swift.org)

## Features

- 🚀 **Request Extensions** - Load images directly from request body or multipart form data
- 📤 **Response Conversion** - Convert `HokusaiImage` to Vapor `Response` with proper MIME types
- ⚙️ **Lifecycle Management** - Automatic initialization and shutdown with Vapor's lifecycle
- 🛣️ **Pre-built Routes** - Ready-to-use route handlers for common image operations
- 🐳 **Docker Ready** - Full Docker support with ImageMagick and libvips

## Installation

### Requirements

**macOS:**
```bash
brew install vips imagemagick pkg-config
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install libvips-dev libmagick++-dev libmagickwand-dev pkg-config
```

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
    .package(url: "https://github.com/ivantokar/hokusai-vapor.git", from: "1.0.0")
]

targets: [
    .target(
        name: "App",
        dependencies: [
            .product(name: "Vapor", package: "vapor"),
            .product(name: "HokusaiVapor", package: "hokusai-vapor")
        ]
    )
]
```

## Quick Start

### 1. Configure Hokusai in your app

```swift
import Vapor
import HokusaiVapor

public func configure(_ app: Application) throws {
    // Initialize Hokusai
    try app.hokusai.configure()

    // Your other configuration...
    try routes(app)
}
```

### 2. Use in your routes

```swift
import Vapor
import HokusaiVapor

func routes(_ app: Application) throws {
    // Simple text overlay endpoint
    app.post("watermark") { req async throws -> Response in
        let image = try await req.hokusaiImage()

        let watermarked = try image.drawText(
            "© 2024 MyCompany",
            x: 10,
            y: 10,
            options: TextOptions(
                font: "Arial",
                fontSize: 24,
                color: [255, 255, 255, 200]
            )
        )

        return try watermarked.response(format: "jpeg", quality: 85)
    }
}
```

### 3. Use pre-built routes

```swift
import HokusaiVapor

func routes(_ app: Application) throws {
    let api = app.grouped("api", "images")

    // Registers /api/images/text and /api/images/convert
    try ImageProcessingRoutes.register(to: api)
}
```

## API Documentation

### Application Configuration

```swift
import HokusaiVapor

// Configure in configure.swift
try app.hokusai.configure()

// Access version info
print(app.hokusai.vipsVersion)    // "8.15.1"
print(app.hokusai.magickVersion)  // "6.9.11-60"
```

### Request Extensions

#### Load from Request Body

```swift
app.post("process") { req async throws -> Response in
    // Load image from raw request body
    let image = try await req.hokusaiImage()

    // Process the image
    let resized = try image.resize(width: 800)

    return try resized.response(format: "jpeg", quality: 85)
}
```

**Test with curl:**
```bash
curl -X POST http://localhost:8080/process \
  --data-binary "@photo.jpg" \
  -o output.jpg
```

#### Load from Multipart Form Data

```swift
app.post("upload") { req async throws -> Response in
    // Load from multipart field named "image"
    let image = try await req.hokusaiImage(field: "image")

    let thumbnail = try image.resize(width: 200, height: 200)

    return try thumbnail.response(format: "png")
}
```

**Test with curl:**
```bash
curl -X POST http://localhost:8080/upload \
  -F "image=@photo.jpg" \
  -o thumbnail.png
```

### Response Conversion

```swift
extension HokusaiImage {
    func response(
        format: String = "jpeg",
        quality: Int? = nil,
        compression: Int? = nil,
        status: HTTPStatus = .ok
    ) throws -> Response
}
```

**Supported formats:**
- `jpeg` / `jpg` - JPEG with quality 1-100 (default: 85)
- `png` - PNG with compression 0-9 (default: 6)
- `webp` - WebP with quality 1-100 (default: 80)
- `avif` - AVIF with quality 1-100 (default: 75)
- `gif` - GIF
- `tiff` / `tif` - TIFF

**Examples:**
```swift
// JPEG with custom quality
return try image.response(format: "jpeg", quality: 90)

// PNG with maximum compression
return try image.response(format: "png", compression: 9)

// WebP
return try image.response(format: "webp", quality: 80)

// Custom status code
return try image.response(format: "jpeg", status: .created)
```

## Pre-built Routes

### Text Overlay Route

**Endpoint:** `POST /text?text=Hello&fontSize=48&x=100&y=200`

**Query Parameters:**
- `text` (required) - Text to render
- `fontSize` (optional) - Font size in pixels (default: 48)
- `font` (optional) - Font path or name (default: "DejaVu-Sans")
- `x` (optional) - X position (default: center)
- `y` (optional) - Y position (default: center)
- `strokeWidth` (optional) - Text outline width
- `quality` (optional) - Output quality 1-100 (default: 90)

**Example:**
```bash
curl -X POST "http://localhost:8080/api/images/text?text=Hello&fontSize=64&strokeWidth=2" \
  --data-binary "@photo.jpg" \
  -o with_text.jpg
```

### Format Conversion Route

**Endpoint:** `POST /convert?format=webp&quality=80`

**Query Parameters:**
- `format` (required) - Target format: jpeg, png, webp, avif, gif, tiff
- `quality` (optional) - Quality 1-100
- `compression` (optional) - PNG compression 0-9

**Example:**
```bash
curl -X POST "http://localhost:8080/api/images/convert?format=webp&quality=80" \
  --data-binary "@photo.jpg" \
  -o photo.webp
```

## Advanced Usage

### Custom Route with Multiple Operations

```swift
app.post("thumbnail") { req async throws -> Response in
    struct Query: Content {
        let width: Int
        let height: Int
        let text: String?
    }

    let params = try req.query.decode(Query.self)
    let image = try await req.hokusaiImage()

    // Create thumbnail
    var processed = try image.resizeToCover(
        width: params.width,
        height: params.height
    )

    // Optionally add watermark
    if let text = params.text {
        processed = try processed.drawText(
            text,
            x: 10,
            y: params.height - 30,
            options: TextOptions(
                font: "Arial",
                fontSize: 20,
                color: [255, 255, 255, 200],
                strokeColor: [0, 0, 0, 200],
                strokeWidth: 1.0
            )
        )
    }

    return try processed.response(format: "jpeg", quality: 85)
}
```

### Certificate Generation Example

```swift
struct CertificateController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.post("generate", use: generate)
    }

    func generate(req: Request) async throws -> Response {
        struct Query: Content {
            let name: String
        }

        let params = try req.query.decode(Query.self)

        // Load certificate template
        let cert = try await Hokusai.image(from: "/path/to/template.png")

        // Configure custom font
        var textOptions = TextOptions()
        textOptions.font = "/path/to/CustomFont.ttf"
        textOptions.fontSize = 96
        textOptions.color = [0, 0, 128, 255]
        textOptions.strokeColor = [255, 255, 255, 255]
        textOptions.strokeWidth = 2.0

        // Add name to certificate
        let width = try cert.width
        let height = try cert.height

        let withText = try cert.drawText(
            params.name,
            x: width / 2,
            y: Int(Double(height) * 0.6),
            options: textOptions
        )

        return try withText.response(format: "png", compression: 9)
    }
}

// Register in routes
try app.register(collection: CertificateController())
```

**Test:**
```bash
curl -X POST "http://localhost:8080/generate?name=John%20Doe" \
  -o certificate.png
```

### Metadata Endpoint

```swift
app.post("metadata") { req async throws -> Response in
    struct MetadataResponse: Content {
        let width: Int
        let height: Int
        let format: String?
        let hasAlpha: Bool
    }

    let image = try await req.hokusaiImage()
    let metadata = try image.metadata()

    let response = MetadataResponse(
        width: metadata.width,
        height: metadata.height,
        format: metadata.format?.rawValue,
        hasAlpha: metadata.hasAlpha
    )

    return try await response.encodeResponse(for: req)
}
```

## Docker Deployment

### Dockerfile Example

```dockerfile
# Build stage
FROM swift:6.1-noble AS build

# Install dependencies
RUN apt-get update && apt-get install -y \
    libvips-dev \
    libmagick++-dev \
    libmagickwand-dev \
    pkg-config

# Create ImageMagick pkg-config symlink
RUN ln -s /usr/lib/$(uname -m)-linux-gnu/pkgconfig/MagickWand-6.Q16.pc \
          /usr/lib/$(uname -m)-linux-gnu/pkgconfig/MagickWand.pc

# Copy source code
WORKDIR /build
COPY . .

# Build application
RUN swift build -c release

# Runtime stage
FROM swift:6.1-noble-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libvips \
    libmagickcore-6.q16-7 \
    libmagickwand-6.q16-7 \
    fonts-dejavu-core \
    fontconfig \
    && rm -rf /var/lib/apt/lists/*

# Copy custom fonts
COPY fonts/ /usr/share/fonts/custom/
RUN fc-cache -f -v

# Copy executable
COPY --from=build /build/.build/release/App /app/

EXPOSE 8080
CMD ["/app/App", "serve", "--env", "production", "--hostname", "0.0.0.0"]
```

### docker-compose.yml

```yaml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - LOG_LEVEL=info
    volumes:
      - ./templates:/app/templates
```

### Build and Run

```bash
# Build image
docker compose build

# Run container
docker compose up

# Test endpoint
curl -X POST "http://localhost:8080/api/images/text?text=Hello" \
  --data-binary "@photo.jpg" \
  -o output.jpg
```

## Performance Considerations

### Memory Usage

Request body size limits can be configured in Vapor:

```swift
// In configure.swift
app.routes.defaultMaxBodySize = "10mb"  // Adjust based on your needs
```

### Concurrent Processing

Hokusai is thread-safe and can handle concurrent requests:

```swift
// Process multiple images concurrently
app.post("batch") { req async throws -> [String] in
    struct BatchRequest: Content {
        let images: [Data]
    }

    let batch = try req.content.decode(BatchRequest.self)

    return try await withThrowingTaskGroup(of: String.self) { group in
        for (index, imageData) in batch.images.enumerated() {
            group.addTask {
                let image = try await Hokusai.image(from: imageData)
                let resized = try image.resize(width: 800)
                let filename = "output_\(index).jpg"
                try resized.toFile("/tmp/\(filename)")
                return filename
            }
        }

        var results: [String] = []
        for try await result in group {
            results.append(result)
        }
        return results
    }
}
```

## Error Handling

```swift
app.post("process") { req async throws -> Response in
    do {
        let image = try await req.hokusaiImage()
        let processed = try image.resize(width: 800)
        return try processed.response(format: "jpeg")
    } catch let error as HokusaiError {
        throw Abort(.badRequest, reason: "Image processing failed: \(error)")
    } catch let error as AbortError {
        throw error
    } catch {
        throw Abort(.internalServerError, reason: "Unexpected error: \(error)")
    }
}
```

## Troubleshooting

### "No image data in request body" Error

Make sure you're sending the image data in the request body:

```bash
# Correct - binary data in body
curl -X POST http://localhost:8080/process \
  --data-binary "@photo.jpg"

# Incorrect - will fail
curl -X POST http://localhost:8080/process
```

### Font Not Found in Docker

Ensure fonts are copied to the container and font cache is updated:

```dockerfile
COPY fonts/ /usr/share/fonts/custom/
RUN fc-cache -f -v
```

Verify fonts are installed:

```bash
docker exec -it container_name fc-list | grep YourFont
```

### pkg-config Errors in Docker

For Ubuntu/Debian, create the ImageMagick symlink:

```dockerfile
RUN ln -s /usr/lib/$(uname -m)-linux-gnu/pkgconfig/MagickWand-6.Q16.pc \
          /usr/lib/$(uname -m)-linux-gnu/pkgconfig/MagickWand.pc
```

## Examples

See the [hokusai-vapor-example](https://github.com/ivantokar/hokusai-vapor-example) demo app for a complete working example with:
- Interactive web UI for testing features
- Certificate generation with custom fonts
- Image metadata extraction
- Format conversion (JPEG, PNG, WebP, AVIF, GIF)
- Text overlay with stroke effects
- Resize and rotate operations
- Docker deployment

## Contributing

Contributions welcome! Please see the main [Hokusai](../hokusai) repository.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Related Projects

- [Hokusai](https://github.com/ivantokar/hokusai) - Core hybrid image processing library
- [hokusai-vapor-example](https://github.com/ivantokar/hokusai-vapor-example) - Complete demo app with web UI
