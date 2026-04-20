import Vapor
import Hokusai

extension Application {
    /// Hokusai configuration and lifecycle management
    public var hokusai: HokusaiConfiguration {
        .init(application: self)
    }

    public struct HokusaiConfiguration {
        let application: Application

        /// Configure Hokusai for this Vapor application
        /// Call this in your configure.swift
        public func configure() throws {
            try Hokusai.initialize()
            application.lifecycle.use(HokusaiLifecycleHandler())
        }

        /// Get Hokusai version
        public var version: String {
            Hokusai.version
        }

        /// Get libvips version
        public var vipsVersion: String {
            Hokusai.vipsVersion
        }

        /// Legacy ImageMagick version shim kept for API compatibility.
        @available(*, deprecated, message: "ImageMagick backend was removed. Use vipsVersion instead.")
        public var magickVersion: String {
            Hokusai.magickVersion
        }

    }
}

/// Lifecycle handler to properly shutdown Hokusai backend
struct HokusaiLifecycleHandler: LifecycleHandler {
    func shutdown(_ application: Application) {
        Hokusai.shutdown()
    }
}
