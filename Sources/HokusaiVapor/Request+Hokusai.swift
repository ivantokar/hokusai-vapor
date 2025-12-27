import Vapor
import Hokusai

extension Request {
    /// Load a HokusaiImage from the request body
    public func hokusaiImage() async throws -> HokusaiImage {
        guard let buffer = body.data else {
            throw Abort(.badRequest, reason: "No image data in request body")
        }
        // Convert ByteBuffer to Data using getData method
        guard let data = buffer.getData(at: buffer.readerIndex, length: buffer.readableBytes) else {
            throw Abort(.badRequest, reason: "Failed to read image data from request")
        }
        return try await Hokusai.image(from: data)
    }

    /// Load a HokusaiImage from multipart form data
    public func hokusaiImage(field: String) async throws -> HokusaiImage {
        // Get the file from multipart form data
        guard let file = try content.decode([String: File].self)[field] else {
            throw Abort(.badRequest, reason: "No file uploaded for field '\(field)'")
        }
        // Convert ByteBuffer to Data using getData method
        guard let data = file.data.getData(at: file.data.readerIndex, length: file.data.readableBytes) else {
            throw Abort(.badRequest, reason: "Failed to read file data")
        }
        return try await Hokusai.image(from: data)
    }
}
