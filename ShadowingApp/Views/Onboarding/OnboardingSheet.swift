import SwiftUI

struct OnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(
                    colors: [Color(red: 0.39, green: 0.40, blue: 0.95),
                             Color(red: 0.02, green: 0.71, blue: 0.83)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            VStack(spacing: 8) {
                Text("Welcome to Shadowing")
                    .font(.largeTitle.weight(.semibold))
                Text("Practice languages by listening and repeating.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 20) {
                bullet(icon: "ear", text: "Listen to native audio at adjustable speeds")
                bullet(icon: "folder.badge.plus", text: "Add your own MP3 folders from iCloud Drive")
                bullet(icon: "rectangle.stack", text: "Save tracks to playlists for daily practice")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                onContinue()
                dismiss()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    private func bullet(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            Text(text)
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}
