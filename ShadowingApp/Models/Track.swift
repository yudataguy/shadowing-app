import Foundation

struct Track: Identifiable, Hashable {
    let folderID: UUID
    let relativePath: String
    let url: URL

    var id: String { stableID }
    var stableID: String { "\(folderID.uuidString):\(relativePath)" }
    var displayTitle: String {
        (relativePath as NSString).lastPathComponent
            .replacingOccurrences(of: ".mp3", with: "", options: [.caseInsensitive, .backwards])
    }
}
