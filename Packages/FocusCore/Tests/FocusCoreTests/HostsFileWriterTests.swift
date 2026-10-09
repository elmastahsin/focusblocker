import XCTest
@testable import FocusCore

final class HostsFileWriterTests: XCTestCase {
    private let original = "127.0.0.1\tlocalhost\n::1 localhost\n# my note\n"
    private var directory: URL!
    private var hostsURL: URL!
    private var backupURL: URL!
    private var writer: HostsFileWriter!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("focusblocker-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        hostsURL = directory.appendingPathComponent("hosts")
        backupURL = directory.appendingPathComponent("support/hosts.bak")
        try Data(original.utf8).write(to: hostsURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: hostsURL.path)
        writer = HostsFileWriter(hostsURL: hostsURL, backupURL: backupURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func hosts() throws -> String { try String(contentsOf: hostsURL, encoding: .utf8) }

    func testSyncWritesBlockOnceThenReportsNoChange() throws {
        XCTAssertTrue(try writer.sync(sites: ["x.com"]))
        XCTAssertEqual(try hosts(), HostsBlockRenderer.apply(to: original, sites: ["x.com"]))
        XCTAssertFalse(try writer.sync(sites: ["x.com"]))
    }

    func testTamperingIsRepaired() throws {
        try writer.sync(sites: ["x.com"])
        try Data(original.utf8).write(to: hostsURL)                    // user wipes the block
        XCTAssertTrue(try writer.sync(sites: ["x.com"]))
        XCTAssertTrue(try hosts().contains("0.0.0.0 x.com"))
    }

    func testUserEditsOutsideBlockSurvive() throws {
        try writer.sync(sites: ["x.com"])
        try Data((try hosts() + "10.0.0.5 devbox\n").utf8).write(to: hostsURL)
        try writer.sync(sites: ["x.com"])
        XCTAssertTrue(try hosts().contains("10.0.0.5 devbox"))
    }

    func testClearRestoresOriginalByteForByte() throws {
        try writer.sync(sites: ["x.com", "y.com"])
        XCTAssertTrue(try writer.clear())
        XCTAssertEqual(try hosts(), original)
        XCTAssertFalse(try writer.clear())
    }

    func testBackupHoldsContentWithoutBlock() throws {
        try writer.sync(sites: ["x.com"])
        XCTAssertEqual(try String(contentsOf: backupURL, encoding: .utf8), original)
    }

    func testPermissionsPreservedAndNoTempLeft() throws {
        try writer.sync(sites: ["x.com"])
        let mode = try FileManager.default.attributesOfItem(atPath: hostsURL.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(mode?.intValue, 0o644)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(), ["hosts", "support"])
    }

    func testMissingHostsFileIsCreated() throws {
        try FileManager.default.removeItem(at: hostsURL)
        XCTAssertTrue(try writer.sync(sites: ["x.com"]))
        XCTAssertEqual(try hosts(), HostsBlockRenderer.render(sites: ["x.com"]))
    }
}
