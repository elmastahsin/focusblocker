import XCTest
@testable import FocusCore

final class HostsBlockRendererTests: XCTestCase {
    private let original = "127.0.0.1\tlocalhost\n255.255.255.255\tbroadcasthost\n::1 localhost\n# my note\n"

    func testRenderEmitsFourLinesPerSite() {
        let block = HostsBlockRenderer.render(sites: ["x.com"])
        XCTAssertEqual(block, """
        # FOCUSBLOCKER-START
        0.0.0.0 x.com
        :: x.com
        0.0.0.0 www.x.com
        :: www.x.com
        # FOCUSBLOCKER-END

        """)
    }

    func testApplyKeepsOriginalLinesAndAppendsBlock() {
        let result = HostsBlockRenderer.apply(to: original, sites: ["x.com"])
        XCTAssertTrue(result.hasPrefix(original))
        XCTAssertTrue(result.hasSuffix(HostsBlockRenderer.render(sites: ["x.com"])))
    }

    func testApplyIsIdempotent() {
        let once = HostsBlockRenderer.apply(to: original, sites: ["x.com", "y.com"])
        XCTAssertEqual(HostsBlockRenderer.apply(to: once, sites: ["x.com", "y.com"]), once)
    }

    func testRemoveRestoresOriginalExactly() {
        let applied = HostsBlockRenderer.apply(to: original, sites: ["x.com"])
        XCTAssertEqual(HostsBlockRenderer.remove(from: applied), original)
    }

    func testTamperedEntryIsRepaired() {
        let applied = HostsBlockRenderer.apply(to: original, sites: ["x.com"])
        let tampered = applied.replacingOccurrences(of: "0.0.0.0 x.com", with: "127.0.0.1 x.com")
        XCTAssertNotEqual(tampered, applied)
        XCTAssertEqual(HostsBlockRenderer.apply(to: tampered, sites: ["x.com"]), applied)
    }

    func testDeletedBlockIsRestored() {
        let applied = HostsBlockRenderer.apply(to: original, sites: ["x.com"])
        XCTAssertEqual(HostsBlockRenderer.apply(to: original, sites: ["x.com"]), applied)
    }

    func testDuplicateBlocksCollapseToOne() {
        let block = HostsBlockRenderer.render(sites: ["x.com"])
        let doubled = original + block + block
        XCTAssertEqual(HostsBlockRenderer.apply(to: doubled, sites: ["x.com"]), original + block)
    }

    func testUnterminatedBlockRemovesOnlyItsEntries() {
        let broken = original + "# FOCUSBLOCKER-START\n0.0.0.0 x.com\n:: x.com\n10.0.0.1 keepme\n"
        XCTAssertEqual(HostsBlockRenderer.remove(from: broken), original + "10.0.0.1 keepme\n")
    }

    func testStrayEndMarkerIsRemoved() {
        XCTAssertEqual(HostsBlockRenderer.remove(from: original + "# FOCUSBLOCKER-END\n"), original)
    }

    func testEmptySitesProducesNoMarkers() {
        XCTAssertEqual(HostsBlockRenderer.apply(to: original, sites: []), original)
    }

    func testMissingTrailingNewlineIsHandled() {
        let result = HostsBlockRenderer.apply(to: "127.0.0.1 localhost", sites: ["x.com"])
        XCTAssertTrue(result.hasPrefix("127.0.0.1 localhost\n# FOCUSBLOCKER-START\n"))
    }
}
