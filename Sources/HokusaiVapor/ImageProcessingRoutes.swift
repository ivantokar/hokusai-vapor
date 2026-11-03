import Hokusai
import Vapor

/// Ready-to-use Vapor handlers for two common image operations.
///
/// These are small examples, not an application framework: validate input and
/// choose limits for your own service, and copy a handler when you need to
/// change it.
public struct ImageProcessingRoutes {
    /// Registers `POST text` and `POST convert` under the given route group.
    ///
    /// ```swift
    /// try ImageProcessingRoutes.register(to: app.grouped("api", "images"))
    /// ```
    public static func register(to routes: RoutesBuilder) throws {
        let routes = routes.grouped(HokusaiErrorMiddleware())
        routes.on(.POST, "text", body: .collect(maxSize: "20mb"), use: addText)
        routes.on(.POST, "convert", body: .collect(maxSize: "20mb"), use: convert)
    }

    // MARK: - Route handlers

    /// Draws text on the uploaded image and returns a JPEG.
    ///
    /// `POST /text?text=Hello&fontSize=48&strokeWidth=2&quality=90`, with the
    /// source image as the raw request body. The text is centred.
    public static func addText(_ req: Request) async throws -> Response {
        struct TextQuery: Content {
            let text: String
            let fontSize: Int?
            let font: String?
            let strokeWidth: Double?
            let quality: Int?
        }

        let params = try req.query.decode(TextQuery.self)
        let stroke = params.strokeWidth.map {
            TextStroke(color: Color(red: 1, green: 1, blue: 1), width: $0)
        }
        let style = TextStyle(
            font: params.font ?? "sans",
            fontSize: params.fontSize ?? 48,
            color: Color(red: 0, green: 0, blue: 0),
            stroke: stroke
        )

        return try await req.hokusaiImage()
            .drawText(.init(stringLiteral: params.text), placement: .gravity(.center), style: style)
            .jpeg(quality: params.quality ?? 90)
            .response()
    }

    /// Converts the uploaded image to the requested format.
    ///
    /// `POST /convert?format=webp&quality=82`, with the source image as the
    /// raw request body. `format` is one of `jpeg`, `png`, `webp`, `avif`, `pdf`.
    public static func convert(_ req: Request) async throws -> Response {
        struct ConvertQuery: Content {
            let format: String
            let quality: Int?
            let compression: Int?
        }

        let params = try req.query.decode(ConvertQuery.self)
        let image = try await req.hokusaiImage()
        let encoded: Hokusai
        switch params.format.lowercased() {
        case "jpeg", "jpg": encoded = try image.jpeg(quality: params.quality ?? 80)
        case "png": encoded = try image.png(compressionLevel: params.compression ?? 6)
        case "webp": encoded = try image.webp(quality: params.quality ?? 80)
        case "avif": encoded = try image.avif(quality: params.quality ?? 50)
        case "pdf": encoded = try image.pdf()
        default: throw Abort(.badRequest, reason: "Unsupported output format: \(params.format)")
        }
        return try await encoded.response()
    }
}
