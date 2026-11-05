import Foundation
import Hokusai
import HokusaiVapor
import NIOCore
import NIOPosix
import Vapor
import XCTest

/// Overload and failures after output began, over real connections (hokusai #126).
///
/// The runtime configuration freezes at first use, so these need a process of their own with a
/// single evaluation slot and no queue. They are skipped unless `HOKUSAI_OVERLOAD_TESTS=1`;
/// run them with `HOKUSAI_OVERLOAD_TESTS=1 swift test --filter OverloadTests` (CI does).
final class OverloadTests: XCTestCase {
    /// Applied once for the process: the configuration can be set only once.
    private static let configured = Result { try Hokusai.configure(.init(maxConcurrentEvaluations: .fixed(1), maxQueuedEvaluations: 0)) }

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["HOKUSAI_OVERLOAD_TESTS"] == "1", "set HOKUSAI_OVERLOAD_TESTS=1 and run this suite alone")
        try Self.configured.get()
    }

    private func withServer(_ routes: (Application) -> Void, _ body: (Int) async throws -> Void) async throws {
        let app = try await Application.make(.testing)
        routes(app)
        try await app.server.start(address: .hostname("127.0.0.1", port: 0))
        let port = app.http.server.shared.localAddress?.port ?? 0
        XCTAssertNotEqual(port, 0)
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

    private func requestText(_ path: String) -> String { "GET \(path) HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n" }

    private func fetch(_ port: Int, _ path: String, limit: Int = .max) async throws -> [UInt8] {
        let channel = try await connect(port)
        var received: [UInt8] = []
        try await channel.executeThenClose { inbound, outbound in
            try await outbound.write(ByteBuffer(string: requestText(path)))
            for try await buffer in inbound {
                received += buffer.readableBytesView
                if received.count >= limit { break }
            }
        }
        return received
    }

    private func slotsFree(within seconds: Double = 15) async -> Bool {
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

    private func text(_ bytes: [UInt8], _ count: Int = 400) -> String { String(decoding: bytes.prefix(count), as: UTF8.self) }

    /// With one slot and no queue, a request that arrives while another is being served is refused
    /// with a 503, the busy one is not disturbed, and the server serves again once the slot is free.
    func testARequestWhileTheOnlySlotIsBusyGets503AndTheServerRecovers() async throws {
        let big = try Hokusai(data: gradientTIFF(width: 2000, height: 2000)).png(compressionLevel: 0)
        let small = try Hokusai(data: gradientTIFF(width: 200, height: 200)).png(compressionLevel: 0)
        let expectedSmall = try await small.data().data
        try await withServer({ app in
            app.get("big") { _ async throws -> Response in try await big.response(chunkSize: 4096) }
            app.get("small") { _ async throws -> Response in try await small.response(chunkSize: 4096) }
        }) { port in
            let first = try await connect(port)
            try await first.executeThenClose { inbound, outbound in
                try await outbound.write(ByteBuffer(string: requestText("/big")))
                var iterator = inbound.makeAsyncIterator()
                _ = try await iterator.next()
                try await Task.sleep(for: .milliseconds(300))
                XCTAssertEqual(Hokusai.runtimeStatus.activeEvaluations, 1, "the first request should hold the slot")

                let refused = try await fetch(port, "/small", limit: 100_000)
                let head = text(refused)
                XCTAssertTrue(head.hasPrefix("HTTP/1.1 503"), "expected 503, got: \(head.prefix(60))")
                XCTAssertEqual(Hokusai.runtimeStatus.queuedEvaluations, 0, "a refused request must not wait in the queue")
                XCTAssertEqual(Hokusai.runtimeStatus.activeEvaluations, 1, "the busy request was disturbed")
            }
            let freed = await slotsFree()
            XCTAssertTrue(freed, "the slot was not released after the first client left")

            let again = try await fetch(port, "/small")
            XCTAssertTrue(text(again, 20).hasPrefix("HTTP/1.1 200"))
            let (payload, complete) = decodeChunked(again)
            XCTAssertTrue(complete && payload == [UInt8](expectedSmall), "the server did not recover after the overload")
        }
    }

    /// A pipeline that fails once output has begun cannot change the status line it already sent;
    /// the body must end without the terminating chunk so the client can tell, and the slot is freed.
    func testAFailureAfterOutputBeganTruncatesTheBodyAndFreesTheSlot() async throws {
        let whole = try await Hokusai(data: gradientTIFF(width: 1500, height: 1500)).png(compressionLevel: 0).data().data
        let broken = try Hokusai(data: Data(whole.prefix(whole.count / 2)), options: InputOptions(access: .sequential, failOn: .truncated)).png(compressionLevel: 0)
        let healthy = try Hokusai(data: gradientTIFF(width: 100, height: 100)).png()
        let expectedHealthy = try await healthy.data().data
        try await withServer({ app in
            app.get("broken") { _ async throws -> Response in try await broken.response(chunkSize: 512) }
            app.get("healthy") { _ async throws -> Response in try await healthy.response() }
        }) { port in
            let received = try await fetch(port, "/broken")
            XCTAssertTrue(text(received, 20).hasPrefix("HTTP/1.1 200"), "output had begun, so the status was already 200")
            let (payload, complete) = decodeChunked(received)
            XCTAssertFalse(complete, "the body ended cleanly although the image failed part-way")
            XCTAssertFalse(payload.isEmpty, "this test expects the failure to come after output began")
            let freed = await slotsFree()
            XCTAssertTrue(freed, "the failed evaluation still holds its slot")

            let ok = try await fetch(port, "/healthy")
            let (body, finished) = decodeChunked(ok)
            XCTAssertTrue(finished && body == [UInt8](expectedHealthy), "the server did not serve after the failure")
        }
    }
}
