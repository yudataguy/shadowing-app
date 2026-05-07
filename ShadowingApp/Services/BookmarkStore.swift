import Foundation
import Observation

@Observable
final class BookmarkStore {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "folderBookmarks.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func all() -> [FolderBookmark] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([FolderBookmark].self, from: data)) ?? []
    }

    func add(_ bookmark: FolderBookmark) {
        var current = all()
        current.append(bookmark)
        save(current)
    }

    func remove(id: UUID) {
        save(all().filter { $0.id != id })
    }

    func update(_ bookmark: FolderBookmark) {
        save(all().map { $0.id == bookmark.id ? bookmark : $0 })
    }

    private func save(_ bookmarks: [FolderBookmark]) {
        let data = try? JSONEncoder().encode(bookmarks)
        defaults.set(data, forKey: key)
    }
}

extension BookmarkStore {
    func makeBookmark(from url: URL, displayName: String) throws -> FolderBookmark {
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        return FolderBookmark(id: UUID(), displayName: displayName, bookmarkData: data)
    }

    func resolve(_ bookmark: FolderBookmark) -> (url: URL, isStale: Bool)? {
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark.bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        return (url, stale)
    }
}
