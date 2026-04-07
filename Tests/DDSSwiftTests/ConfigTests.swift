import XCTest

@testable import DDSSwift

final class ConfigTests: XCTestCase {

    func testSetMaxThreads_zeroCausesNoCrash() {
        DDSConfig.setMaxThreads(0)
        let info = DDSSolver.getInfo()
        XCTAssertGreaterThan(info.noOfThreads, 0, "Should auto-configure at least 1 thread")
    }

    func testSetMaxThreads_specificValue() {
        // SetMaxThreads only takes effect when DDS reinitializes internally.
        // Verify it does not crash and info remains valid.
        DDSConfig.setMaxThreads(1)
        let info = DDSSolver.getInfo()
        XCTAssertGreaterThan(info.noOfThreads, 0, "Should still have threads configured")

        // Reset to auto
        DDSConfig.setMaxThreads(0)
    }

    func testSetThreading_GCD() throws {
        // On macOS, GCD (code 3) should be available
        try DDSConfig.setThreading(3)
        let info = DDSSolver.getInfo()
        XCTAssertEqual(info.threading, 3, "Threading should be GCD (3)")
    }

    func testSetResources_noCrash() {
        DDSConfig.setResources(maxMemoryMB: 160, maxThreads: 2)
        let info = DDSSolver.getInfo()
        // Just verify we can still get info after setting resources
        XCTAssertGreaterThan(info.major, 0)
    }

    func testFreeMemory_noCrash() {
        DDSConfig.freeMemory()
        // Should not crash; verify we can still operate
        let info = DDSSolver.getInfo()
        XCTAssertGreaterThan(info.major, 0)
    }

    func testGetInfo_afterConfigChanges() {
        DDSConfig.setMaxThreads(0)
        let info1 = DDSSolver.getInfo()

        DDSConfig.setMaxThreads(1)
        let info2 = DDSSolver.getInfo()

        // Version should remain the same regardless of config
        XCTAssertEqual(info1.major, info2.major)
        XCTAssertEqual(info1.minor, info2.minor)
        XCTAssertEqual(info1.patch, info2.patch)

        // Thread count should still be positive
        XCTAssertGreaterThan(info2.noOfThreads, 0)

        // Reset
        DDSConfig.setMaxThreads(0)
    }
}
