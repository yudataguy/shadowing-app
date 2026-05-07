import SwiftUI

struct ScrubberView: View {
    let currentTime: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void

    @State private var isDragging = false
    @State private var dragValue: Double = 0

    private var displayValue: Double {
        isDragging ? dragValue : currentTime
    }

    var body: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { displayValue },
                    set: { dragValue = $0 }
                ),
                in: 0...max(duration, 0.001),
                onEditingChanged: { editing in
                    if editing {
                        isDragging = true
                        dragValue = currentTime
                    } else {
                        isDragging = false
                        onSeek(dragValue)
                    }
                }
            )
            HStack {
                Text(format(displayValue))
                Spacer()
                Text("-" + format(max(0, duration - displayValue)))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private func format(_ seconds: Double) -> String {
        let s = Int(max(0, seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
