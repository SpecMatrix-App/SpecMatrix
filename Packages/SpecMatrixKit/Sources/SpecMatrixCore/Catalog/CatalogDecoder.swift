import Foundation

/// Decodes and validates catalog JSON (schema version 2).
///
/// Validation rules:
/// 1. The data must be a JSON object with an integer `schemaVersion` equal to 2.
///    Other versions are rejected before any further parsing.
/// 2. Keys not defined by the schema are rejected, so typos cannot silently drop data.
/// 3. Values must have the declared JSON types (e.g. integers for core counts).
/// 4. Required fields: `catalogVersion` (`YYYY.MM.N`), and per entry `id`, `identifiers`, `family`,
///    `marketingName`, `sources`, `verification`. All other fields are optional; an absent field
///    means "not recorded", never zero.
/// 5. Field values: numbers positive; dates valid `YYYY-MM-DD`; entry IDs unique lowercase slugs;
///    identifiers well-formed, unique across the catalog, and matching the entry's family;
///    marketing names unique; resolution in portrait.
/// 6. Sources: each has a title, an `accessed` date, a non-empty `supports` list, and exactly one
///    location — an HTTPS `url`, or an `xcodeSimulatorDeviceType` with its `xcodeVersion`
///    (which may only support `identifiers`). Sources are unique within an entry.
/// 7. Attribution: every populated field group is supported by at least one source, and no
///    source claims a group the entry does not populate.
/// 8. Consistency: `accessed` dates and `releaseDate` are not after `verifiedOn`; pixel density
///    agrees with resolution and diagonal (see `pixelDensityTolerance`); entries naming the
///    same chip agree on its Neural Engine core count.
/// 9. `verified` entries satisfy `CatalogPolicy`: each populated specification group has a
///    manufacturer-published source, and identifiers are supported by enough independent publishers.
/// All issues are collected; any issue rejects the whole catalog.
enum CatalogDecoder {
    /// Allowed relative difference between the published pixel density and the density computed
    /// from resolution and diagonal. Published diagonals are rounded to 0.01–0.1 in and densities
    /// to whole pixels, which accounts for up to about 0.6 % on the smallest screens; 1 % allows
    /// for that rounding while still catching a wrong resolution, diagonal, or density.
    static let pixelDensityTolerance = 0.01

    static func decode(_ data: Data, policy: CatalogPolicy) -> Result<DeviceCatalog, CatalogLoadError> {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            return .failure(.malformedJSON("The data is not valid JSON."))
        }
        guard let root = json as? [String: Any] else {
            return .failure(.malformedJSON("The top level must be a JSON object."))
        }
        let version = (root["schemaVersion"] as? NSNumber).flatMap { Int(exactly: $0.doubleValue) }
        guard version == DeviceCatalog.supportedSchemaVersion else {
            return .failure(.unsupportedSchemaVersion(found: version, supported: DeviceCatalog.supportedSchemaVersion))
        }

        var issues = UnknownKeyCheck.issues(in: root)

        let raw: RawCatalog
        do {
            raw = try JSONDecoder().decode(RawCatalog.self, from: data)
        } catch let error as DecodingError {
            return .failure(.malformedJSON(describe(error)))
        } catch {
            return .failure(.malformedJSON(error.localizedDescription))
        }

        var validator = Validator(policy: policy)
        let catalog = validator.validate(raw)
        issues += validator.issues
        guard issues.isEmpty, let catalog else {
            return .failure(.invalid(issues))
        }
        return .success(catalog)
    }

    private static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }.joined()
        }
        switch error {
        case .typeMismatch(_, let context), .valueNotFound(_, let context),
             .keyNotFound(_, let context), .dataCorrupted(let context):
            return "\(path(context)): \(context.debugDescription)"
        @unknown default:
            return String(describing: error)
        }
    }
}

// MARK: - Raw schema (every field optional so validation can report all problems)

struct RawCatalog: Decodable {
    let schemaVersion: Int?
    let catalogVersion: String?
    let entries: [RawEntry]?
}

struct RawEntry: Decodable {
    let id: String?
    let identifiers: [String]?
    let family: String?
    let marketingName: String?
    let releaseDate: String?
    let chip: RawChip?
    let display: RawDisplay?
    let sources: [RawSource]?
    let verification: RawVerification?
}

struct RawChip: Decodable {
    let name: String?
    let performanceCores: Int?
    let efficiencyCores: Int?
    let gpuCores: Int?
    let neuralEngineCores: Int?
}

