import Hokusai
import Vapor

extension Application {
    /// Hokusai's process-wide runtime, as seen from a Vapor application.
    public var hokusai: HokusaiConfiguration {
        .init(application: self)
    }

    public struct HokusaiConfiguration {
        let application: Application

        /// Freezes Hokusai's process-level runtime configuration.
        ///
        /// Call it once, during bootstrap, before the first image is
        /// evaluated. Without a configuration the defaults apply and the
        /// native runtime starts on first use. Hokusai owns ordinary process
        /// teardown, so there is no shutdown hook to register.
        ///
        /// ```swift
        /// try app.hokusai.configure(.init(maxConcurrentEvaluations: .fixed(4), maxQueuedEvaluations: 64))
        /// ```
        public func configure(_ configuration: RuntimeConfiguration? = nil) throws {
            if let configuration {
                try Hokusai.configure(configuration)
            } else {
                try Hokusai.initialize()
            }
        }

        /// The native formats and features this process can read and write.
        public func capabilities() throws -> RuntimeCapabilities {
            try Hokusai.capabilities()
        }

        /// Scheduler state: running and queued evaluations.
        public var runtimeStatus: RuntimeStatus {
            Hokusai.runtimeStatus
        }
    }
}
