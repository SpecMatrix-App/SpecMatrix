import Darwin
import SpecMatrixCore

/// Typed access to `sysctlbyname`. Failures are returned, not hidden behind defaults.
enum Sysctl {
    static func string(_ name: String) -> Result<String, SpecError> {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0 else { return .failure(error(name)) }
        guard size > 0 else { return .failure(SpecError(operation: "sysctl \(name)", message: "Empty value.")) }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return .failure(error(name)) }
        return .success(CString.decode(buffer.prefix(size)))
    }

    static func integer(_ name: String) -> Result<Int, SpecError> {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0 else { return .failure(error(name)) }
        switch size {
        case MemoryLayout<Int32>.size:
            var value: Int32 = 0
            guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return .failure(error(name)) }
            return .success(Int(value))
        case MemoryLayout<Int64>.size:
            var value: Int64 = 0
            guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return .failure(error(name)) }
            return .success(Int(value))
        default:
            return .failure(SpecError(operation: "sysctl \(name)", message: "Unexpected value size \(size)."))
        }
    }

    private static func error(_ name: String) -> SpecError {
        SpecError(operation: "sysctl \(name)", message: String(cString: strerror(errno)))
    }
}

enum CString {
    /// Decodes bytes up to the first NUL as UTF-8.
    static func decode<C: Collection>(_ bytes: C) -> String where C.Element == UInt8 {
        String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }
}