struct RawDisplay: Decodable {
    let diagonalInches: Double?
    let pixelWidth: Int?
    let pixelHeight: Int?
    let pixelsPerInch: Int?
    let maximumRefreshRateHz: Int?
}

struct RawSource: Decodable {
    let title: String?
    let url: String?
    let xcodeSimulatorDeviceType: String?
    let xcodeVersion: String?
    let accessed: String?
    let supports: [String]?
}

struct RawVerification: Decodable {
    let status: String?
    let verifiedOn: String?
}

// MARK: - Unknown keys

private enum UnknownKeyCheck {
    static let rootKeys: Set<String> = ["schemaVersion", "catalogVersion", "entries"]
    static let entryKeys: Set<String> = ["id", "identifiers", "family", "marketingName", "releaseDate",
                                         "chip", "display", "sources", "verification"]
    static let chipKeys: Set<String> = ["name", "performanceCores", "efficiencyCores", "gpuCores", "neuralEngineCores"]
    static let displayKeys: Set<String> = ["diagonalInches", "pixelWidth", "pixelHeight", "pixelsPerInch", "maximumRefreshRateHz"]
    static let sourceKeys: Set<String> = ["title", "url", "xcodeSimulatorDeviceType", "xcodeVersion", "accessed", "supports"]
    static let verificationKeys: Set<String> = ["status", "verifiedOn"]

    static func issues(in root: [String: Any]) -> [CatalogIssue] {
        var issues = unexpected(in: root, allowed: rootKeys, path: "")
        for (index, value) in (root["entries"] as? [Any] ?? []).enumerated() {
            guard let entry = value as? [String: Any] else { continue }
            let path = "entries[\(index)]"
            issues += unexpected(in: entry, allowed: entryKeys, path: path)
            if let chip = entry["chip"] as? [String: Any] {
                issues += unexpected(in: chip, allowed: chipKeys, path: path + ".chip")
            }
            if let display = entry["display"] as? [String: Any] {
                issues += unexpected(in: display, allowed: displayKeys, path: path + ".display")
            }
            if let verification = entry["verification"] as? [String: Any] {
                issues += unexpected(in: verification, allowed: verificationKeys, path: path + ".verification")
            }
            for (sourceIndex, source) in (entry["sources"] as? [Any] ?? []).enumerated() {
                guard let source = source as? [String: Any] else { continue }
                issues += unexpected(in: source, allowed: sourceKeys, path: path + ".sources[\(sourceIndex)]")
            }
        }
        return issues
    }

    private static func unexpected(in object: [String: Any], allowed: Set<String>, path: String) -> [CatalogIssue] {
        object.keys.filter { !allowed.contains($0) }.sorted().map {
            CatalogIssue(path: path.isEmpty ? $0 : "\(path).\($0)", message: "Unknown field.")
        }
    }
}

// MARK: - Field validation

private struct Validator {
    let policy: CatalogPolicy
    var issues: [CatalogIssue] = []
    private var seenEntryIDs: Set<String> = []
    private var seenIdentifiers: [HardwareIdentifier: String] = [:]
    private var seenMarketingNames: [String: String] = [:]

    /// Identifier prefixes allowed for each family. A family not listed must equal its prefix.
    private static let identifierPrefixes: [String: Set<String>] = [
        "Mac": ["Mac", "MacBookAir", "MacBookPro", "Macmini", "iMac", "MacPro"],
    ]

    init(policy: CatalogPolicy) {
        self.policy = policy
    }

    mutating func validate(_ raw: RawCatalog) -> DeviceCatalog? {
        let catalogVersion = nonEmpty(raw.catalogVersion, path: "catalogVersion")
        if let catalogVersion, !Self.isCatalogVersion(catalogVersion) {
            issue("catalogVersion", "\"\(catalogVersion)\" is not of the form YYYY.MM.N.")
        }
        guard let rawEntries = raw.entries else {
            issue("entries", "Required field is missing.")
            return nil
        }
        var entries: [CatalogEntry] = []
        var entryPaths: [String] = []
        for (index, rawEntry) in rawEntries.enumerated() {
            if let entry = validate(rawEntry, path: "entries[\(index)]") {
                entries.append(entry)
                entryPaths.append("entries[\(index)]")
            }
        }
        checkChipConsistency(entries, paths: entryPaths)
        guard let catalogVersion, issues.isEmpty else { return nil }
        return DeviceCatalog(schemaVersion: DeviceCatalog.supportedSchemaVersion, catalogVersion: catalogVersion, entries: entries)
    }

