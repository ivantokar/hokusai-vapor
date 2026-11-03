import Foundation
import Hokusai
import HokusaiVapor
import NIOCore
import Vapor
import XCTVapor

/// A 24x16 gradient as an uncompressed little-endian TIFF, so the tests need no fixture files.
func gradientTIFF(width: Int = 24, height: Int = 16) -> Data {
    var data = Data()
    func u16(_ value: Int) { data.append(contentsOf: [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)]) }
    func u32(_ value: Int) { u16(value & 0xFFFF); u16((value >> 16) & 0xFFFF) }
    func entry(_ tag: Int, _ type: Int, _ count: Int, _ value: Int) { u16(tag); u16(type); u32(count); u32(value) }
    let entries = 9
    let arrayOffset = 8 + 2 + entries * 12 + 4
    let pixelOffset = arrayOffset + 6
    data.append(contentsOf: [0x49, 0x49, 42, 0])
    u32(8)
    u16(entries)
    entry(256, 4, 1, width); entry(257, 4, 1, height); entry(258, 3, 3, arrayOffset)
    entry(259, 3, 1, 1); entry(262, 3, 1, 2); entry(273, 4, 1, pixelOffset)
    entry(277, 3, 1, 3); entry(278, 4, 1, height); entry(279, 4, 1, width * height * 3)
    u32(0)
    for _ in 0..<3 { u16(8) }
    for y in 0..<height { for x in 0..<width { data.append(contentsOf: [UInt8(x * 10 % 256), UInt8(y * 14 % 256), UInt8((x + y) % 256)]) } }
    return data
}

final class HokusaiVaporTests: XCTestCase {
    private func makeApp() async throws -> Application {
        let app = try await Application.make(.testing)
        app.routes.defaultMaxBodySize = "1mb"
        app.grouped(HokusaiErrorMiddleware()).group("") { routes in
            routes.post("webp") { req async throws -> Response in
                try await req.hokusaiImage(maximumSize: 1 << 20).resize(width: 12).webp(quality: 80).response()
            }
            routes.post("png") { req async throws -> Response in
                try await req.hokusaiImage(maximumSize: 1 << 20).png().response(headers: ["Cache-Control": "no-store"])
            }
            routes.post("pdf") { req async throws -> Response in
                try await req.hokusaiImage(maximumSize: 1 << 20).pdf().response()
            }
            routes.post("small") { req async throws -> Response in
                try await req.hokusaiImage(maximumSize: 100).png().response()
            }
            routes.post("noencoder") { req async throws -> Response in
                try await req.hokusaiImage(maximumSize: 1 << 20).response()
            }
            routes.post("evaluate") { req async throws -> Response in
                // Evaluates the pipeline itself and relies on the middleware for its errors.
                let image = try await req.hokusaiImage(
                    options: InputOptions(limits: InputLimits(maxPixels: 10)), maximumSize: 1 << 20)
                let output = try await image.png().data()
                return Response(status: .ok, body: .init(data: output.data))
            }
        }
        try ImageProcessingRoutes.register(to: app.grouped("api", "images"))
        return app
    }

    private func withApp(_ body: (Application) async throws -> Void) async throws {
        let app = try await makeApp()
        do { try await body(app) } catch { try await app.asyncShutdown(); throw error }
        try await app.asyncShutdown()
    }

    private func canEncode(_ format: ImageFormat) -> Bool { (try? Hokusai.capabilities().canEncode(format)) ?? false }

    func testWebPResponseIsADecodableImageWithItsContentType() async throws {
        try XCTSkipUnless(canEncode(.webp))
        try await withApp { app in
            try await app.test(.POST, "webp", body: ByteBuffer(data: gradientTIFF())) { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.headers.first(name: .contentType), "image/webp")
                let info = try await Hokusai(data: Data(buffer: res.body)).metadata()
                XCTAssertEqual(info.width, 12)
            }
        }
    }

    func testExtraHeadersAreKeptAndPNGIsSent() async throws {
        try await withApp { app in
            try await app.test(.POST, "png", body: ByteBuffer(data: gradientTIFF())) { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.headers.first(name: .contentType), "image/png")
                XCTAssertEqual(res.headers.first(name: .cacheControl), "no-store")
                let info = try await Hokusai(data: Data(buffer: res.body)).metadata()
                XCTAssertEqual(info.width, 24)
            }
        }
    }

    func testPDFResponseHasPDFContentType() async throws {
        try await withApp { app in
            try await app.test(.POST, "pdf", body: ByteBuffer(data: gradientTIFF())) { res async throws in
                XCTAssertEqual(res.headers.first(name: .contentType), "application/pdf")
                XCTAssertTrue(Data(buffer: res.body).starts(with: Data("%PDF-".utf8)))
            }
        }
    }

    func testAnUploadOverTheLimitIs413() async throws {
        try await withApp { app in
            try await app.test(.POST, "small", body: ByteBuffer(data: gradientTIFF())) { res async throws in
                XCTAssertEqual(res.status, .payloadTooLarge)
            }
        }
    }

    func testAnEmptyBodyIs400() async throws {
        try await withApp { app in
            try await app.test(.POST, "png") { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        }
    }

    func testAnUndecodableUploadIsA4xxBeforeAnyBodyIsSent() async throws {
        try await withApp { app in
            try await app.test(.POST, "png", body: ByteBuffer(string: "not an image")) { res async throws in
                XCTAssertEqual(res.status, .unprocessableEntity)
            }
        }
    }

    func testAPipelineWithoutAnEncoderIs500() async throws {
        try await withApp { app in
            try await app.test(.POST, "noencoder", body: ByteBuffer(data: gradientTIFF())) { res async throws in
                XCTAssertEqual(res.status, .internalServerError)
            }
        }
    }

    func testTheMiddlewareMapsAnErrorFromARouteThatEvaluatesItself() async throws {
        try await withApp { app in
            try await app.test(.POST, "evaluate", body: ByteBuffer(data: gradientTIFF())) { res async throws in
                XCTAssertEqual(res.status, .unprocessableEntity)
            }
        }
    }

    func testTheConvertRouteChoosesTheEncoder() async throws {
        try await withApp { app in
            try await app.test(.POST, "api/images/convert?format=png", body: ByteBuffer(data: gradientTIFF())) { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.headers.first(name: .contentType), "image/png")
            }
            try await app.test(.POST, "api/images/convert?format=bmp", body: ByteBuffer(data: gradientTIFF())) { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            }
        }
    }

    func testTheTextRouteReturnsAJPEGOfTheSameSize() async throws {
        try await withApp { app in
            try await app.test(.POST, "api/images/text?text=Hi&fontSize=8", body: ByteBuffer(data: gradientTIFF(width: 64, height: 48))) { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.headers.first(name: .contentType), "image/jpeg")
                let info = try await Hokusai(data: Data(buffer: res.body)).metadata()
                XCTAssertEqual(info.width, 64)
                XCTAssertEqual(info.height, 48)
            }
        }
    }

    func testTheHttpStatusFollowsTheErrorCase() {
        XCTAssertEqual(HokusaiError.invalidInput(reason: "x").httpStatus, .badRequest)
        XCTAssertEqual(HokusaiError.invalidOption(name: "n", reason: "x").httpStatus, .badRequest)
    }
}
