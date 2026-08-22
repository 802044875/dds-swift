import XCTest

@testable import DDSSwift

final class ConfigTests: XCTestCase {

    func testInitialize_noCrash() {
        // DDSConfig.initialize() wraps InitializeStaticMemory() — should never crash.
        DDSConfig.initialize()
        let info = DDSSolver.getInfo()
        XCTAssertGreaterThan(info.major, 0)
    }

    func testSetMaxThreads_zeroCausesNoCrash() {
        // In DDS 3.x, SetMaxThreads is a deprecated alias for InitializeStaticMemory().
        DDSConfig.setMaxThreads(0)
        let info = DDSSolver.getInfo()
        XCTAssertGreaterThan(info.numCores, 0, "Should detect at least 1 hardware core")
    }

    func testSetMaxThreads_specificValue() {
        // In DDS 3.x the thread-count argument is ignored; verify no crash.
        DDSConfig.setMaxThreads(1)
        let info = DDSSolver.getInfo()
        XCTAssertGreaterThan(info.numCores, 0, "Should still have cores detected")
        DDSConfig.setMaxThreads(0)
    }

    func testSetResources_noCrash() {
        DDSConfig.setResources(maxMemoryMB: 160, maxThreads: 2)
        let info = DDSSolver.getInfo()
        XCTAssertGreaterThan(info.major, 0)
    }

    func testGetInfo_versionIs3() {
        let info = DDSSolver.getInfo()
        XCTAssertEqual(info.major, 3, "DDS 3.1.0 should report major version 3")
        XCTAssertEqual(info.minor, 1)
        XCTAssertEqual(info.patch, 0)
        XCTAssertEqual(info.versionString, "3.1.0")
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

        XCTAssertGreaterThan(info2.numCores, 0)

        DDSConfig.setMaxThreads(0)
    }
}
