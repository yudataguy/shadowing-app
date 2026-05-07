import SwiftUI

struct FolderSectionHeader: View {
    let folderName: String
    let onPlay: () -> Void
    let onShuffle: () -> Void

    var body: some View {
        HStack {
            Text(folderName)
                .font(.headline)
                .textCase(nil)
            Spacer()
            Button(action: onPlay) {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.borderless)
            Button(action: onShuffle) {
                Image(systemName: "shuffle")
            }
            .buttonStyle(.borderless)
        }
    }
}
