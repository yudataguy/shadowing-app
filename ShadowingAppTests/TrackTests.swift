import XCTest
@testable import ShadowingApp

final class TrackTests: XCTestCase {
    func test_stableID_combinesFolderIDAndRelativePath() {
        let folderID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let track = Track(
            folderID: folderID,
            relativePath: "lessons/01-intro.mp3",
            url: URL(fileURLWithPath: "/tmp/lessons/01-intro.mp3")
        )
        XCTAssertEqual(track.stableID, "00000000-0000-0000-0000-000000000001:lessons/01-intro.mp3")
    }

    func test_displayTitle_stripsExtension() {
        let track = Track(
            folderID: UUID(),
            relativePath: "lessons/01-intro.mp3",
            url: URL(fileURLWithPath: "/tmp/x.mp3")
        )
        XCTAssertEqual(track.displayTitle, "01-intro")
    }
}
