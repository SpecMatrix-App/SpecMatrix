import Foundation
import SpecMatrixShared

/// Decodes and validates Mac catalog JSON (schema version 1).
///
/// Rules (all issues are collected; any issue rejects the whole catalog):
/// 1. A JSON object whose integer `schemaVersion` is 1; other versions are rejected first.
/// 2. Unknown keys are rejected at every level, so typos cannot silently drop data.
/// 3. Required: `catalogVersion`, at least one entry, and per entry `id` (unique lowercase slug),
///    `identifiers`, `marketingName`, `sources`, `verification`. Everything else is optional; an absent
///    field means "not recorded", never zero.
/// 4. Identifiers are well-formed, unique across the catalog, and use a Mac prefix
///    (`MacCatalog.identifierFamilies`).
/// 5. Numbers are positive; dates are valid `YYYY-MM-DD`; display resolution is landscape and
///    complete (width and height together).
/// 6. Sources have a title, an HTTPS `url`, an `accessed` date and a non-empty `supports` list drawn
///    from `MacCatalog.fields`. Every populated field group is supported by a source, and no source
///    claims a group the entry does not record.
/// 7. `accessed` and `releaseDate` are not after `verifiedOn`. `verified` entries have an apple.com
///    source for every populated group other than identifiers, and identifiers supported by at
///    least two independent publishers (the same policy as the iPhone/iPad catalog).
enum MacCatalogDecoder {
    static let manufacturerPublisher = "apple.com"
    static let minimumIdentifierPublishers = 2

    static func decode(_ data: Data) -> Result<MacCatalog, CatalogLoadError> {
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
        guard version == MacCatalog.supportedSchemaVersion else {
            return .failure(.unsupportedSchemaVersion(found: version, supported: MacCatalog.supportedSchemaVersion))
        }

        var validator = Validator()
        validator.checkKeys(root)

        let raw: RawCatalog
        do {
            raw = try JSONDecoder().decode(RawCatalog.self, from: data)
        } catch {
            return .failure(.malformedJSON(String(describing: error)))
        }
        let catalog = validator.validate(raw)
        guard validator.issues.isEmpty, let catalog else {
            return .failure(.invalid(validator.issues))
        }
        return .success(catalog)
    }
}

// MARK: - Raw schema (every field optional so validation can report all problems)

private struct RawCatalog: Decodable {
    let catalogVersion: String?
    let entries: [RawEntry]?
}

private struct RawEntry: Decodable {
    let id: String?
    let identifiers: [String]?
    let marketingName: String?
    let releaseDate: String?
    let chip: RawChip?
    let display: RawDisplay?
    let sources: [RawSource]?
    let verification: RawVerification?
}

private struct RawChip: Decodable {
    let name: String?
    let performanceCores: Int?
    let efficiencyCores: Int?
    let gpuCores: Int?
    let neuralEngineCores: Int?
}

private struct RawDisplay: Decodable {
    let diagonalInches: Double?
    let pixelWidth: Int?
    let pixelHeight: Int?
    let pixelsPerInch: Int?
    let maximumRefreshRateHz: Int?
}

private struct RawSource: Decodable {
    let title: String?
    let url: String?
    let accessed: String?
    let supports: [String]?
}

private struct RawVerification: Decodable {
    let status: String?
    let verifiedOn: String?
}

// MARK: - Validation

private struct Validator {
    private(set) var issues: [CatalogIssue] = []
    private var seenIDs: Set<String> = []
    private var seenIdentifiers: [HardwareIdentifier: String] = [:]

    private static let rootKeys: Set<String> = ["schemaVersion", "catalogVersion", "derivedFrom", "entries"]
    private static let entryKeys: Set<String> = ["id", "identifiers", "marketingName", "releaseDate", "chip", "display",
                                                 "sources", "verification"]
    private static let chipKeys: Set<String> = ["name", "performanceCores", "efficiencyCores", "gpuCores", "neuralEngineCores"]
    private static let displayKeys: Set<String> = ["diagonalInches", "pixelWidth", "pixelHeight", "pixelsPerInch",
                                                   "maximumRefreshRateHz"]
    private static let sourceKeys: Set<String> = ["title", "url", "accessed", "supports"]
    private static let verificationKeys: Set<String> = ["status", "verifiedOn"]

