import Foundation
import SpecMatrixShared

/// Operating-system information, always measured from the running system.
public struct OperatingSystemInfo: Sendable, Equatable, SpecErrorReporting {
    /// e.g. `iOS`, `iPadOS`, `macOS`.
    public var name: SpecValue<String>
    public var version: SpecValue<OSVersion>
    /// e.g. `24A434`.
    public var build: SpecValue<String>

    public init(name: SpecValue<String>, version: SpecValue<OSVersion>, build: SpecValue<String>) {
        self.name = name
        self.version = version
        self.build = build
    }

    public var errors: [SpecError] {
        [name.specError, version.specError, build.specError].compactMap { $0 }
    }
}
