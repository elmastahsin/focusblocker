import XCTest
@testable import FocusCore

final class DefaultBlockListTests: XCTestCase {
    func testDefaultSitesAreNormalizedAndUnique() {
        let lists = [DefaultBlockList.socialSites, DefaultBlockList.workSites, DefaultBlockList.deepFocusExtraSites]
        for list in lists {
            for site in list {
                XCTAssertEqual(DomainNormalizer.normalize(site), site)
            }
            XCTAssertEqual(Set(list).count, list.count)
        }
    }
}
