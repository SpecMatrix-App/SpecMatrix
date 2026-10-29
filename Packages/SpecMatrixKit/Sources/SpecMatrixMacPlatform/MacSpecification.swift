import Foundation
import SpecMatrixMacCatalog
import SpecMatrixShared

/// How this Mac relates to the chip configurations the catalog publishes for its model.
public enum MacConfigurationMatch: Sendable, Equatable {
    /// No catalog entry applies (uncatalogued model, unknown identifier, or the catalog failed to load).
    case unresolved(String)
    /// The entry records no chip configurations.
    case notRecorded
    /// What macOS reports matches none of the published configurations.
    case noMatch(String)
    /// The configurations consistent with what macOS reports (never empty). One means the configuration
    /// is identified; several mean macOS does not report what distinguishes them (usually GPU cores).
    case matched([MacChipConfiguration])

    public var candidates: [MacChipConfiguration] {
        if case .matched(let configurations) = self { return configurations }
        return []
    }
}

/// Specifications that macOS does not expose, taken from the Mac catalog for this exact model.
///
/// Every value is `.catalog` (with its citation), `.unknown` (with the reason), or `.error` (the catalog
/// failed to load). Configuration-specific values are shown only when every published configuration
/// consistent with what macOS reports agrees on them, so a value from a different configuration is
/// never shown.
public struct MacSpecification: Sendable, Equatable {
    public var marketingName: SpecValue<String>
    public var catalogChipName: SpecValue<String>
    public var gpuCores: SpecValue<Int>
    public var neuralEngineCores: SpecValue<Int>
    public var builtInDisplayDiagonal: SpecValue<DisplayDiagonal>
    public var builtInDisplayResolution: SpecValue<PixelDimensions>
    public var builtInDisplayPixelDensity: SpecValue<PixelDensity>
    public var builtInDisplayMaximumRefreshRate: SpecValue<RefreshRate>
    public var configurationMatch: MacConfigurationMatch
    /// The catalog entry used, if any, and the catalog's version.
    public var entry: MacCatalogEntry?
    public var catalogVersion: String?

    public var entryID: String? { entry?.id }

    public init(allMissing reason: MissingValue) {
        marketingName = SpecValue(reason)
        catalogChipName = SpecValue(reason)
        gpuCores = SpecValue(reason)
        neuralEngineCores = SpecValue(reason)
        builtInDisplayDiagonal = SpecValue(reason)
        builtInDisplayResolution = SpecValue(reason)
        builtInDisplayPixelDensity = SpecValue(reason)
        builtInDisplayMaximumRefreshRate = SpecValue(reason)
        switch reason {
        case .unavailable(let why): configurationMatch = .unresolved(why.explanation)
        case .unknown(let why): configurationMatch = .unresolved(why)
        case .error(let error): configurationMatch = .unresolved(error.description)
        }
        entry = nil
        catalogVersion = nil
    }
}

public enum MacSpecificationResolver {
    /// - Parameters:
    ///   - identifier: The measured model identifier (`hw.model`).
    ///   - detectedChipName: The chip name macOS reports (`machdep.cpu.brand_string`, e.g. "Apple M2").
    ///   - detectedCoreClusters: The CPU clusters macOS reports (`hw.perflevelN`), highest performance first.
    public static func resolve(identifier: SpecValue<HardwareIdentifier>,
                               detectedChipName: SpecValue<String>,
                               detectedCoreClusters: SpecValue<[MacCoreCluster]> = .unknown("Not provided."),
                               catalog: Result<MacCatalog, CatalogLoadError>) -> MacSpecification {
        let loaded: MacCatalog
        switch catalog {
        case .success(let value): loaded = value
        case .failure(let error):
            return MacSpecification(allMissing: .error(SpecError(operation: "Load Mac catalog", message: error.description)))
        }
        guard let model = identifier.value else {
            return MacSpecification(allMissing: .unknown("The model identifier could not be determined."))
        }
        guard let entry = loaded.entry(for: model) else {
            return MacSpecification(allMissing: .unknown(
                "\(model) is not in the SpecMatrix Mac catalog (version \(loaded.catalogVersion))."))
        }

        func cited<T: Sendable & Equatable>(_ value: T?, _ field: CatalogField, missing: String) -> SpecValue<T> {
            guard let value else { return .unknown(missing) }
            return .catalog(value, loaded.reference(for: entry, field: field))
        }

        var spec = MacSpecification(allMissing: .unknown(""))
        spec.entry = entry
        spec.catalogVersion = loaded.catalogVersion
        spec.marketingName = .catalog(entry.marketingName, loaded.reference(for: entry, field: .marketingName))

        spec.configurationMatch = match(entry: entry, chip: detectedChipName.value,
                                        clusters: detectedCoreClusters.value)
        let chipReference = loaded.reference(for: entry, field: .chip)
        switch spec.configurationMatch {
        case .matched(let candidates):
            spec.catalogChipName = agreed(candidates, \.chip, reference: chipReference,
                                          differ: { "Apple sells \(entry.marketingName) with \(list($0)); macOS reports \(detectedChipName.value ?? "no chip name")." })
            spec.gpuCores = agreed(candidates, \.gpuCores, reference: chipReference,
                                   differ: { "Apple sells this configuration of \(entry.marketingName) with a \(list($0.map { "\($0)-core" })) GPU. macOS does not report which one this Mac has." },
                                   missing: "Apple does not publish the GPU core count for every matching configuration.")
            spec.neuralEngineCores = agreed(candidates, \.neuralEngineCores, reference: chipReference,
                                            differ: { "Matching configurations have a \(list($0.map { "\($0)-core" })) Neural Engine." },
                                            missing: "Apple does not publish a single Neural Engine core count for this configuration.")
        case .notRecorded:
            let reason = "The catalog records no chip configurations for \(entry.marketingName)."
            spec.catalogChipName = .unknown(reason)
            spec.gpuCores = .unknown(reason)
            spec.neuralEngineCores = .unknown(reason)
        case .noMatch(let reason), .unresolved(let reason):
            spec.catalogChipName = .unknown(reason)
            spec.gpuCores = .unknown(reason)
            spec.neuralEngineCores = .unknown(reason)
        }

        let noDisplay = "\(entry.marketingName) has no built-in display recorded in the catalog."
        spec.builtInDisplayDiagonal = cited(entry.display?.diagonal, .display, missing: noDisplay)
        spec.builtInDisplayResolution = cited(entry.display?.resolution, .display, missing: noDisplay)
        spec.builtInDisplayPixelDensity = cited(entry.display?.pixelDensity, .display, missing: noDisplay)
        spec.builtInDisplayMaximumRefreshRate = cited(entry.display?.maximumRefreshRate, .display,
                                                      missing: entry.display == nil ? noDisplay
                                                          : "Apple does not state a refresh rate for this display.")
        return spec
    }

