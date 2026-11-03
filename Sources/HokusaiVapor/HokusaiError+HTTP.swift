import Hokusai
import Vapor

extension HokusaiError {
    /// The HTTP status a request should fail with.
    ///
    /// The caller's mistakes are `4xx` and everything about this server is
    /// `5xx`, decided by the error case and never by message text:
    ///
    /// | Case | Status |
    /// | --- | --- |
    /// | `invalidInput`, `invalidOption` | 400 |
    /// | `decode` | 422 |
    /// | `resource` for bytes | 413 |
    /// | `resource` for pixels or channels | 422 |
    /// | `resource` for the evaluation queue | 503 |
    /// | `unsupported` | 501 |
    /// | `io`, `transform`, `encode`, `runtime` | 500 |
    public var httpStatus: HTTPStatus {
        switch self {
        case .invalidInput, .invalidOption: .badRequest
        case .decode: .unprocessableEntity
        case .resource(let failure):
            switch failure.kind {
            case .encodedBytes: .payloadTooLarge
            case .queuedEvaluations: .serviceUnavailable
            default: .unprocessableEntity
            }
        case .unsupported: .notImplemented
        case .io, .transform, .encode, .runtime: .internalServerError
        }
    }

    /// ``httpStatus`` with Hokusai's own description as the reason.
    public var abort: Abort {
        Abort(httpStatus, reason: errorDescription ?? "Image processing failed")
    }
}

/// Turns a ``HokusaiError`` thrown by a route into its ``HokusaiError/abort``.
///
/// ``Hokusai/response(status:headers:chunkSize:)`` and
/// ``Request/hokusaiImage(options:maximumSize:)`` already do this for what they
/// run; add the middleware for pipelines a route evaluates itself with
/// `data()` or `write(to:)`. `CancellationError` passes through.
public struct HokusaiErrorMiddleware: AsyncMiddleware {
    public init() {}

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch let error as HokusaiError {
            throw error.abort
        }
    }
}
