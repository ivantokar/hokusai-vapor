import Vapor
import Hokusai

extension Request {
    /// PURPOSE: Decode raw request body bytes into `HokusaiImage`.
    /// INPUT: Body must contain encoded image bytes.
    /// OUTPUT: Loaded image ready for processing.
    /// CONSTRAINTS: Throws `400` for missing/invalid body payload.
    public func hokusaiImage() async throws -> HokusaiImage {
        guard let buffer = body.data else {
            throw Abort(.badRequest, reason: "No image data in request body")
        }
        // PURPOSE: Convert ByteBuffer to Data using getData method
        guard let data = buffer.getData(at: buffer.readerIndex, length: buffer.readableBytes) else {
            throw Abort(.badRequest, reason: "Failed to read image data from request")
        }
        return try await Hokusai.image(from: data)
    }

    /// PURPOSE: Decode uploaded multipart file into `HokusaiImage`.
    /// INPUT: `field` key that maps to multipart `File`.
    /// OUTPUT: Loaded image ready for processing.
    /// CONSTRAINTS: Throws `400` when field/file bytes are missing.
    public func hokusaiImage(field: String) async throws -> HokusaiImage {
        // PURPOSE: Get the file from multipart form data
        guard let file = try content.decode([String: File].self)[field] else {
            throw Abort(.badRequest, reason: "No file uploaded for field '\(field)'")
        }
        // PURPOSE: Convert ByteBuffer to Data using getData method
        guard let data = file.data.getData(at: file.data.readerIndex, length: file.data.readableBytes) else {
            throw Abort(.badRequest, reason: "Failed to read file data")
        }
        return try await Hokusai.image(from: data)
    }
}
