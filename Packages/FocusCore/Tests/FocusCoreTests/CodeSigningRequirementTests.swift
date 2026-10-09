import XCTest
@testable import FocusCore

final class CodeSigningRequirementTests: XCTestCase {
    func testAppRequirementPinsIdentifierAndTeam() {
        XCTAssertEqual(CodeSigningRequirement.app(teamID: "ABCDE12345"),
                       "anchor apple generic and identifier \"app.focusblocker.app\" and certificate leaf[subject.OU] = \"ABCDE12345\"")
    }

    func testDaemonRequirementUsesDaemonLabel() {
        XCTAssertTrue(CodeSigningRequirement.daemon(teamID: "ABCDE12345")!.contains("\"app.focusblocker.daemon\""))
    }

    func testRejectsMalformedTeamID() {
        for bad in ["", "short", "abcde12345", "ABCDE1234\"", "ABCDE12345 or true"] {
            XCTAssertNil(CodeSigningRequirement.app(teamID: bad), bad)
        }
    }

    func testRequirementStringCompiles() {
        var requirement: SecRequirement?
        let text = CodeSigningRequirement.app(teamID: "ABCDE12345")!
        XCTAssertEqual(SecRequirementCreateWithString(text as CFString, [], &requirement), errSecSuccess)
    }
}
