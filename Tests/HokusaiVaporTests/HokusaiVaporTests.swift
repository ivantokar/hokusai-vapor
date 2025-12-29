import Foundation
import Hokusai
import HokusaiVapor
import Testing
import Vapor

private actor HokusaiTestRuntime {
    static let shared = HokusaiTestRuntime()
    private var isInitialized = false

    func withHokusai<T>(_ work: () async throws -> T) async throws -> T {
        if !isInitialized {
            try Hokusai.initialize()
            isInitialized = true
        }

        return try await work()
    }
}

private let samplePngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO9KX5kAAAAASUVORK5CYII="

@Test("PNG response sets content type and body")
func pngResponseHasHeaders() async throws {
    let response = try await HokusaiTestRuntime.shared.withHokusai {
        let data = try #require(Data(base64Encoded: samplePngBase64))
        let image = try await Hokusai.image(from: data)
        return try image.response(format: "png")
    }

    let bodyBytes = response.body.buffer?.readableBytes ?? 0

    #expect(response.status == .ok)
    #expect(response.headers["Content-Type"].first == "image/png")
    #expect(bodyBytes > 0)
}
