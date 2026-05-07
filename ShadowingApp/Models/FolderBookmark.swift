import Foundation

struct FolderBookmark: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var bookmarkData: Data
}