    private mutating func validate(_ raw: RawEntry, path: String) -> CatalogEntry? {
        let startCount = issues.count

        let id = nonEmpty(raw.id, path: path + ".id")
        if let id {
            if !Self.isSlug(id) { issue(path + ".id", "Must be a lowercase slug such as \"iphone-16-pro\".") }
            if !seenEntryIDs.insert(id).inserted { issue(path + ".id", "Duplicate entry ID \"\(id)\".") }
        }

        let family = nonEmpty(raw.family, path: path + ".family")

        var identifiers: [HardwareIdentifier] = []
        if let rawIdentifiers = raw.identifiers, !rawIdentifiers.isEmpty {
            for (index, text) in rawIdentifiers.enumerated() {
                let identifierPath = "\(path).identifiers[\(index)]"
                guard let identifier = HardwareIdentifier(text), identifier.rawValue == text else {
                    issue(identifierPath, "\"\(text)\" is not a valid hardware identifier.")
                    continue
                }
                if let owner = seenIdentifiers[identifier] {
                    issue(identifierPath, "\(text) is already assigned to entry \"\(owner)\".")
                } else {
                    seenIdentifiers[identifier] = id ?? path
                }
                if let family, !(Self.identifierPrefixes[family] ?? [family]).contains(identifier.family) {
                    issue(identifierPath, "\(text) does not belong to the \(family) family.")
                }
                identifiers.append(identifier)
            }
        } else {
            issue(path + ".identifiers", "At least one hardware identifier is required.")
        }

        let marketingName = nonEmpty(raw.marketingName, path: path + ".marketingName")
        if let marketingName {
            if let owner = seenMarketingNames[marketingName] {
                issue(path + ".marketingName", "\"\(marketingName)\" is already used by entry \"\(owner)\".")
            } else {
                seenMarketingNames[marketingName] = id ?? path
            }
        }
        let releaseDate = raw.releaseDate.flatMap { date(from: $0, path: path + ".releaseDate") }
        let chip = raw.chip.flatMap { validate($0, path: path + ".chip") }
        let display = raw.display.map { validate($0, path: path + ".display") }
        let sources = validate(raw.sources, path: path + ".sources")
        let verification = validate(raw.verification, path: path + ".verification")

        // Presence is judged from the raw data so that an invalid section does not also
        // produce a misleading attribution issue.
        var populated: Set<CatalogField> = [.identifiers, .marketingName]
        if raw.releaseDate != nil { populated.insert(.releaseDate) }
        if raw.chip != nil { populated.insert(.chip) }
        if raw.display != nil { populated.insert(.display) }
        checkAttribution(sources, populated: populated, path: path)

        if let verification {
            for (index, source) in sources where source.accessed > verification.verifiedOn {
                issue("\(path).sources[\(index)].accessed", "Accessed \(source.accessed), after verifiedOn \(verification.verifiedOn).")
            }
            if let releaseDate, releaseDate > verification.verifiedOn {
                issue(path + ".releaseDate", "Release date \(releaseDate) is after verifiedOn \(verification.verifiedOn).")
            }
            if verification.status == .verified {
                checkVerifiedPolicy(sources.map(\.source), populated: populated, path: path)
            }
        }

        guard issues.count == startCount,
              let id, let family, let marketingName, let verification
        else { return nil }
        return CatalogEntry(id: id, identifiers: identifiers, family: family, marketingName: marketingName,
                            releaseDate: releaseDate, chip: chip, display: display,
                            sources: sources.map(\.source), verification: verification)
    }

    private mutating func validate(_ raw: RawChip, path: String) -> ChipSpecification? {
        let name = nonEmpty(raw.name, path: path + ".name")
        let counts = [
            ("performanceCores", raw.performanceCores), ("efficiencyCores", raw.efficiencyCores),
            ("gpuCores", raw.gpuCores), ("neuralEngineCores", raw.neuralEngineCores),
        ]
        for (key, value) in counts {
            if let value, value <= 0 { issue("\(path).\(key)", "Must be a positive integer (found \(value)).") }
        }
        guard let name else { return nil }
        return ChipSpecification(name: name, performanceCores: raw.performanceCores, efficiencyCores: raw.efficiencyCores,
                                 gpuCores: raw.gpuCores, neuralEngineCores: raw.neuralEngineCores)
    }