    mutating func checkKeys(_ root: [String: Any]) {
        unexpected(root, Self.rootKeys, "")
        for (index, value) in (root["entries"] as? [Any] ?? []).enumerated() {
            guard let entry = value as? [String: Any] else { continue }
            let path = "entries[\(index)]"
            unexpected(entry, Self.entryKeys, path)
            if let chip = entry["chip"] as? [String: Any] { unexpected(chip, Self.chipKeys, path + ".chip") }
            if let display = entry["display"] as? [String: Any] { unexpected(display, Self.displayKeys, path + ".display") }
            if let verification = entry["verification"] as? [String: Any] {
                unexpected(verification, Self.verificationKeys, path + ".verification")
            }
            for (sourceIndex, source) in (entry["sources"] as? [Any] ?? []).enumerated() {
                if let source = source as? [String: Any] { unexpected(source, Self.sourceKeys, "\(path).sources[\(sourceIndex)]") }
            }
        }
    }

    mutating func validate(_ raw: RawCatalog) -> MacCatalog? {
        let catalogVersion = nonEmpty(raw.catalogVersion, "catalogVersion")
        guard let rawEntries = raw.entries, !rawEntries.isEmpty else {
            issue("entries", "At least one entry is required.")
            return nil
        }
        var entries: [MacCatalogEntry] = []
        for (index, rawEntry) in rawEntries.enumerated() {
            if let entry = validate(rawEntry, path: "entries[\(index)]") { entries.append(entry) }
        }
        guard let catalogVersion, issues.isEmpty else { return nil }
        return MacCatalog(catalogVersion: catalogVersion, entries: entries)
    }

    private mutating func validate(_ raw: RawEntry, path: String) -> MacCatalogEntry? {
        let startCount = issues.count

        let id = nonEmpty(raw.id, path + ".id")
        if let id {
            if !Self.isSlug(id) { issue(path + ".id", "Must be a lowercase slug such as \"macbook-air-m2-2022\".") }
            if !seenIDs.insert(id).inserted { issue(path + ".id", "Duplicate entry ID \"\(id)\".") }
        }

        var identifiers: [HardwareIdentifier] = []
        if let rawIdentifiers = raw.identifiers, !rawIdentifiers.isEmpty {
            for (index, text) in rawIdentifiers.enumerated() {
                let identifierPath = "\(path).identifiers[\(index)]"
                guard let identifier = HardwareIdentifier(text), identifier.rawValue == text else {
                    issue(identifierPath, "\"\(text)\" is not a valid model identifier.")
                    continue
                }
                if !MacCatalog.identifierFamilies.contains(identifier.family) {
                    issue(identifierPath, "\(text) is not a Mac model identifier.")
                }
                if let owner = seenIdentifiers[identifier] {
                    issue(identifierPath, "\(text) is already assigned to entry \"\(owner)\".")
                } else {
                    seenIdentifiers[identifier] = id ?? path
                }
                identifiers.append(identifier)
            }
        } else {
            issue(path + ".identifiers", "At least one model identifier is required.")
        }

        let marketingName = nonEmpty(raw.marketingName, path + ".marketingName")
        let releaseDate = raw.releaseDate.flatMap { date($0, path + ".releaseDate") }
        let chip = raw.chip.flatMap { validate($0, path: path + ".chip") }
        let display = raw.display.map { validate($0, path: path + ".display") }
        let sources = validate(raw.sources, path: path + ".sources")

        var populated: Set<CatalogField> = [.identifiers, .marketingName]
        if raw.releaseDate != nil { populated.insert(.releaseDate) }
        if raw.chip != nil { populated.insert(.chip) }
        if raw.display != nil { populated.insert(.display) }
        checkAttribution(sources, populated: populated, path: path)

        var status: CatalogVerificationStatus?
        var verifiedOn: CalendarDate?
        if let verification = raw.verification {
            if let text = nonEmpty(verification.status, path + ".verification.status") {
                status = CatalogVerificationStatus(rawValue: text)
                if status == nil {
                    let allowed = CatalogVerificationStatus.allCases.map(\.rawValue).joined(separator: ", ")
                    issue(path + ".verification.status", "\"\(text)\" is not one of: \(allowed).")
                }
            }
            verifiedOn = nonEmpty(verification.verifiedOn, path + ".verification.verifiedOn")
                .flatMap { date($0, path + ".verification.verifiedOn") }
        } else {
            issue(path + ".verification", "Required field is missing.")
        }

        if let verifiedOn {
            for (index, source) in sources where source.accessed > verifiedOn {
                issue("\(path).sources[\(index)].accessed", "Accessed \(source.accessed), after verifiedOn \(verifiedOn).")
            }
            if let releaseDate, releaseDate > verifiedOn {
                issue(path + ".releaseDate", "Release date \(releaseDate) is after verifiedOn \(verifiedOn).")
            }
        }
        if status == .verified {
            checkVerifiedPolicy(sources.map(\.source), populated: populated, path: path)
        }

        guard issues.count == startCount, let id, let marketingName, let status, let verifiedOn else { return nil }
        return MacCatalogEntry(id: id, identifiers: identifiers, marketingName: marketingName, releaseDate: releaseDate,
                               chip: chip, display: display, sources: sources.map(\.source),
                               verificationStatus: status, verifiedOn: verifiedOn)
    }

