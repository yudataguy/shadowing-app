import Foundation

enum LibraryService {
    static func scan(rootURL: URL, folderID: UUID) -> [Track] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []  // include hidden files so iCloud placeholders are visible
        ) else { return [] }

        var results: [Track] = []
        let rootPath = rootURL.standardizedFileURL.path

        for case let url as URL in enumerator {
            let name = url.lastPathComponent

            // iCloud Drive placeholder: hidden dotfile ending in .icloud
            // Real form: .track.mp3.icloud  →  track.mp3
            if name.hasPrefix(".") && name.hasSuffix(".icloud") {
                let withoutLeadingDot = String(name.dropFirst())
                let withoutICloudSuffix = String(withoutLeadingDot.dropLast(".icloud".count))
                guard withoutICloudSuffix.lowercased().hasSuffix(".mp3") else { continue }

                let realURL = url.deletingLastPathComponent().appendingPathComponent(withoutICloudSuffix)
                // Kick off a background download. Idempotent; safe to call repeatedly.
                try? fm.startDownloadingUbiquitousItem(at: realURL)

                let absolute = realURL.standardizedFileURL.path
                guard absolute.hasPrefix(rootPath + "/") else { continue }
                let relative = String(absolute.dropFirst(rootPath.count + 1))
                results.append(Track(folderID: folderID, relativePath: relative, url: realURL))
                continue
            }

            // Skip other hidden files (e.g., .DS_Store)
            if name.hasPrefix(".") { continue }

            // Regular .mp3 file
            guard url.pathExtension.lowercased() == "mp3",
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            else { continue }

            let absolute = url.standardizedFileURL.path
            guard absolute.hasPrefix(rootPath + "/") else { continue }
            let relative = String(absolute.dropFirst(rootPath.count + 1))
            results.append(Track(folderID: folderID, relativePath: relative, url: url))
        }
        return results
    }
}
