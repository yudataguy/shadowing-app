import Foundation

final class BookmarkStore {
    private let defaults: UserDefaults
    private let key = "folderBookmarks.v1"

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
