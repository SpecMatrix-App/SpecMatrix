import Foundation

/// A non-negative number of bytes.
public struct ByteCount: Sendable, Hashable, Comparable, CustomStringConvertible {
    public let bytes: Int64

    /// Returns `nil` for negative values or values that do not fit in `Int64`.
    public init?<T: BinaryInteger>(exactly value: T) {
        guard let bytes = Int64(exactly: value), bytes >= 0 else { return nil }
        self.bytes = bytes
    }

    public static func < (lhs: ByteCount, rhs: ByteCount) -> Bool { lhs.bytes < rhs.bytes }

    public var description: String { "\(bytes) bytes" }
}

/// A finite fraction in `0...1`, used for percentages such as battery level or storage use.
public struct UnitFraction: Sendable, Hashable, Comparable, CustomStringConvertible {
    public let value: Double

    /// Returns `nil` for NaN, infinity, or values outside `0...1`.
    public init?(_ value: Double) {
        guard value.isFinite, (0...1).contains(value) else { return nil }
        self.value = value
    }

    /// The fraction expressed as a percentage in `0...100`.
    public var percent: Double { value * 100 }

    public static func < (lhs: UnitFraction, rhs: UnitFraction) -> Bool { lhs.value < rhs.value }

    public var description: String { "\(percent)%" }
}

/// A positive refresh or frame rate in hertz.
public struct RefreshRate: Sendable, Hashable, Comparable, CustomStringConvertible {
    public let hertz: Int

    public init?(hertz: Int) {
        guard hertz > 0 else { return nil }
        self.hertz = hertz
    }

    public static func < (lhs: RefreshRate, rhs: RefreshRate) -> Bool { lhs.hertz < rhs.hertz }

    public var description: String { "\(hertz) Hz" }
}

/// A positive display diagonal in inches, as marketed by the manufacturer.
public struct DisplayDiagonal: Sendable, Hashable, CustomStringConvertible {
    public let inches: Double

    public init?(inches: Double) {
        guard inches.isFinite, inches > 0 else { return nil }
        self.inches = inches
    }

    public var description: String { "\(inches) in" }
}

/// A positive pixel density in pixels per inch.
public struct PixelDensity: Sendable, Hashable, CustomStringConvertible {
    public let pixelsPerInch: Int

    public init?(pixelsPerInch: Int) {
        guard pixelsPerInch > 0 else { return nil }
        self.pixelsPerInch = pixelsPerInch
    }

    public var description: String { "\(pixelsPerInch) ppi" }
}

/// Positive pixel dimensions. Device displays are described in portrait orientation.
public struct PixelDimensions: Sendable, Hashable, CustomStringConvertible {
    public let width: Int
    public let height: Int

    public init?(width: Int, height: Int) {
        guard width > 0, height > 0 else { return nil }
        self.width = width
        self.height = height
    }

    public var description: String { "\(width) × \(height)" }
}

/// A calendar day without a time zone, parsed from `YYYY-MM-DD`.
public struct CalendarDate: Sendable, Hashable, Comparable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init?(iso8601 string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        // Rejects impossible days such as 2026-02-30.
        guard Calendar(identifier: .gregorian).date(from: components).map({
            Calendar(identifier: .gregorian).component(.day, from: $0) == day
        }) == true else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
