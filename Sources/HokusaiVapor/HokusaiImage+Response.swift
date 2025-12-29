import Vapor
import Hokusai

extension HokusaiImage {
    /// Convert image to Vapor Response
    ///
    /// Example:
    /// ```swift
    /// app.post("resize") { req async throws -> Response in
    ///     try await req.hokusaiImage()
    ///         .drawText("Hello", x: 100, y: 100)
    ///         .response(format: "jpeg", quality: 85)
    /// }
    /// ```
    public func response(
        format: String = "jpeg",
        quality: Int? = nil,
        compression: Int? = nil,
        status: HTTPStatus = .ok
    ) throws -> Response {
        let formatLowercased = format.lowercased()
        let targetQuality = formatLowercased == "png" ? (compression ?? quality) : quality
        let data = try toBuffer(format: format, quality: targetQuality)

        // Map format to mime type
        let mimeType = getMimeType(for: formatLowercased)

        return Response(
            status: status,
            headers: ["Content-Type": mimeType],
            body: .init(data: data)
        )
    }

    // MARK: - Helper Methods

    private func getMimeType(for format: String) -> String {
        switch format.lowercased() {
        case "jpeg", "jpg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "webp":
            return "image/webp"
        case "gif":
            return "image/gif"
        case "tiff", "tif":
            return "image/tiff"
        case "avif":
            return "image/avif"
        case "heif", "heic":
            return "image/heif"
        default:
            return "application/octet-stream"
        }
    }
}
