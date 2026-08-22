internal import DDS

/// Configuration and lifecycle management for the DDS library.
public enum DDSConfig {

    /// Initialises DDS static memory (transposition tables, thread pools, lookup tables).
    ///
    /// DDS 3.1.0 initialises itself lazily on first use. Call this explicitly at app
    /// start if you want to absorb the one-time setup cost before the first solve.
    public static func initialize() {
        InitializeStaticMemory()
    }

    /// Sets the maximum number of threads DDS will use.
    ///
    /// Deprecated in DDS 3.x — acts as an alias for `initialize()`. The thread
    /// count is now controlled per-call via the N-variants (e.g. `SolveAllBoardsN`).
    ///
    /// - Parameter threads: Ignored in DDS 3.x.
    public static func setMaxThreads(_ threads: Int32) {
        SetMaxThreads(threads)
    }

    /// Sets memory and thread limits for DDS.
    ///
    /// Deprecated in DDS 3.x — use the N-variants for per-call thread caps.
    ///
    /// - Parameters:
    ///   - maxMemoryMB: Maximum memory in MB that DDS may use.
    ///   - maxThreads: Maximum number of threads DDS may use.
    public static func setResources(maxMemoryMB: Int32, maxThreads: Int32) {
        SetResources(maxMemoryMB, maxThreads)
    }
}
