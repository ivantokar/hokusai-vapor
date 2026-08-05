import Vapor
import Hokusai

/// PURPOSE: Provide ready-to-use Vapor handlers for common image operations.
/// STABILITY: Flexible
/// AI HINTS:
/// - Keep handlers simple examples, not a full application framework.
/// - Validate query/body inputs before invoking image operations.
public struct ImageProcessingRoutes {
    /// PURPOSE: Register sample text/convert routes under provided route group.
    ///
    /// Example:
    /// ```swift
    /// try ImageProcessingRoutes.register(to: app.grouped("api", "images"))
    /// ```
    public static func register(to routes: RoutesBuilder) throws {
        routes.post("text", use: addText)
        routes.post("convert", use: convert)
    }

    // MARK: - Route Handlers

    /// PURPOSE: Render text overlay using query params + raw request image body.
    /// POST /text?text=Hello&fontSize=48&font=/path/to/font.ttf&x=100&y=200
    /// Body: raw image data
    public static func addText(_ req: Request) async throws -> Response {
        struct TextQuery: Content {
            let text: String
            let fontSize: Int?
            let font: String?
            let x: Int?
            let y: Int?
            let strokeWidth: Double?
            let quality: Int?
        }

        let params = try req.query.decode(TextQuery.self)
        let image = try req.hokusaiImage()

        var textOptions = TextOptions()
        textOptions.font = params.font ?? "DejaVu-Sans"
        textOptions.fontSize = params.fontSize ?? 48
        textOptions.color = [0, 0, 0, 255]  // Black

        // Add white stroke for visibility
        if let strokeWidth = params.strokeWidth {
            textOptions.strokeColor = [255, 255, 255, 255]
            textOptions.strokeWidth = strokeWidth
        }

        // PURPOSE: Use center position if x, y not specified
        let metadata = try image.metadata()
        let x = params.x ?? (metadata.width / 2)
        let y = params.y ?? (metadata.height / 2)

        let withText = try image.drawText(
            params.text,
            x: x,
            y: y,
            options: textOptions
        )

        return try await withText.response(format: "jpeg", quality: params.quality ?? 90)
    }

    /// PURPOSE: Convert uploaded image to requested output format.
    /// POST /convert?format=png&quality=85
    /// Body: raw image data
    public static func convert(_ req: Request) async throws -> Response {
        struct ConvertQuery: Content {
            let format: String  // "jpeg", "png", "webp", etc.
            let quality: Int?
            let compression: Int?
        }

        let params = try req.query.decode(ConvertQuery.self)
        let image = try req.hokusaiImage()

        return try await image.response(
            format: params.format,
            quality: params.quality,
            compression: params.compression
        )
    }
}
