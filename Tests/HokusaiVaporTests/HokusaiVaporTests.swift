import Foundation
import Hokusai
import HokusaiVapor
import Vapor
import XCTest

private actor HokusaiTestRuntime {
    static let shared = HokusaiTestRuntime()
    private var isInitialized = false

    func ensureInitialized() throws {
        if !isInitialized {
            try Hokusai.initialize()
            isInitialized = true
        }
    }
}

private let samplePngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO9KX5kAAAAASUVORK5CYII="

final class HokusaiVaporTests: XCTestCase {
    func testPNGResponseHasHeaders() async throws {
        try await HokusaiTestRuntime.shared.ensureInitialized()

        let data = try XCTUnwrap(Data(base64Encoded: samplePngBase64))
        let image = try await Hokusai.image(from: data)
        let response = try image.response(format: "png")
        let bodyBytes = response.body.buffer?.readableBytes ?? 0

        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(response.headers["Content-Type"].first, "image/png")
        XCTAssertGreaterThan(bodyBytes, 0)
    }
}
