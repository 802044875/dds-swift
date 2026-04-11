# dds-swift

Swift Package Manager wrapper for the [DDS (Double Dummy Solver)](https://github.com/dds-bridge/dds) bridge hand solver, with iOS and macOS sandbox patches.

This is a fork of the upstream DDS 2.9.0 C/C++ library (dormant since July 2020), restructured as an SPM package with a pure Swift API layer.

## Installation

Add the package dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/802044875/dds-swift.git", from: "2.10.0")
]
```

Then add the product dependency to your target:

```swift
.target(name: "YourTarget", dependencies: [
    .product(name: "DDSSwift", package: "dds-swift")
])
```

## Patches vs Upstream

This fork applies patches to the upstream DDS source. The upstream repository has not been updated since July 2020 and does not contain these fixes.

### `src/System.cpp` — Memory Detection Fix

Replaced `popen("sysctl -n hw.memsize")` with `sysctlbyname()` C API call. The `popen` approach spawns a shell which fails in the iOS simulator sandbox (`sh: sysctl: command not found`), causing DDS to detect 0 KB of memory. The `sysctlbyname()` call works in all Apple environments. Fallback chain retained: `os_proc_available_memory()` on iOS, then 1.4 GB hardcoded fallback.

### `Sources/DDSSwift/DDSSolver.swift` — Thread Safety

All public `DDSSolver` methods are serialized via a `DispatchQueue` to prevent concurrent access to DDS global mutable state (`memory`, `scheduler`, `cparam`, `threadMgr`). DDS handles internal parallelism via `dispatch_apply`, so serializing external calls does not reduce throughput.

## Swift API

The `DDSSwift` module provides a pure Swift interface to the DDS C library. All C types are hidden behind `internal import` — consumers only see Swift types.

Wraps all recommended DDS functions. Deprecated functions (`CalcPar`, `CalcParPBN`) and superseded functions (`SolveAllChunks*`) are intentionally excluded.

### Solving

| Function | DDS C Function | Description |
|----------|---------------|-------------|
| `DDSSolver.solveBoard(pbn:target:solutions:mode:trump:first:...)` | `SolveBoardPBN` | Solve a single board position (PBN) |
| `DDSSolver.solveBoard(deal:target:solutions:mode:)` | `SolveBoard` | Solve a single board position (binary) |
| `DDSSolver.solveAllBoards(boards:)` | `SolveAllBoards` | Batch solve multiple boards in parallel |

### DD Table Calculation

| Function | DDS C Function | Description |
|----------|---------------|-------------|
| `DDSSolver.calcDDTablePBN(pbn:)` | `CalcDDtablePBN` | Single-board DD table (PBN) |
| `DDSSolver.calcDDTable(deal:)` | `CalcDDtable` | Single-board DD table (binary) |
| `DDSSolver.calcTables(hands:vulns:dealers:)` | `CalcAllTablesPBN` + `DealerPar` | Batch DD table + par calculation |

### Par Calculation

| Function | DDS C Function | Description |
|----------|---------------|-------------|
| `DDSSolver.par(table:vulnerable:)` | `Par` | Par score and contracts from NS/EW perspective |
| `DDSSolver.dealerPar(table:dealer:vulnerable:)` | `DealerPar` | Par from specific dealer's perspective |
| `DDSSolver.sidesPar(table:vulnerable:)` | `SidesPar` | Par for both sides |
| `DDSSolver.dealerParBin(table:dealer:vulnerable:)` | `DealerParBin` | Structured par from dealer's perspective |
| `DDSSolver.sidesParBin(table:vulnerable:)` | `SidesParBin` | Structured par for both sides |
| `DDSSolver.convertToDealerTextFormat(par:)` | `ConvertToDealerTextFormat` | Format structured par as dealer text |
| `DDSSolver.convertToSidesTextFormat(sides:)` | `ConvertToSidesTextFormat` | Format structured par as sides text |

### Play Analysis

| Function | DDS C Function | Description |
|----------|---------------|-------------|
| `DDSSolver.analysePlay(deal:play:)` | `AnalysePlayBin` | DD values after each card (binary) |
| `DDSSolver.analysePlayPBN(deal:play:)` | `AnalysePlayPBN` | DD values after each card (PBN) |
| `DDSSolver.analyseAllPlays(boards:plays:)` | `AnalyseAllPlaysBin` | Batch play analysis (binary) |
| `DDSSolver.analyseAllPlaysPBN(boards:plays:)` | `AnalyseAllPlaysPBN` | Batch play analysis (PBN) |

### Configuration

| Function | DDS C Function | Description |
|----------|---------------|-------------|
| `DDSSolver.getInfo()` | `GetDDSInfo` | DDS version, threading, memory, and core information |
| `DDSConfig.setMaxThreads(_:)` | `SetMaxThreads` | Set max thread count (0 = auto-detect) |
| `DDSConfig.freeMemory()` | `FreeMemory` | Explicitly free DDS-allocated memory |
| `DDSConfig.setThreading(_:)` | `SetThreading` | Set threading backend |
| `DDSConfig.setResources(maxMemoryMB:maxThreads:)` | `SetResources` | Configure memory and thread limits |

### Swift Types

| Type | Description |
|------|-------------|
| `DDSFutureTricks` | Result of `solveBoard` — playable cards with trick counts |
| `DDSTableResults` | 5×4 trick table (5 strains × 4 hands) |
| `DDSDeal` | Binary card representation (bitmask holdings per hand/suit) |
| `DDSParResults` | Par scores and contracts from NS/EW perspective |
| `DDSParResultsDealer` | Par result from dealer's perspective |
| `DDSParResultsMaster` | Structured par with contract entries |
| `DDSContractType` | Single par contract entry (level, denomination, seats, tricks) |
| `DDSParTextResults` | Short par text with equality flag |
| `DDSPlayTrace` | Binary play trace (suits and ranks) |
| `DDSPlayTracePBN` | PBN play trace (card string) |
| `DDSSolvedPlay` | DD trick values after each card in a play sequence |
| `DDSInfoResult` | System and version information |
| `DDSError` | Error enum mapping all DDS C error codes to Swift cases with descriptions |

## Tests

Run tests from the package directory:

```bash
swift test
```

The test suite includes 46 tests across 9 test files:
- **DDSSolverTests** — batch DD table calculation with 18 boards and known optimum scores
- **SolveBoardTests** — PBN and binary single-board solving with cross-validation
- **SolveAllBoardsTests** — batch solving, verified against individual results
- **CalcDDTableTests** — single-table DD calculation (PBN and binary) with reference data
- **ParCalculationTests** — all par variants (Par, DealerPar, SidesPar, binary, text conversion)
- **PlayAnalysisTests** — single and batch play analysis (PBN and binary)
- **ConfigTests** — threading, resource configuration, memory management
- **ErrorTests** — invalid inputs produce correct DDSError cases
- **ThreadSafetyTests** — rapid sequential and concurrent calls across multiple threads

## Licence

This fork retains the original **Apache 2.0** licence from upstream DDS.

(c) Bo Haglund 2006-2014, (c) Bo Haglund / Soren Hein 2014-2018.
Swift wrapper (c) 2024-2026.

See [LICENSE](LICENSE) for full licence text.

## Upstream

- **Repository:** https://github.com/dds-bridge/dds
- **Version:** 2.9.0 (August 2018)
- **Status:** Dormant since July 2020
