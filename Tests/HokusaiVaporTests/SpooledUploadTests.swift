import Foundation
import Hokusai
import HokusaiVapor
import NIOCore
import Vapor
import XCTVapor

/// Uploads spooled to a temporary file (hokusai#112): the route reads the body with
/// `memoryLimit: 0`, so every upload goes through the spool file, and the file must be gone
/// once the request is over.
final class SpooledUploadTests: XCTestCase {
    private func withApp(spool: URL, _ body: (Application) async throws -> Void) async throws {
        let app = try await Application.make(.testing)
        app.routes.defaultMaxBodySize = "1mb"
        app.grouped(HokusaiErrorMiddleware()).group("") { routes in
            routes.post("spool") { req async throws -> Response in
                try await req.hokusaiImage(maximumSize: 1 << 20, memoryLimit: 0, spoolDirectory: spool)
                    .png().response()
            }
            routes.post("small") { req async throws -> Response in
                try await req.hokusaiImage(maximumSize: 100, memoryLimit: 0, spoolDirectory: spool)
                    .png().response()
            }
        }
        do { try await body(app) } catch { try await app.asyncShutdown(); throw error }
        try await app.asyncShutdown()
    }

    private func scratchDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("hokusai-vapor-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    /// The pipeline is released when the response has been sent, which can be a moment after the
    /// client has read it, so the directory is polled briefly.
    private func assertEmpty(_ directory: URL, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<50 {
            if try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("the spool file was left behind", file: file, line: line)
    }

    func testASpooledUploadIsProcessedAndItsFileRemoved() async throws {
        let spool = try scratchDirectory()
        try await withApp(spool: spool) { app in
            try await app.test(.POST, "spool", body: ByteBuffer(data: gradientTIFF())) { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.headers.first(name: .contentType), "image/png")
                let info = try await Hokusai(data: Data(buffer: res.body)).metadata()
                XCTAssertEqual(info.width, 24)
            }
        }
        try await assertEmpty(spool)
    }

    func testAnUploadOverTheLimitIs413AndLeavesNoFile() async throws {
        let spool = try scratchDirectory()
        try await withApp(spool: spool) { app in
            try await app.test(.POST, "small", body: ByteBuffer(data: gradientTIFF())) { res async throws in
                XCTAssertEqual(res.status, .payloadTooLarge)
            }
        }
        try await assertEmpty(spool)
    }

    func testAnEmptyBodyIs400AndLeavesNoFile() async throws {
        let spool = try scratchDirectory()
        try await withApp(spool: spool) { app in
            try await app.test(.POST, "spool") { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        }
        try await assertEmpty(spool)
    }

    func testAMissingSpoolDirectoryIs500() async throws {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("hokusai-missing-\(UUID().uuidString)")
        try await withApp(spool: missing) { app in
            try await app.test(.POST, "spool", body: ByteBuffer(data: gradientTIFF())) { res async throws in
                XCTAssertEqual(res.status, .internalServerError)
            }
        }
    }
}
