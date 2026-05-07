import XCTest
@testable import ShadowingApp

final class BookmarkStoreTests: XCTestCase {
    var defaults: UserDefaults!
    var store: BookmarkStore!

    override func setUp() {
        defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        store = BookmarkStore(defaults: defaults)
    }

    func test_emptyByDefault() {
        XCTAssertEqual(store.all().count, 0)
    }

    func test_addAndRetrieve() {
        let bookmark = FolderBookmark(id: UUID(), displayName: "Lessons", bookmarkData: Data([1, 2, 3]))
        store.add(bookmark)
        XCTAssertEqual(store.all(), [bookmark])
    }

    func test_remove() {
        let a = FolderBookmark(id: UUID(), displayName: "A", bookmarkData: Data([1]))
        let b = FolderBookmark(id: UUID(), displayName: "B", bookmarkData: Data([2]))
        store.add(a); store.add(b)
        store.remove(id: a.id)
        XCTAssertEqual(store.all(), [b])
    }
}
