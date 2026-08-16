import SwiftUI

struct RecordingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Button(action: model.stopRecording) {
                VStack(spacing: 24) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                            .shadow(color: .red, radius: 6)
                        Text("Tap and start humming")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)

                    Text(Titles.timer(model.elapsed))
                        .font(.system(size: 72, weight: .semibold, design: .rounded))
                        .monospacedDigit()

                    LiveWaveform(levels: model.levels)

                    Spacer()

                    Text("Tap to stop")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
            }
            .buttonStyle(.plain)
            .navigationTitle("Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stop", action: model.stopRecording)
                }
            }
            .background(Color(.systemBackground))
        }
    }
}
