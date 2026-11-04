import Foundation
import Hokusai
import HokusaiVapor
import NIOCore
import NIOPosix
import Vapor
import XCTest

/// Real connections to a real server (hokusai #126): a client that reads slowly, a
/// client that disconnects part-way, and the evaluation slot afterwards.
final class LiveHTTPTests: XCTestCase {
    private func withServer(
        _ pipeline: Hokusai, chunkSize: Int = 16 * 1024, _ body: (Int) async throws -> Void
    ) async throws {
        let app = try await Application.make(.testing)
        app.get("image") { _ async throws -> Response in try await pipeline.response(chunkSize: chunkSize) }
        try await app.server.start(address: .hostname("127.0.0.1", port: 0))
        let port = app.http.server.shared.localAddress?.port ?? 0
        XCTAssertNotEqual(port, 0, "the server did not report its port")
        do { try await body(port) } catch {
            await app.server.shutdown()
            try await app.asyncShutdown()
            throw error
        }
        await app.server.shutdown()
        try await app.asyncShutdown()
    }

    private func connect(_ port: Int) async throws -> NIOAsyncChannel<ByteBuffer, ByteBuffer> {
        try await ClientBootstrap(group: NIOSingletons.posixEventLoopGroup)
            .connect(host: "127.0.0.1", port: port) { channel in
                channel.eventLoop.makeCompletedFuture { try NIOAsyncChannel(wrappingChannelSynchronously: channel) }
            }
    }

    private let requestText = "GET /image HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"

    private func slotsRelease(within seconds: Double = 15) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if Hokusai.runtimeStatus.activeEvaluations == 0 { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    private func decodeChunked(_ bytes: [UInt8]) -> (payload: [UInt8], complete: Bool) {
        var payload: [UInt8] = []
        var index = bytes.firstRange(of: [13, 10, 13, 10]).map { $0.upperBound } ?? bytes.count
        while index < bytes.count {
            guard let lineEnd = bytes[index...].firstRange(of: [13, 10])?.lowerBound,
                let size = Int(String(decoding: bytes[index..<lineEnd], as: UTF8.self), radix: 16)
            else { return (payload, false) }
            index = lineEnd + 2
            if size == 0 { return (payload, true) }
            guard index + size <= bytes.count else { return (payload, false) }
            payload += bytes[index..<index + size]
            index += size + 2
        }
        return (payload, false)
    }

    func testASlowReadingClientReceivesEveryByte() async throws {
        let pipeline = try Hokusai(data: gradientTIFF(width: 600, height: 400)).png(compressionLevel: 0)
        let expected = try await pipeline.data().data
        try await withServer(pipeline) { port in
            let channel = try await connect(port)
            var received: [UInt8] = []
            try await channel.executeThenClose { inbound, outbound in
                try await outbound.write(ByteBuffer(string: requestText))
                for try await buffer in inbound {
                    received += buffer.readableBytesView
                    try await Task.sleep(for: .milliseconds(20))   // far slower than the encoder
                }
            }
            let (payload, complete) = decodeChunked(received)
            XCTAssertTrue(complete, "the chunked body was not terminated")
            XCTAssertEqual(payload, [UInt8](expected), "\(payload.count) bytes arrived, expected \(expected.count)")
        }
        let released = await slotsRelease()
        XCTAssertTrue(released)
    }

    func testAClientThatDisconnectsMidResponseReleasesTheEvaluation() async throws {
        let pipeline = try Hokusai(data: gradientTIFF(width: 2000, height: 2000)).png(compressionLevel: 0)
        try await withServer(pipeline, chunkSize: 4096) { port in
            for _ in 0..<5 {
                let channel = try await connect(port)
                try await channel.executeThenClose { inbound, outbound in
                    try await outbound.write(ByteBuffer(string: requestText))
                    var seen = 0
                    for try await buffer in inbound {
                        seen += buffer.readableBytes
                        if seen > 20_000 { break }   // leaves the loop, which closes the connection
                    }
                }
            }
            let released = await slotsRelease()
            XCTAssertTrue(released, "an evaluation still holds a slot after every client left")
        }
    }

    func testTheServerStillServesAfterDroppedConnections() async throws {
        let pipeline = try Hokusai(data: gradientTIFF(width: 800, height: 800)).png(compressionLevel: 0)
        let expected = try await pipeline.data().data
        try await withServer(pipeline, chunkSize: 4096) { port in
            for _ in 0..<3 {
                let channel = try await connect(port)
                try await channel.executeThenClose { inbound, outbound in
                    try await outbound.write(ByteBuffer(string: requestText))
                    for try await _ in inbound { break }
                }
            }
            let channel = try await connect(port)
            var received: [UInt8] = []
            try await channel.executeThenClose { inbound, outbound in
                try await outbound.write(ByteBuffer(string: requestText))
                for try await buffer in inbound { received += buffer.readableBytesView }
            }
            let (payload, complete) = decodeChunked(received)
            XCTAssertTrue(complete && payload == [UInt8](expected), "a full request after dropped ones did not get the whole image")
        }
    }
}
