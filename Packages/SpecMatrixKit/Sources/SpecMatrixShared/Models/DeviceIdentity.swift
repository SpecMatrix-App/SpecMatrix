import Foundation

/// A hardware model identifier such as `iPhone17,1`, `iPad16,4`, or `Mac14,2`.
///
/// The identifier is validated for format only. A valid identifier is not assumed to
/// correspond to a known product; product information comes from the catalog.
public struct HardwareIdentifier: Sendable, Hashable, Comparable, CustomStringConvertible {
    /// The normalized identifier, e.g. `iPhone17,1`.
    public let rawValue: String
    /// The alphabetic prefix, e.g. `iPhone`, `iPad`, `Mac`, `MacBookPro`.
    public let family: String
    public let major: Int
    public let minor: Int

    /// Parses `<letters><digits>,<digits>` after trimming whitespace and NUL padding.
    /// Returns `nil` for any other format (e.g. `arm64`, `x86_64`, or an empty string).
    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\0")))
        let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        let head = parts[0]
        let family = head.prefix { $0.isASCII && $0.isLetter }
        let majorDigits = head.dropFirst(family.count)
        let minorDigits = parts[1]

        func isDigits(_ text: Substring) -> Bool {
            !text.isEmpty && text.count <= 4 && text.allSatisfy { $0.isASCII && $0.isNumber }
        }
        guard !family.isEmpty, isDigits(majorDigits), isDigits(minorDigits),
              let major = Int(majorDigits), let minor = Int(minorDigits)
        else { return nil }

        self.rawValue = trimmed
        self.family = String(family)
        self.major = major
        self.minor = minor
    }

    public static func < (lhs: HardwareIdentifier, rhs: HardwareIdentifier) -> Bool {
        (lhs.family, lhs.major, lhs.minor) < (rhs.family, rhs.major, rhs.minor)
    }

    public var description: String { rawValue }
}

/// The identity of the running device.
public struct DeviceIdentity: Sendable, Hashable {
    public let identifier: HardwareIdentifier
    /// In the Simulator, `identifier` is the simulated model, not the host Mac.
    public let environment: RuntimeEnvironment

    public init(identifier: HardwareIdentifier, environment: RuntimeEnvironment) {
        self.identifier = identifier
        self.environment = environment
    }
}

/// An operating-system version such as 17.4.1.
public struct OSVersion: Sendable, Hashable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public static func < (lhs: OSVersion, rhs: OSVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    /// `17.4` when the patch is zero, otherwise `17.4.1`.
    public var description: String {
        patch == 0 ? "\(major).\(minor)" : "\(major).\(minor).\(patch)"
    }
}