    /// Narrows the entry's configurations to those consistent with the detected chip name and CPU clusters.
    /// A configuration that does not record a value is not excluded on that value.
    public static func match(entry: MacCatalogEntry, chip: String?, clusters: [MacCoreCluster]?) -> MacConfigurationMatch {
        guard !entry.configurations.isEmpty else { return .notRecorded }
        var candidates = entry.configurations
        if let chip {
            candidates = candidates.filter { chipNamesMatch(detected: chip, catalog: $0.chip) }
            if candidates.isEmpty {
                let published = Set(entry.configurations.map(\.chip)).sorted()
                return .noMatch("This Mac reports \(chip), but Apple lists \(list(published)) for \(entry.marketingName), "
                                + "so configuration-specific values are not shown.")
            }
        }
        if let clusters, !clusters.isEmpty {
            let counts = clusters.map(\.cores)
            let total = counts.reduce(0, +)
            let narrowed = candidates.filter { configuration in
                (configuration.cpuCores.map { $0 == total } ?? true)
                    && (configuration.cpuClusters.map { $0.map(\.cores) == counts } ?? true)
            }
            if narrowed.isEmpty {
                let split = counts.map(String.init).joined(separator: " + ")
                return .noMatch("This Mac reports a \(total)-core CPU (\(split)), which matches none of the configurations "
                                + "Apple publishes for \(entry.marketingName).")
            }
            candidates = narrowed
        }
        return .matched(candidates)
    }

    /// "Apple M2 Pro" (macOS) matches "M2 Pro" (catalog). Comparison is exact apart from the prefix.
    public static func chipNamesMatch(detected: String, catalog: String) -> Bool {
        let trimmed = detected.trimmingCharacters(in: .whitespaces)
        let withoutPrefix = trimmed.hasPrefix("Apple ") ? String(trimmed.dropFirst("Apple ".count)) : trimmed
        return withoutPrefix == catalog
    }

    /// A catalog value when every candidate records the same value; otherwise unknown with the reason.
    private static func agreed<T: Sendable & Hashable & Comparable>(
        _ candidates: [MacChipConfiguration], _ field: KeyPath<MacChipConfiguration, T?>, reference: CatalogReference,
        differ: ([T]) -> String, missing: String
    ) -> SpecValue<T> {
        let values = candidates.map { $0[keyPath: field] }
        let known = Set(values.compactMap { $0 })
        guard values.allSatisfy({ $0 != nil }) else { return .unknown(missing) }
        if known.count == 1, let value = known.first { return .catalog(value, reference) }
        return .unknown(differ(known.sorted()))
    }

    private static func agreed(_ candidates: [MacChipConfiguration], _ field: KeyPath<MacChipConfiguration, String>,
                               reference: CatalogReference, differ: ([String]) -> String) -> SpecValue<String> {
        let names = Set(candidates.map { $0[keyPath: field] })
        if names.count == 1, let name = names.first { return .catalog(name, reference) }
        return .unknown(differ(names.sorted()))
    }

    /// "8 or 10", "M4 Pro, M4 Max or M4 Ultra".
    static func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " or " + items[items.count - 1]
    }

    private static func list(_ items: [Int]) -> String { list(items.map(String.init)) }
}
