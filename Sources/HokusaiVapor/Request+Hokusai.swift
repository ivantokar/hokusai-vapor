import Foundation
import Hokusai
import HokusaiNIO
import NIOCore
import Vapor

extension Request {
    /// Reads a raw image upload into an immutable Hokusai pipeline.
    ///
    /// The body is read as it arrives and never beyond `maximumSize`: a declared
    /// `Content-Length` over the limit is rejected before any byte is read, and a
    /// body without one is rejected as soon as it grows past the limit. Both give
    /// `413 Payload Too Large`, and an empty body gives `400 Bad Request`. Vapor's
    /// own `defaultMaxBodySize` still applies to the route and should be at least
    /// `maximumSize`.
    ///
    /// A small upload stays in memory. One larger than `memoryLimit` bytes moves to
    /// a private temporary file (``Hokusai/init(spooling:options:memoryLimit:spoolDirectory:)``),
    /// so the encoded upload occupies at most `memoryLimit` plus one chunk of memory
    /// however large `maximumSize` is. The pipeline owns the file and removes it
    /// when the last copy of the pipeline is released. The route has to collect
    /// the body as a stream (`body: .stream`) for the body to arrive in pieces; a
    /// body Vapor has already collected is read from memory as before.
    ///
    /// Nothing is decoded here, so a corrupt image surfaces when the pipeline
    /// is evaluated (``Hokusai/response(status:headers:chunkSize:)`` does that
    /// before it commits to a response).
    ///
    /// - Parameters:
    ///   - options: Input options, including Hokusai's own decode limits. The
    ///     byte limit is the smaller of `options.limits.maxBytes` and `maximumSize`.
    ///   - maximumSize: Largest accepted upload, in bytes.
    ///   - memoryLimit: The largest upload kept in memory, in bytes (default 1 MiB).
    ///   - spoolDirectory: Where a larger upload is spooled. Defaults to the
    ///     system temporary directory; it must exist.
    public func hokusaiImage(
        options: InputOptions = .init(),
        maximumSize: Int = 20 * 1024 * 1024,
        memoryLimit: Int = 1_048_576,
        spoolDirectory: URL? = nil
    ) async throws -> Hokusai {
        guard maximumSize > 0 else {
            throw Abort(.internalServerError, reason: "The Hokusai maximum upload size must be positive")
        }
        if let declared = headers.first(name: .contentLength).flatMap({ Int($0) }), declared > maximumSize {
            throw Abort(.payloadTooLarge, reason: "The image upload exceeds the configured size limit")
        }
        var options = options
        options.limits.maxBytes = min(options.limits.maxBytes, maximumSize)
        do {
            return try await Hokusai(
                spooling: body, options: options, memoryLimit: memoryLimit, spoolDirectory: spoolDirectory)
        } catch let error as HokusaiError {
            throw error.abort
        }
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
