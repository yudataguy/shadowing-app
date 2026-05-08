import Foundation

enum BundledLibrary {
    /// Fixed UUID so the synthetic folder always has the same ID across launches.
    /// Stable IDs for resume positions remain consistent.
    static let folderID = UUID(uuidString: "00000000-0000-0000-0000-53414d504c45")!

    static let folderName = "Sample Library"

    /// Returns Track records for every MP3 inside the SampleAudio resource directory.
    /// `resourceURL` defaults to the main app bundle's Resources; tests can pass a
    /// fixture directory containing MP3s to exercise the same scanning logic.
    static func tracks(resourceURL: URL? = Bundle.main.resourceURL) -> [Track] {
        guard let resourceURL else { return [] }
        let sampleDir = resourceURL.appendingPathComponent("SampleAudio")
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: sampleDir,
                                                          includingPropertiesForKeys: nil)
        else { return [] }

        return contents
            .filter { $0.pathExtension.lowercased() == "mp3" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { url in
                Track(
                    folderID: folderID,
                    relativePath: url.lastPathComponent,
                    url: url
                )
            }
    }
}
