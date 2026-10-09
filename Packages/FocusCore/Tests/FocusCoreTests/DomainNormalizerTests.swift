import XCTest
@testable import FocusCore

final class DomainNormalizerTests: XCTestCase {
    func testStripsSchemeWwwPathPortAndCase() {
        XCTAssertEqual(DomainNormalizer.normalize("  HTTPS://www.X.com:8080/a/b?c=d#e "), "x.com")
        XCTAssertEqual(DomainNormalizer.normalize("user@instagram.com"), "instagram.com")
        XCTAssertEqual(DomainNormalizer.normalize("youtube.com."), "youtube.com")
    }

    func testKeepsSubdomains() {
        XCTAssertEqual(DomainNormalizer.normalize("m.youtube.com"), "m.youtube.com")
    }

    func testIsIdempotent() {
        let once = DomainNormalizer.normalize("https://www.reddit.com/r/swift")!
        XCTAssertEqual(DomainNormalizer.normalize(once), once)
    }

    func testRejectsInvalidInput() {
        for bad in ["", "localhost", "-x.com", "x-.com", "a..com", "x.123", "exa mple.com",
                    "evil.com\n0.0.0.0 bank.com", "bad_name.com", "çay.com"] {
            XCTAssertNil(DomainNormalizer.normalize(bad), bad)
        }
    }

    func testBundleIDValidation() {
        XCTAssertTrue(BundleIDValidator.isValid("com.apple.Safari"))
        XCTAssertTrue(BundleIDValidator.isValid("org.my_app-1.Test"))
        XCTAssertFalse(BundleIDValidator.isValid(""))
        XCTAssertFalse(BundleIDValidator.isValid("com.apple Safari"))
        XCTAssertFalse(BundleIDValidator.isValid("a\nb"))
    }
}
