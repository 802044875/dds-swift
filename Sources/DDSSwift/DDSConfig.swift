internal import DDS

/// Configuration and lifecycle management for the DDS library.
public enum DDSConfig {

    /// Sets the maximum number of threads DDS will use.
    ///
    /// - Parameter threads: Number of threads (0 = auto-detect based on cores).
    public static func setMaxThreads(_ threads: Int32) {
        SetMaxThreads(threads)
    }

    /// Explicitly frees all DDS-allocated memory.
    ///
    /// Called automatically after batch operations in `DDSSolver`, but can be
    /// called manually if needed (e.g., under memory pressure).
    public static func freeMemory() {
        FreeMemory()
    }

    /// Sets the threading system used by DDS.
    ///
    /// - Parameter code: Threading backend code (0=none, 1=Windows, 2=OpenMP,
    ///   3=GCD, 4=Boost, 5=STL, 6=TBB).
    /// - Throws: `DDSError` if the requested threading system is not available.
    public static func setThreading(_ code: Int32) throws {
        let res = SetThreading(code)
        try checkDDS(res)
    }

    /// Configures memory and thread limits for DDS.
    ///
    /// - Parameters:
    ///   - maxMemoryMB: Maximum memory in MB that DDS may use.
    ///   - maxThreads: Maximum number of threads DDS may use.
    public static func setResources(maxMemoryMB: Int32, maxThreads: Int32) {
        SetResources(maxMemoryMB, maxThreads)
    }
}
