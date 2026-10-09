import XCTest
@testable import FocusCore

final class AppBundleMatcherTests: XCTestCase {
    func testPlainAppExecutable() {
        XCTAssertEqual(AppBundleMatcher.enclosingBundlePaths(forExecutable: "/System/Applications/Calculator.app/Contents/MacOS/Calculator"),
                       ["/System/Applications/Calculator.app"])
    }

    func testNestedHelperMatchesBothBundlesOutermostFirst() {
        let path = "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Helpers/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper"
        XCTAssertEqual(AppBundleMatcher.enclosingBundlePaths(forExecutable: path), [
            "/Applications/Google Chrome.app",
            "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Helpers/Google Chrome Helper.app",
        ])
    }

    func testNonBundleExecutableHasNoBundles() {
        XCTAssertTrue(AppBundleMatcher.enclosingBundlePaths(forExecutable: "/usr/bin/ssh").isEmpty)
    }

    func testProtectedBundles() {
        XCTAssertTrue(AppBundleMatcher.protectedBundleIDs.contains(Identifiers.appBundleID))
        XCTAssertTrue(AppBundleMatcher.protectedBundleIDs.contains("com.apple.finder"))
        XCTAssertFalse(AppBundleMatcher.protectedBundleIDs.contains("com.apple.Safari"))
    }
}
