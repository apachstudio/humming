import SwiftUI

/// "Chords Ready" screen (Figma 4:3). Light theme: hum header, key/BPM
/// meta, chord grid, playback card and actions.
struct ResultsView: View {
    enum Mode {
        case fresh(
            onSave: (Hum) -> Void,
            onRecordAgain: () -> Void,
            onClose: () -> Void
        )
        case saved(onDelete: () -> Void, onBack: () -> Void)
    }

    let hum: Hum
    let audioURL: URL
    let mode: Mode

    @StateObject private var player = PlayerModel()
    @State private var name: String
    @State private var midiURL: URL?

    init(hum: Hum, audioURL: URL, mode: Mode) {
        self.hum = hum
        self.audioURL = audioURL
        self.mode = mode
        _name = State(initialValue: hum.name)
    }

    private var headline: String {
        if case .saved = mode { return "Saved Hum" }
        return "Chords Ready"
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .frame(height: 56)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        humInfo
                        metaRow
                        chordSection
                            .padding(.top, 16)
                        playbackCard
                            .padding(.top, 16)
                        actions
                            .padding(.top, 4)
                            .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            player.load(url: audioURL)
            midiURL = try? MIDIExporter.export(hum: currentHum)
        }
        .onDisappear {
            player.stop()
        }
    }

    private var currentHum: Hum {
        var hum = hum
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { hum.name = trimmed }
        return hum
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                Haptics.light()
                switch mode {
                case .fresh(_, _, let onClose): onClose()
                case .saved(_, let onBack): onBack()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(HumTheme.ink)
                    .frame(width: 44, height: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")

            Spacer()

            Text(headline.uppercased())
                .font(.system(size: 14))
                .kerning(0.55)
                .foregroundStyle(HumTheme.grayText)
        }
    }

    // MARK: - Hum info

    private var humInfo: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(HumTheme.avatarGradient)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 0) {
                if case .fresh = mode {
                    TextField("Name your hum", text: $name)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(HumTheme.ink)
                        .submitLabel(.done)
                        .onSubmit {
                            midiURL = try? MIDIExporter.export(hum: currentHum)
                        }
                } else {
                    Text(hum.name)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(HumTheme.ink)
                }
                Text(hum.subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(HumTheme.grayText)
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 0) {
                Text("Key: ").foregroundStyle(HumTheme.grayText2)
                Text(hum.key).fontWeight(.medium).foregroundStyle(.black)
            }
            HStack(spacing: 0) {
                Text("BPM: ").foregroundStyle(HumTheme.grayText2)
                Text("~\(hum.bpm)").fontWeight(.medium).foregroundStyle(.black)
            }
            Text(hum.timeSignature)
                .fontWeight(.medium)
                .foregroundStyle(.black)
        }
        .font(.system(size: 14))
    }

    // MARK: - Chords

    private var chordSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("CHORDS")
                    .kerning(0.6)
                Spacer()
                Text("Set key")
            }
            .font(.system(size: 12))
            .foregroundStyle(HumTheme.grayText)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
                spacing: 12
            ) {
                ForEach(Array(hum.chords.enumerated()), id: \.offset) { _, chord in
                    ChordCard(symbol: chord)
                }
            }
        }
    }

    // MARK: - Playback

    private var playbackCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    Haptics.selection()
                    player.toggle()
                } label: {
                    ZStack {
                        Circle().fill(Color.black).frame(width: 32, height: 32)
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: player.isPlaying ? 0 : 1)
                    }
                }
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

                Text("\(player.currentTime.clockString) / \(max(player.duration, hum.duration).clockString)")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(HumTheme.grayText)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(HumTheme.hairline)
                    Capsule()
                        .fill(HumTheme.ink)
                        .frame(width: max(0, proxy.size.width * player.progress))
                }
            }
            .frame(height: 4)
        }
        .padding(16)
        .background(HumTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 12) {
            switch mode {
            case .fresh(let onSave, let onRecordAgain, _):
                Button("Record Again") {
                    Haptics.medium()
                    onRecordAgain()
                }
                    .buttonStyle(OutlinePillButtonStyle())

                exportButton

                Button {
                    onSave(currentHum)
                    Haptics.success()
                } label: {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledPillButtonStyle())

            case .saved(let onDelete, _):
                exportButton

                Button(role: .destructive) {
                    Haptics.warning()
                    onDelete()
                } label: {
                    Text("Delete Hum")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OutlinePillButtonStyle(textColor: HumTheme.ink))
            }
        }
    }

    @ViewBuilder
    private var exportButton: some View {
        if let midiURL {
            ShareLink(item: midiURL) {
                Text("Export MIDI")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OutlinePillButtonStyle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    Haptics.light()
                }
            )
        } else {
            Button("Export MIDI") {}
                .buttonStyle(OutlinePillButtonStyle())
                .disabled(true)
        }
    }
}

// MARK: - Components

/// One tile in the chord grid; minor chords carry the dark emphasis.
struct ChordCard: View {
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(symbol)
                .font(.system(size: 36, weight: .light))
                .kerning(0.37)
                .foregroundStyle(Hum.isMinorSymbol(symbol) ? HumTheme.ink : HumTheme.dimmed)

            HStack(spacing: 4) {
                ForEach(Array(["↓", "↑", "↓", "↑"].enumerated()), id: \.offset) { _, arrow in
                    Text(arrow)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(HumTheme.dimmed)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .frame(height: 112)
        .background(HumTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct OutlinePillButtonStyle: ButtonStyle {
    var textColor: Color = .black

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                Capsule()
                    .fill(Color.white)
                    .overlay(Capsule().strokeBorder(HumTheme.hairline, lineWidth: 1))
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct FilledPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Capsule().fill(Color.black))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

#Preview {
    ResultsView(
        hum: Hum(
            id: UUID(),
            name: "Ideia pro refrão",
            createdAt: .now,
            duration: 15,
            key: "Am",
            bpm: 96,
            timeSignature: "4/4",
            chords: ["Am", "F", "C", "G", "Em", "Dm"],
            notes: [],
            audioFileName: ""
        ),
        audioURL: URL(fileURLWithPath: "/dev/null"),
        mode: .fresh(onSave: { _ in }, onRecordAgain: {}, onClose: {})
    )
}
