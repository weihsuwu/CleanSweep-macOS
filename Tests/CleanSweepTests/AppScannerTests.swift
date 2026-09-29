import XCTest
@testable import CleanSweep

final class AppScannerTests: XCTestCase {
    func testFileSizeTextIsNotEmpty() {
        XCTAssertFalse(Int64(1_024).fileSizeText.isEmpty)
    }

    func testDirectorySizeForMissingPathIsZero() {
        let url = URL(fileURLWithPath: "/tmp/cleansweep-this-path-should-not-exist")
        XCTAssertEqual(AppScanner.directorySize(at: url), 0)
    }
}
