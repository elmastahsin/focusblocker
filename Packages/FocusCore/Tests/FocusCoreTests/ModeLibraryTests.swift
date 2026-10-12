import XCTest
@testable import FocusCore

final class ModeLibraryTests: XCTestCase {
    private func mode(_ name: String, sites: [String] = ["a.com"]) -> FocusMode {
        FocusMode(name: name, symbol: "star.fill", color: .blue, sites: sites)
    }

    // MARK: starter

    func testStarterHasThreeUsableModes() {
        let library = ModeLibrary.starter()
        XCTAssertEqual(library.modes.map(\.name), ["Sosyal Medya", "Çalışma", "Derin Odak"])
        XCTAssertTrue(library.modes.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(library.modes[0].sites, DefaultBlockList.socialSites)
    }

    func testDeepFocusContainsEverything() {
        let library = ModeLibrary.starter()
        let deep = Set(library.modes[2].sites)
        XCTAssertTrue(deep.isSuperset(of: library.modes[0].sites))
        XCTAssertTrue(deep.isSuperset(of: library.modes[1].sites))
        XCTAssertTrue(deep.isSuperset(of: DefaultBlockList.deepFocusExtraSites))
    }

    // MARK: migration

    func testMigrationMovesLegacyListsIntoSocialAndDeepFocus() {
        let app = BlockedApp(bundleID: "com.example.Game", name: "Game")
        let library = ModeLibrary.migrating(legacySites: ["steamcommunity.com", "x.com"], legacyApps: [app])
        XCTAssertEqual(library.modes[0].sites, ["steamcommunity.com", "x.com"])
        XCTAssertEqual(library.modes[0].apps, [app])
        XCTAssertTrue(library.modes[2].sites.contains("steamcommunity.com"))
        XCTAssertEqual(library.modes[2].apps, [app])
    }

    func testMigrationDropsInvalidLegacySites() {
        let library = ModeLibrary.migrating(legacySites: ["valid.com", "not a site"], legacyApps: [])
        XCTAssertEqual(library.modes[0].sites, ["valid.com"])
    }

    func testEmptyLegacyFallsBackToStarter() {
        XCTAssertEqual(ModeLibrary.migrating(legacySites: [], legacyApps: []).modes.map(\.name),
                       ModeLibrary.starter().modes.map(\.name))
    }

    // MARK: add / update

    func testAddTrimsName() throws {
        var library = ModeLibrary()
        try library.add(mode("  Okuma  "))
        XCTAssertEqual(library.modes.first?.name, "Okuma")
    }

    func testAddRejectsBadNames() throws {
        var library = ModeLibrary(modes: [mode("Okuma")])
        XCTAssertThrowsError(try library.add(mode("   "))) { XCTAssertEqual($0 as? ModeError, .emptyName) }
        XCTAssertThrowsError(try library.add(mode("okuma"))) { XCTAssertEqual($0 as? ModeError, .duplicateName) }
        XCTAssertThrowsError(try library.add(mode(String(repeating: "x", count: 41)))) {
            XCTAssertEqual($0 as? ModeError, .nameTooLong)
        }
    }

    func testAddRespectsLimit() throws {
        var library = ModeLibrary()
        for i in 0..<ModeLibrary.maxModes { try library.add(mode("Mod \(i)")) }
        XCTAssertThrowsError(try library.add(mode("Fazla"))) { XCTAssertEqual($0 as? ModeError, .limitReached) }
    }

    func testUpdateAllowsKeepingOwnNameButNotTakingAnothers() throws {
        var library = ModeLibrary(modes: [mode("A"), mode("B")])
        var first = library.modes[0]
        first.sites = ["z.com"]
        try library.update(first)
        XCTAssertEqual(library.modes[0].sites, ["z.com"])

        first.name = "b"
        XCTAssertThrowsError(try library.update(first)) { XCTAssertEqual($0 as? ModeError, .duplicateName) }
    }

    func testUpdateUnknownModeFails() {
        var library = ModeLibrary(modes: [mode("A")])
        XCTAssertThrowsError(try library.update(mode("Other"))) { XCTAssertEqual($0 as? ModeError, .notFound) }
    }

    // MARK: delete / duplicate

    func testDeleteRemovesButKeepsLastMode() throws {
        var library = ModeLibrary(modes: [mode("A"), mode("B")])
        try library.delete(id: library.modes[0].id)
        XCTAssertEqual(library.modes.map(\.name), ["B"])
        XCTAssertThrowsError(try library.delete(id: library.modes[0].id)) {
            XCTAssertEqual($0 as? ModeError, .lastMode)
        }
        XCTAssertThrowsError(try library.delete(id: UUID())) { XCTAssertEqual($0 as? ModeError, .notFound) }
    }

    func testDuplicateInsertsRightAfterSourceWithUniqueNames() throws {
        var library = ModeLibrary(modes: [mode("A", sites: ["a.com", "b.com"]), mode("B")])
        let first = try library.duplicate(id: library.modes[0].id)
        let second = try library.duplicate(id: library.modes[0].id)
        XCTAssertEqual(library.modes.map(\.name), ["A", "A kopya 2", "A kopya", "B"])
        XCTAssertNotEqual(first.id, library.modes[0].id)
        XCTAssertEqual(first.sites, ["a.com", "b.com"])
        XCTAssertNotEqual(first.id, second.id)
    }

    // MARK: FocusMode editing

    func testModeSiteEditing() {
        var m = mode("A", sites: [])
        XCTAssertTrue(m.addSite("https://www.Reddit.com/r/swift"))
        XCTAssertTrue(m.addSite("reddit.com"))
        XCTAssertFalse(m.addSite("not a site"))
        XCTAssertEqual(m.sites, ["reddit.com"])
        m.removeSite("reddit.com")
        XCTAssertTrue(m.isEmpty)
    }

    func testModeAppEditing() {
        var m = mode("A", sites: [])
        let app = BlockedApp(bundleID: "com.example.App", name: "App")
        m.addApp(app)
        m.addApp(app)
        m.addApp(BlockedApp(bundleID: "bad id", name: "Bad"))
        XCTAssertEqual(m.apps, [app])
        m.removeApp(bundleID: "com.example.App")
        XCTAssertTrue(m.isEmpty)
    }

    func testSwitchedOffItemsStayListedButAreNotBlocked() {
        var m = mode("A", sites: ["a.com", "b.com"])
        m.addApp(BlockedApp(bundleID: "com.example.One", name: "One"))
        m.addApp(BlockedApp(bundleID: "com.example.Two", name: "Two"))
        m.setSite("a.com", enabled: false)
        m.setApp(bundleID: "com.example.One", enabled: false)
        XCTAssertEqual(m.sites, ["a.com", "b.com"])
        XCTAssertEqual(m.enabledSites, ["b.com"])
        XCTAssertEqual(m.enabledAppIDs, ["com.example.Two"])
        XCTAssertFalse(m.isSiteEnabled("a.com"))
        XCTAssertFalse(m.isAppEnabled(bundleID: "com.example.One"))

        m.setSite("a.com", enabled: true)
        XCTAssertEqual(m.enabledSites, ["a.com", "b.com"])
    }

    func testSwitchIgnoresItemsNotInMode() {
        var m = mode("A")
        m.setSite("other.com", enabled: false)
        m.setApp(bundleID: "com.example.Missing", enabled: false)
        XCTAssertTrue(m.disabledSites.isEmpty)
        XCTAssertTrue(m.disabledAppIDs.isEmpty)
    }

    func testRemovingClearsSwitchState() {
        var m = mode("A", sites: ["a.com"])
        m.addApp(BlockedApp(bundleID: "com.example.App", name: "App"))
        m.setSite("a.com", enabled: false)
        m.setApp(bundleID: "com.example.App", enabled: false)
        m.removeSite("a.com")
        m.removeApp(bundleID: "com.example.App")
        XCTAssertTrue(m.disabledSites.isEmpty)
        XCTAssertTrue(m.disabledAppIDs.isEmpty)

        m.addSite("a.com")
        XCTAssertEqual(m.enabledSites, ["a.com"])
    }

    func testAllSwitchedOffCountsAsEmpty() {
        var m = mode("A", sites: ["a.com"])
        m.addApp(BlockedApp(bundleID: "com.example.App", name: "App"))
        m.setSite("a.com", enabled: false)
        XCTAssertFalse(m.isEmpty)
        m.setApp(bundleID: "com.example.App", enabled: false)
        XCTAssertTrue(m.isEmpty)
    }

    // MARK: Codable

    func testCodableRoundTripKeepsSwitchState() throws {
        var m = mode("A", sites: ["a.com", "b.com"])
        m.addApp(BlockedApp(bundleID: "com.example.App", name: "App"))
        m.setSite("b.com", enabled: false)
        m.setApp(bundleID: "com.example.App", enabled: false)
        let data = try JSONEncoder().encode(m)
        XCTAssertEqual(try JSONDecoder().decode(FocusMode.self, from: data), m)
    }

    func testDecodesModesSavedBeforeSwitches() throws {
        let json = """
        {"id":"8D1F0C2A-6B7E-4F5A-9C3D-1E2F3A4B5C6D","name":"Old","symbol":"star.fill","color":"blue",
         "sites":["a.com"],"apps":[{"bundleID":"com.example.App","name":"App"}]}
        """
        let m = try JSONDecoder().decode(FocusMode.self, from: Data(json.utf8))
        XCTAssertEqual(m.enabledSites, ["a.com"])
        XCTAssertEqual(m.enabledAppIDs, ["com.example.App"])
    }

    func testCodableRoundTrip() throws {
        let library = ModeLibrary.starter()
        let data = try JSONEncoder().encode(library)
        XCTAssertEqual(try JSONDecoder().decode(ModeLibrary.self, from: data), library)
    }
}
