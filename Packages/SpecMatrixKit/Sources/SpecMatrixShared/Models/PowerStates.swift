import Foundation

public enum BatteryChargeState: String, Sendable, Hashable, CaseIterable {
    /// Running on battery power.
    case unplugged
    case charging
    /// Connected to power and fully charged.
    case full
    /// Connected to power but not charging (e.g. a Mac holding its charge level).
    case notCharging
}

public enum ThermalLevel: String, Sendable, Hashable, CaseIterable {
    case nominal, fair, serious, critical

    public init?(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: return nil
        }
    }
}
