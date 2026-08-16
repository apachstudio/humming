import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let copy = Titles.greeting()

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(copy.kicker)\n\(copy.line)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Hum a melody and get the chords instantly")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)

            Spacer()

            HStack {
                Spacer()
                HumButton(action: model.startRecording)
                Spacer()
            }

            Button("or try a sample melody", action: model.runSample)
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)

            Spacer()

            HStack {
                Text("Humming Beta v1.0")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                NavigationLink(value: Route.library) {
                    Label("Library", systemImage: "waveform")
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(AppModel())
    .preferredColorScheme(.dark)
}
