import XCTest
@testable import ShadowingApp

final class BundledLibraryTests: XCTestCase {
    private var fixtureRoot: URL!

    override func setUp() {
        // Build a fixture directory mirroring the production layout:
        //   <root>/SampleAudio/*.mp3
        fixtureRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sampleDir = fixtureRoot.appendingPathComponent("SampleAudio")
        try! FileManager.default.createDirectory(at: sampleDir, withIntermediateDirectories: true)
        for name in ["a.mp3", "b.mp3", "c.mp3", "notes.txt"] {
            FileManager.default.createFile(atPath: sampleDir.appendingPathComponent(name).path,
                                           contents: Data())
        }
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fixtureRoot)
    }

    func test_tracks_returnsOnlyMP3s() {
        let tracks = BundledLibrary.tracks(resourceURL: fixtureRoot)
        XCTAssertEqual(tracks.count, 3)
        XCTAssertTrue(tracks.allSatisfy { $0.url.pathExtension.lowercased() == "mp3" })
    }

    func test_tracks_useFixedFolderID() {
        let tracks = BundledLibrary.tracks(resourceURL: fixtureRoot)
        XCTAssertTrue(tracks.allSatisfy { $0.folderID == BundledLibrary.folderID })
    }

    func test_tracks_haveStableIDs() {
        let tracks = BundledLibrary.tracks(resourceURL: fixtureRoot)
        XCTAssertEqual(Set(tracks.map(\.stableID)).count, tracks.count)
    }

    func test_tracks_areSortedByName() {
        let tracks = BundledLibrary.tracks(resourceURL: fixtureRoot)
        XCTAssertEqual(tracks.map(\.relativePath), ["a.mp3", "b.mp3", "c.mp3"])
    }

    func test_tracks_emptyWhenDirectoryMissing() {
        let nonexistent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertEqual(BundledLibrary.tracks(resourceURL: nonexistent), [])
    }

    func test_folderID_isStableAcrossCalls() {
        XCTAssertEqual(BundledLibrary.folderID, BundledLibrary.folderID)
    }

    func test_folderName_isExpected() {
        XCTAssertEqual(BundledLibrary.folderName, "Sample Library")
    }
}