    private mutating func validate(_ raw: RawChip, path: String) -> MacChipSpecification? {
        let name = nonEmpty(raw.name, path + ".name")
        let counts = [("performanceCores", raw.performanceCores), ("efficiencyCores", raw.efficiencyCores),
                      ("gpuCores", raw.gpuCores), ("neuralEngineCores", raw.neuralEngineCores)]
        for (key, value) in counts {
            if let value, value <= 0 { issue("\(path).\(key)", "Must be a positive integer (found \(value)).") }
        }
        guard let name else { return nil }
        return MacChipSpecification(name: name, performanceCores: raw.performanceCores, efficiencyCores: raw.efficiencyCores,
                                    gpuCores: raw.gpuCores, neuralEngineCores: raw.neuralEngineCores)
    }

    private mutating func validate(_ raw: RawDisplay, path: String) -> MacDisplaySpecification {
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
            if width < height { issue(path, "Resolution must be in landscape order (width ≥ height).") }
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
        return MacDisplaySpecification(diagonal: diagonal, resolution: resolution, pixelDensity: density, maximumRefreshRate: refresh)
    }

    private mutating func validate(_ raw: [RawSource]?, path: String) -> [(index: Int, source: CatalogSource)] {
        guard let raw, !raw.isEmpty else {
            issue(path, "At least one source is required.")
            return []
        }
        var sources: [(index: Int, source: CatalogSource)] = []
        var seenURLs: Set<URL> = []
        for (index, rawSource) in raw.enumerated() {
            let sourcePath = "\(path)[\(index)]"
            let title = nonEmpty(rawSource.title, sourcePath + ".title")
            var url: URL?
            if let text = nonEmpty(rawSource.url, sourcePath + ".url") {
                if let parsed = URL(string: text), parsed.scheme == "https", parsed.host?.isEmpty == false {
                    url = parsed
                    if !seenURLs.insert(parsed).inserted { issue(sourcePath, "Duplicate source within the entry.") }
                } else {
                    issue(sourcePath + ".url", "Must be an absolute HTTPS URL.")
                }
            }
            let accessed = nonEmpty(rawSource.accessed, sourcePath + ".accessed").flatMap { date($0, sourcePath + ".accessed") }
            var supports: Set<CatalogField> = []
            if let rawSupports = rawSource.supports, !rawSupports.isEmpty {
                for text in rawSupports {
                    guard let field = CatalogField(rawValue: text), MacCatalog.fields.contains(field) else {
                        let allowed = MacCatalog.fields.map(\.rawValue).joined(separator: ", ")
                        issue(sourcePath + ".supports", "\"\(text)\" is not one of: \(allowed).")
                        continue
                    }
                    if !supports.insert(field).inserted { issue(sourcePath + ".supports", "\"\(text)\" is listed twice.") }
                }
            } else {
                issue(sourcePath + ".supports", "At least one supported field is required.")
            }
            if let title, let url, let accessed, !supports.isEmpty {
                sources.append((index, CatalogSource(title: title, location: .web(url), accessed: accessed, supports: supports)))
            }
        }
        return sources
    }

    private mutating func checkAttribution(_ sources: [(index: Int, source: CatalogSource)],
                                           populated: Set<CatalogField>, path: String) {
        guard !sources.isEmpty else { return } // Already reported.
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
        guard !sources.isEmpty else { return }
        let statusPath = path + ".verification.status"
        for field in populated.subtracting([.identifiers]).sorted() {
            let published = sources.contains {
                $0.supports.contains(field) && $0.publisher == MacCatalogDecoder.manufacturerPublisher
            }
            if !published {
                issue(statusPath, "verified requires an \(MacCatalogDecoder.manufacturerPublisher) source for \(field.rawValue).")
            }
        }
        let publishers = Set(sources.filter { $0.supports.contains(.identifiers) }.map(\.publisher))
        if publishers.count < MacCatalogDecoder.minimumIdentifierPublishers {
            issue(statusPath, "verified requires identifiers supported by \(MacCatalogDecoder.minimumIdentifierPublishers) independent publishers (found \(publishers.count)).")
        }
    }

    // MARK: Helpers

    private mutating func unexpected(_ object: [String: Any], _ allowed: Set<String>, _ path: String) {
        for key in object.keys.sorted() where !allowed.contains(key) {
            issue(path.isEmpty ? key : "\(path).\(key)", "Unknown field.")
        }
    }

    private mutating func nonEmpty(_ value: String?, _ path: String) -> String? {
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

    private mutating func date(_ text: String, _ path: String) -> CalendarDate? {
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
}
