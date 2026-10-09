import XCTest
@testable import FocusCore

final class StateStoreTests: XCTestCase {
    private var directory: URL!
    private var store: StateStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("focusblocker-tests-\(UUID().uuidString)", isDirectory: true)
        store = StateStore(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func sampleState() -> BlockState {
        BlockState(sites: ["x.com"], appBundleIDs: ["com.apple.Safari"],
                   endDate: Date(timeIntervalSince1970: 1_234_567.25), remainingMonotonic: 321.5)
    }

    func testLoadReturnsNilWhenMissing() throws {
        XCTAssertNil(try store.load())
    }

    func testSaveLoadRoundTrip() throws {
        try store.save(sampleState())
        XCTAssertEqual(try store.load(), sampleState())
    }

    func testFileMode0600() throws {
        try store.save(sampleState())
        let mode = try FileManager.default.attributesOfItem(atPath: store.fileURL.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(mode?.intValue, 0o600)
    }

    func testCorruptFileThrows() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.fileURL)
        XCTAssertThrowsError(try store.load())
    }

    func testClearIsIdempotent() throws {
        try store.save(sampleState())
        try store.clear()
        try store.clear()
        XCTAssertNil(try store.load())
    }

    func testSaveLeavesNoTempFile() throws {
        try store.save(sampleState())
        try store.save(sampleState())
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["state.json"])
    }
}
