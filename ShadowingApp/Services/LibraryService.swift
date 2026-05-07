import Foundation

enum LibraryService {
    static func scan(rootURL: URL, folderID: UUID) -> [Track] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [Track] = []
        let rootPath = rootURL.standardizedFileURL.path
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "mp3",
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            let absolute = url.standardizedFileURL.path
            guard absolute.hasPrefix(rootPath + "/") else { continue }
            let relative = String(absolute.dropFirst(rootPath.count + 1))
            results.append(Track(folderID: folderID, relativePath: relative, url: url))
        }
        return results
    }
}