    private mutating func validate(_ raw: RawDisplay, path: String) -> DisplaySpecification {
        var diagonal: DisplayDiagonal?
        if let inches = raw.diagonalInches {
            diagonal = DisplayDiagonal(inches: inches)
            if diagonal == nil { issue(path + ".diagonalInches", "Must be a positive number (found \(inches)).") }
        }
        var resolution: PixelDimensions?
        switch (raw.pixelWidth, raw.pixelHeight) {
        case (nil, nil):
            break
        case (let width?, let height?):
            resolution = PixelDimensions(width: width, height: height)
            if resolution == nil { issue(path, "pixelWidth and pixelHeight must be positive (found \(width) × \(height)).") }
            if width > height { issue(path, "Resolution must be in portrait orientation (width ≤ height).") }
        default:
            issue(path, "pixelWidth and pixelHeight must be provided together.")
        }
        var density: PixelDensity?
        if let ppi = raw.pixelsPerInch {
            density = PixelDensity(pixelsPerInch: ppi)
            if density == nil { issue(path + ".pixelsPerInch", "Must be a positive integer (found \(ppi)).") }
        }
        var refresh: RefreshRate?
        if let hertz = raw.maximumRefreshRateHz {
            refresh = RefreshRate(hertz: hertz)
            if refresh == nil { issue(path + ".maximumRefreshRateHz", "Must be a positive integer (found \(hertz)).") }
        }
        if let diagonal, let resolution, resolution.width <= resolution.height, let density {
            let computed = (Double(resolution.width) * Double(resolution.width)
                            + Double(resolution.height) * Double(resolution.height)).squareRoot() / diagonal.inches
            let difference = abs(computed - Double(density.pixelsPerInch)) / Double(density.pixelsPerInch)
            if difference > CatalogDecoder.pixelDensityTolerance {
                issue(path + ".pixelsPerInch", String(
                    format: "%d ppi disagrees with %d × %d at %.2f in, which gives %.1f ppi.",
                    density.pixelsPerInch, resolution.width, resolution.height, diagonal.inches, computed))
            }
        }
        return DisplaySpecification(diagonal: diagonal, resolution: resolution, pixelDensity: density, maximumRefreshRate: refresh)
    }

    /// Valid sources, each paired with its index in the raw array so later issues point at it.
    private mutating func validate(_ raw: [RawSource]?, path: String) -> [(index: Int, source: CatalogSource)] {
        guard let raw, !raw.isEmpty else {
            issue(path, "At least one source is required.")
            return []
        }
        var sources: [(index: Int, source: CatalogSource)] = []
        var seenLocations: Set<CatalogSourceLocation> = []
        for (index, source) in raw.enumerated() {
            let sourcePath = "\(path)[\(index)]"
            let title = nonEmpty(source.title, path: sourcePath + ".title")
            let location = validateLocation(source, path: sourcePath)
            if let location, !seenLocations.insert(location).inserted {
                issue(sourcePath, "Duplicate source within the entry.")
            }
            let accessed = nonEmpty(source.accessed, path: sourcePath + ".accessed").flatMap {
                date(from: $0, path: sourcePath + ".accessed")
            }
            var supports: Set<CatalogField> = []
            if let rawSupports = source.supports, !rawSupports.isEmpty {
                for text in rawSupports {
                    guard let field = CatalogField(rawValue: text) else {
                        let allowed = CatalogField.allCases.map(\.rawValue).joined(separator: ", ")
                        issue(sourcePath + ".supports", "\"\(text)\" is not one of: \(allowed).")
                        continue
                    }
                    if !supports.insert(field).inserted { issue(sourcePath + ".supports", "\"\(text)\" is listed twice.") }
                }
            } else {
                issue(sourcePath + ".supports", "At least one supported field is required.")
            }
            if case .xcodeSimulatorDeviceType = location, supports.contains(where: { $0 != .identifiers }) {
                issue(sourcePath + ".supports", "An Xcode Simulator device type can only support identifiers.")
            }
            if let title, let location, let accessed, !supports.isEmpty {
                sources.append((index, CatalogSource(title: title, location: location, accessed: accessed, supports: supports)))
            }
        }
        return sources
    }

    private mutating func validateLocation(_ source: RawSource, path: String) -> CatalogSourceLocation? {
        switch (source.url, source.xcodeSimulatorDeviceType) {
        case (let text?, nil):
            if source.xcodeVersion != nil { issue(path + ".xcodeVersion", "Only allowed with xcodeSimulatorDeviceType.") }
            guard let text = nonEmpty(text, path: path + ".url") else { return nil }
            guard let url = URL(string: text), url.scheme == "https", url.host?.isEmpty == false else {
                issue(path + ".url", "Must be an absolute HTTPS URL.")
                return nil
            }
            return .web(url)
        case (nil, let name?):
            let name = nonEmpty(name, path: path + ".xcodeSimulatorDeviceType")
            let version = nonEmpty(source.xcodeVersion, path: path + ".xcodeVersion")
            guard let name, let version else { return nil }
            return .xcodeSimulatorDeviceType(name: name, xcodeVersion: version)
        case (nil, nil):
            issue(path, "A source needs a url or an xcodeSimulatorDeviceType.")
            return nil
        case (.some, .some):
            issue(path, "A source has either a url or an xcodeSimulatorDeviceType, not both.")
            return nil
        }
    }

