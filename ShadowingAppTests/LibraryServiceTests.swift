import XCTest
@testable import ShadowingApp

final class LibraryServiceTests: XCTestCase {
    var tmp: URL!

    override func setUp() {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func touch(_ relativePath: String) {
        let full = tmp.appendingPathComponent(relativePath)
        try! FileManager.default.createDirectory(at: full.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: full.path, contents: Data())
    }

    func test_scan_findsTopLevelMP3s() {
        touch("a.mp3"); touch("b.mp3"); touch("notes.txt")
        let folderID = UUID()
        let tracks = LibraryService.scan(rootURL: tmp, folderID: folderID)
        XCTAssertEqual(tracks.map(\.relativePath).sorted(), ["a.mp3", "b.mp3"])
    }

    func test_scan_recurses() {
        touch("lessons/01.mp3"); touch("lessons/sub/02.mp3")
        let tracks = LibraryService.scan(rootURL: tmp, folderID: UUID())
        XCTAssertEqual(tracks.map(\.relativePath).sorted(), ["lessons/01.mp3", "lessons/sub/02.mp3"])
    }

    func test_scan_caseInsensitiveExtension() {
        touch("a.MP3"); touch("b.Mp3")
        let tracks = LibraryService.scan(rootURL: tmp, folderID: UUID())
        XCTAssertEqual(tracks.count, 2)
    }
}
