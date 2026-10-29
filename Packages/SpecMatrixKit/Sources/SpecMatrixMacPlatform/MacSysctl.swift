#if os(macOS)
import Darwin
import SpecMatrixShared

/// Typed access to `sysctlbyname`. Failures are returned, not hidden behind defaults.
///
/// The iOS providers have an equivalent internal helper in `SpecMatrixPlatform`. It is not shared,
/// because that target belongs to the iOS product and links the iPhone/iPad catalog.
enum MacSysctl {
    static func string(_ name: String) -> Result<String, SpecError> {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0 else { return .failure(error(name)) }
        guard size > 0 else { return .failure(SpecError(operation: "sysctl \(name)", message: "Empty value.")) }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return .failure(error(name)) }
        return .success(String(decoding: buffer.prefix(size).prefix { $0 != 0 }, as: UTF8.self))
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

    /// A fixed-size C structure such as `xsw_usage`.
    static func value<T>(_ name: String, as type: T.Type) -> Result<T, SpecError> {
        var size = MemoryLayout<T>.size
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<T>.alignment)
        defer { buffer.deallocate() }
        guard sysctlbyname(name, buffer, &size, nil, 0) == 0 else { return .failure(error(name)) }
        guard size == MemoryLayout<T>.size else {
            return .failure(SpecError(operation: "sysctl \(name)", message: "Unexpected value size \(size)."))
        }
        return .success(buffer.load(as: T.self))
    }

    private static func error(_ name: String) -> SpecError {
        SpecError(operation: "sysctl \(name)", message: String(cString: strerror(errno)))
    }
}
#endif
