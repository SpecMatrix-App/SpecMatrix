import Foundation

/// Locale-aware formatting with explicit unit conventions.
public enum SpecFormat {
    /// Storage uses decimal units (1 GB = 10⁹ bytes), matching Apple's marketing and the Settings app.
    public static func storage(_ value: ByteCount, locale: Locale = .current) -> String {
        Int64(value.bytes).formatted(ByteCountFormatStyle(style: .file, allowedUnits: .all, spellsOutZero: false,
                                                          includesActualByteCount: false, locale: locale))
    }

    /// Memory uses binary units (1 GB = 2³⁰ bytes), as reported by the operating system.
    public static func memory(_ value: ByteCount, locale: Locale = .current) -> String {
        Int64(value.bytes).formatted(ByteCountFormatStyle(style: .memory, allowedUnits: .all, spellsOutZero: false,
                                                          includesActualByteCount: false, locale: locale))
    }

    /// A whole-number percentage, e.g. "37%".
    public static func percent(_ value: UnitFraction, locale: Locale = .current) -> String {
        value.value.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// The hardware identifier as reported, plus " (Simulator)" when applicable.
    public static func identity(_ identity: DeviceIdentity) -> String {
        identity.environment == .simulator ? "\(identity.identifier) (Simulator)" : identity.identifier.rawValue
    }
}
