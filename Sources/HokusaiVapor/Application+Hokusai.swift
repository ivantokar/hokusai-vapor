import Vapor
import Hokusai

extension Application {
    /// PURPOSE: Expose Hokusai integration entrypoint on Vapor `Application`.
    /// OUTPUT: Config object that wires safe one-time initialization.
    public var hokusai: HokusaiConfiguration {
        .init(application: self)
    }

    public struct HokusaiConfiguration {
        let application: Application

        /// PURPOSE: Register Hokusai runtime with Vapor app lifecycle.
        /// SIDE EFFECTS:
        /// - Initializes libvips runtime.
        /// DO: Call once during application bootstrap.
        public func configure() throws {
            try Hokusai.initialize()
        }

        /// PURPOSE: Return current Hokusai runtime version string.
        public var version: String {
            Hokusai.version
        }

        /// PURPOSE: Return current libvips runtime version string.
        public var vipsVersion: String {
            Hokusai.vipsVersion
        }

        /// PURPOSE: Legacy ImageMagick version shim kept for API compatibility.
        @available(*, deprecated, message: "ImageMagick backend was removed. Use vipsVersion instead.")
        public var magickVersion: String {
            Hokusai.magickVersion
        }

    }
}
