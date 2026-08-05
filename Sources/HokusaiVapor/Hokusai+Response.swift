import Vapor
import Hokusai

extension Hokusai {
    /// Evaluates a configured 1.0 pipeline and returns a Vapor image/PDF response.
    public func response(
        format: String = "jpeg",
        quality: Int? = nil,
        compression: Int? = nil,
        status: HTTPStatus = .ok
    ) async throws -> Response {
        let outputFormat = try HokusaiVaporOutput.format(
            named: format, quality: quality, compression: compression
        )
        let output = try await encode(as: outputFormat).data()
        return Response(
            status: status,
            headers: ["Content-Type": output.info.format.mimeType],
            body: .init(data: output.data)
        )
    }
}

private enum HokusaiVaporOutput {
    static func format(named name: String, quality: Int?, compression: Int?) throws -> OutputFormat {
        switch name.lowercased() {
        case "jpeg", "jpg": return .jpeg(.init(quality: quality ?? 80))
        case "png": return .png(.init(compressionLevel: compression ?? quality ?? 6))
        case "webp": return .webp(.init(quality: quality ?? 80))
        case "avif": return .avif(.init(quality: quality ?? 50))
        case "pdf": return .pdf()
        default: throw Abort(.badRequest, reason: "Unsupported Hokusai 1.0 output format: \(name)")
        }
    }
}