    private mutating func checkAttribution(_ sources: [(index: Int, source: CatalogSource)],
                                           populated: Set<CatalogField>, path: String) {
        guard !sources.isEmpty else { return } // Already reported as missing or invalid sources.
        for field in populated.sorted() where !sources.contains(where: { $0.source.supports.contains(field) }) {
            issue(path + ".sources", "No source supports \(field.rawValue).")
        }
        for (index, source) in sources {
            for field in source.supports.subtracting(populated).sorted() {
                issue("\(path).sources[\(index)].supports", "Claims \(field.rawValue), which the entry does not record.")
            }
        }
    }

    private mutating func checkVerifiedPolicy(_ sources: [CatalogSource], populated: Set<CatalogField>, path: String) {
        guard !sources.isEmpty else { return } // Already reported as missing or invalid sources.
        let statusPath = path + ".verification.status"
        for field in populated.subtracting([.identifiers]).sorted() {
            let published = sources.contains { $0.supports.contains(field) && $0.publisher == policy.manufacturerPublisher }
            if !published {
                issue(statusPath, "verified requires a \(policy.manufacturerPublisher) source for \(field.rawValue).")
            }
        }
        let publishers = Set(sources.filter { $0.supports.contains(.identifiers) }.map(\.publisher))
        if publishers.count < policy.minimumIdentifierPublishers {
            issue(statusPath, "verified requires identifiers supported by \(policy.minimumIdentifierPublishers) independent publishers (found \(publishers.count)).")
        }
    }

    /// The same chip can be binned with different CPU or GPU core counts, but its Neural Engine
    /// core count is fixed; entries that disagree indicate a data error.
    private mutating func checkChipConsistency(_ entries: [CatalogEntry], paths: [String]) {
        var firstClaim: [String: (cores: Int, entryID: String)] = [:]
        for (entry, path) in zip(entries, paths) {
            guard let chip = entry.chip, let cores = chip.neuralEngineCores else { continue }
            if let claim = firstClaim[chip.name] {
                if claim.cores != cores {
                    issue(path + ".chip.neuralEngineCores",
                          "\(chip.name) has a \(claim.cores)-core Neural Engine in entry \"\(claim.entryID)\", not \(cores).")
                }
            } else {
                firstClaim[chip.name] = (cores, entry.id)
            }
        }
    }

    private mutating func validate(_ raw: RawVerification?, path: String) -> CatalogVerification? {
        guard let raw else {
            issue(path, "Required field is missing.")
            return nil
        }
        var status: CatalogVerificationStatus?
        if let text = nonEmpty(raw.status, path: path + ".status") {
            status = CatalogVerificationStatus(rawValue: text)
            if status == nil {
                let allowed = CatalogVerificationStatus.allCases.map(\.rawValue).joined(separator: ", ")
                issue(path + ".status", "\"\(text)\" is not one of: \(allowed).")
            }
        }
        let verifiedOn = nonEmpty(raw.verifiedOn, path: path + ".verifiedOn").flatMap {
            date(from: $0, path: path + ".verifiedOn")
        }
        guard let status, let verifiedOn else { return nil }
        return CatalogVerification(status: status, verifiedOn: verifiedOn)
    }

    // MARK: Helpers

    private mutating func nonEmpty(_ value: String?, path: String) -> String? {
        guard let value else {
            issue(path, "Required field is missing.")
            return nil
        }
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            issue(path, "Must not be empty.")
            return nil
        }
        return value
    }

    private mutating func date(from text: String, path: String) -> CalendarDate? {
        guard let date = CalendarDate(iso8601: text) else {
            issue(path, "\"\(text)\" is not a valid YYYY-MM-DD date.")
            return nil
        }
        return date
    }

    private mutating func issue(_ path: String, _ message: String) {
        issues.append(CatalogIssue(path: path, message: message))
    }

    private static func isSlug(_ text: String) -> Bool {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        return !parts.isEmpty && parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber) }
        }
    }

    /// `YYYY.MM.N`, e.g. `2026.10.0`.
    private static func isCatalogVersion(_ text: String) -> Bool {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, !parts[2].isEmpty,
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let month = Int(parts[1]), (1...12).contains(month)
        else { return false }
        return true
    }
}
