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
        let image = try Hokusai(data: data)
        let response = try await image.response(format: "png")
        let bodyBytes = response.body.buffer?.readableBytes ?? 0

        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(response.headers["Content-Type"].first, "image/png")
        XCTAssertGreaterThan(bodyBytes, 0)
    }

    func testPDFResponseHasPDFContentType() async throws {
        let data = try XCTUnwrap(Data(base64Encoded: samplePngBase64))
        let response = try await Hokusai(data: data).response(format: "pdf")
        XCTAssertEqual(response.headers["Content-Type"].first, "application/pdf")
        XCTAssertTrue((response.body.buffer?.getData(at: 0, length: response.body.buffer?.readableBytes ?? 0) ?? Data()).starts(with: Data("%PDF-".utf8)))
    }
}
