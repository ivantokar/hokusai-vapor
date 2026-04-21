import Vapor
import Hokusai

extension Application {
    /// PURPOSE: Expose Hokusai integration entrypoint on Vapor `Application`.
    /// OUTPUT: Config object that wires lifecycle-safe initialization/shutdown.
    public var hokusai: HokusaiConfiguration {
        .init(application: self)
    }

    public struct HokusaiConfiguration {
        let application: Application

        /// PURPOSE: Register Hokusai runtime with Vapor app lifecycle.
        /// SIDE EFFECTS:
        /// - Initializes libvips runtime.
        /// - Registers shutdown hook.
        /// DO: Call once during application bootstrap.
        public func configure() throws {
            try Hokusai.initialize()
            application.lifecycle.use(HokusaiLifecycleHandler())
        }

        /// PURPOSE: Return current Hokusai runtime version string.
        public var version: String {
            Hokusai.version
        }

        /// PURPOSE: Return current libvips runtime version string.
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

/// PURPOSE: Lifecycle hook that guarantees Hokusai runtime teardown.
struct HokusaiLifecycleHandler: LifecycleHandler {
    func shutdown(_ application: Application) {
        Hokusai.shutdown()
    }
}
