import Foundation

/// Decodes and validates catalog JSON (schema version 1).
///
/// Validation rules:
/// 1. The data must be a JSON object with an integer `schemaVersion` equal to 1.
///    Other versions are rejected before any further parsing.
/// 2. Keys not defined by the schema are rejected, so typos cannot silently drop data.
/// 3. Values must have the declared JSON types (e.g. integers for core counts).
/// 4. Required fields: `catalogVersion`, and per entry `id`, `identifiers`, `family`,
///    `marketingName`, `sources`, `verification`. All other fields are optional; an
///    absent field means "not recorded", never zero.
/// 5. Present numeric fields must be positive; dates must be `YYYY-MM-DD`; URLs must be HTTPS;
///    identifiers must be well-formed and unique across the catalog; entry IDs must be
///    unique lowercase slugs.
/// All issues are collected; any issue rejects the whole catalog.
enum CatalogDecoder {
    static func decode(_ data: Data) -> Result<DeviceCatalog, CatalogLoadError> {
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

        var validator = Validator()
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
    let accessed: String?
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
    static let sourceKeys: Set<String> = ["title", "url", "accessed"]
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
    var issues: [CatalogIssue] = []
    private var seenEntryIDs: Set<String> = []
    private var seenIdentifiers: [HardwareIdentifier: String] = [:]

    mutating func validate(_ raw: RawCatalog) -> DeviceCatalog? {
        let catalogVersion = nonEmpty(raw.catalogVersion, path: "catalogVersion")
        guard let rawEntries = raw.entries else {
            issue("entries", "Required field is missing.")
            return nil
        }
        var entries: [CatalogEntry] = []
        for (index, rawEntry) in rawEntries.enumerated() {
            if let entry = validate(rawEntry, path: "entries[\(index)]") {
                entries.append(entry)
            }
        }
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
                identifiers.append(identifier)
            }
        } else {
            issue(path + ".identifiers", "At least one hardware identifier is required.")
        }

        let family = nonEmpty(raw.family, path: path + ".family")
        let marketingName = nonEmpty(raw.marketingName, path: path + ".marketingName")
        let releaseDate = raw.releaseDate.flatMap { date(from: $0, path: path + ".releaseDate") }
        let chip = raw.chip.flatMap { validate($0, path: path + ".chip") }
        let display = raw.display.map { validate($0, path: path + ".display") }
        let sources = validate(raw.sources, path: path + ".sources")
        let verification = validate(raw.verification, path: path + ".verification")

        guard issues.count == startCount,
              let id, let family, let marketingName, let verification
        else { return nil }
        return CatalogEntry(id: id, identifiers: identifiers, family: family, marketingName: marketingName,
                            releaseDate: releaseDate, chip: chip, display: display,
                            sources: sources, verification: verification)
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
        return DisplaySpecification(diagonal: diagonal, resolution: resolution, pixelDensity: density, maximumRefreshRate: refresh)
    }

    private mutating func validate(_ raw: [RawSource]?, path: String) -> [CatalogSource] {
        guard let raw, !raw.isEmpty else {
            issue(path, "At least one source is required.")
            return []
        }
        var sources: [CatalogSource] = []
        for (index, source) in raw.enumerated() {
            let sourcePath = "\(path)[\(index)]"
            let title = nonEmpty(source.title, path: sourcePath + ".title")
            var url: URL?
            if let text = nonEmpty(source.url, path: sourcePath + ".url") {
                url = URL(string: text)
                if url?.scheme != "https" || url?.host == nil {
                    issue(sourcePath + ".url", "Must be an absolute HTTPS URL.")
                    url = nil
                }
            }
            let accessed = nonEmpty(source.accessed, path: sourcePath + ".accessed").flatMap {
                date(from: $0, path: sourcePath + ".accessed")
            }
            if let title, let url, let accessed {
                sources.append(CatalogSource(title: title, url: url, accessed: accessed))
            }
        }
        return sources
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
}
