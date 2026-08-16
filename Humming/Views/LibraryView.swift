import SwiftUI

/// The hum library: view saved hums, open their chords, delete them.
/// Styled after the light "Chords Ready" theme.
struct LibraryView: View {
    @EnvironmentObject private var store: HumStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedHum: Hum?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 24)
                        .frame(height: 56)

                    title
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    if store.hums.isEmpty {
                        emptyState
                    } else {
                        humList
                    }
                }
            }
            .navigationDestination(item: $selectedHum) { hum in
                ResultsView(
                    hum: hum,
                    audioURL: store.audioURL(for: hum),
                    mode: .saved(
                        onDelete: {
                            store.delete(hum)
                            selectedHum = nil
                        },
                        onBack: { selectedHum = nil }
                    )
                )
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .preferredColorScheme(.light)
    }

    private var header: some View {
        HStack {
            Button {
                Haptics.light()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(HumTheme.ink)
                    .frame(width: 44, height: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")

            Spacer()

            Text("LIBRARY")
                .font(.system(size: 14))
                .kerning(0.55)
                .foregroundStyle(HumTheme.grayText)
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your hums,")
                .foregroundStyle(HumTheme.greetingGray)
            Text("ready to play")
                .foregroundStyle(HumTheme.ink)
        }
        .font(.system(size: 26, weight: .medium))
        .kerning(-0.3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var humList: some View {
        List {
            ForEach(store.hums) { hum in
                Button {
                    Haptics.selection()
                    selectedHum = hum
                } label: {
                    HumRow(hum: hum)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 24, bottom: 6, trailing: 24))
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Haptics.warning()
                        store.delete(hum)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            WaveGlyphView(color: HumTheme.dimmed)
                .frame(width: 96, height: 44)
            Text("Nothing here yet.\nHum something!")
                .font(.system(size: 16))
                .foregroundStyle(HumTheme.grayText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

/// A single saved hum row: avatar, name, meta and chord chips.
struct HumRow: View {
    let hum: Hum

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(HumTheme.avatarGradient)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(hum.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(HumTheme.ink)
                    .lineLimit(1)

                Text(chordSummary)
                    .font(.system(size: 13))
                    .foregroundStyle(HumTheme.grayText)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HumTheme.dimmed)
        }
        .padding(16)
        .background(HumTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }

    private var chordSummary: String {
        let chords = hum.chords.prefix(4).joined(separator: " · ")
        return "\(hum.subtitle)  ·  \(chords)"
    }
}

#Preview {
    LibraryView()
        .environmentObject(HumStore())
}
