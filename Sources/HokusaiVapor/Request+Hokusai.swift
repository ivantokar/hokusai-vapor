import Hokusai
import HokusaiNIO
import NIOCore
import Vapor

extension Request {
    /// Reads a raw image upload into an immutable Hokusai pipeline.
    ///
    /// Hokusai decodes a complete source, so the body is collected, but never
    /// beyond `maximumSize`: a declared `Content-Length` over the limit is
    /// rejected before any byte is read, and a body without one is rejected as
    /// soon as it grows past the limit. Both give `413 Payload Too Large`, and
    /// an empty body gives `400 Bad Request`. Vapor's own
    /// `defaultMaxBodySize` still applies to the route and should be at least
    /// `maximumSize`.
    ///
    /// Nothing is decoded here, so a corrupt image surfaces when the pipeline
    /// is evaluated (``Hokusai/response(status:headers:chunkSize:)`` does that
    /// before it commits to a response).
    ///
    /// - Parameters:
    ///   - options: Input options, including Hokusai's own decode limits.
    ///   - maximumSize: Largest accepted upload, in bytes.
    public func hokusaiImage(
        options: InputOptions = .init(),
        maximumSize: Int = 20 * 1024 * 1024
    ) async throws -> Hokusai {
        guard maximumSize > 0 else {
            throw Abort(.internalServerError, reason: "The Hokusai maximum upload size must be positive")
        }
        let declared = headers.first(name: .contentLength).flatMap { Int($0) }
        if let declared, declared > maximumSize {
            throw Abort(.payloadTooLarge, reason: "The image upload exceeds the configured size limit")
        }

        var collected = ByteBufferAllocator().buffer(capacity: min(declared ?? 64 * 1024, maximumSize))
        for try await buffer in body {
            guard buffer.readableBytes <= maximumSize - collected.readableBytes else {
                throw Abort(.payloadTooLarge, reason: "The image upload exceeds the configured size limit")
            }
            var buffer = buffer
            collected.writeBuffer(&buffer)
        }
        return try pipeline(from: collected, options: options)
    }

    /// Reads a multipart file field into an immutable Hokusai pipeline.
    ///
    /// The file is already in memory (Vapor collects multipart bodies up to
    /// its `defaultMaxBodySize`), so only `Hokusai`'s own limits in `options`
    /// apply on top. A missing or empty field gives `400 Bad Request`.
    public func hokusaiImage(field: String, options: InputOptions = .init()) throws -> Hokusai {
        guard let file = try content.decode([String: File].self)[field] else {
            throw Abort(.badRequest, reason: "No file uploaded for field '\(field)'")
        }
        return try pipeline(from: file.data, options: options)
    }

    private func pipeline(from buffer: ByteBuffer, options: InputOptions) throws -> Hokusai {
        guard buffer.readableBytes > 0 else {
            throw Abort(.badRequest, reason: "No image data in the request body")
        }
        do {
            return try Hokusai(buffer: buffer, options: options)
        } catch let error as HokusaiError {
            throw error.abort
        }
    }
}
