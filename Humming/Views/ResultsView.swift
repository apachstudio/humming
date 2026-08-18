import SwiftUI

/// Dark results screen: analyzed hum name, detected meta, chord grid, playback and actions.
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
    @StateObject private var chordPlayer = ChordPreviewPlayer()
    @State private var name: String
    @State private var midiURL: URL?
    @State private var isTextVisible = false
    @State private var isLeaving = false
    @State private var scrollContentOffset: CGFloat = 0

    private let contentInset: CGFloat = 24

    init(hum: Hum, audioURL: URL, mode: Mode) {
        self.hum = hum
        self.audioURL = audioURL
        self.mode = mode
        _name = State(initialValue: hum.name)
    }

    var body: some View {
        GeometryReader { proxy in
            let contentX = proxy.safeAreaInsets.leading + contentInset
            let contentWidth = max(
                0,
                proxy.size.width
                - proxy.safeAreaInsets.leading
                - proxy.safeAreaInsets.trailing
                - contentInset * 2
            )

            ZStack(alignment: .topLeading) {
                HumTheme.charcoal.ignoresSafeArea()
                resultsGlow

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            metaRow
                                .premiumTextReveal(isTextVisible, yOffset: 16, blur: 9)
                            chordSection
                                .padding(.top, 24)
                                .premiumTextReveal(isTextVisible, yOffset: 20, blur: 10)
                            playbackCard
                                .padding(.top, 24)
                                .premiumTextReveal(isTextVisible, yOffset: 22, blur: 10)
                        }
                        .frame(width: contentWidth, alignment: .leading)
                        .padding(.top, 72)
                        .padding(.bottom, 128)
                        .background(
                            GeometryReader { scrollProxy in
                                Color.clear.preference(
                                    key: ResultsScrollOffsetPreferenceKey.self,
                                    value: scrollProxy.frame(in: .named("resultsScroll")).minY
                                )
                            }
                        )
                        .clipped()
                        .frame(maxWidth: .infinity)
                    }
                    .coordinateSpace(name: "resultsScroll")
                    .onPreferenceChange(ResultsScrollOffsetPreferenceKey.self) { value in
                        scrollContentOffset = value
                    }
                    .clipped()
                }
                .frame(width: contentWidth, height: proxy.size.height)
                .offset(x: contentX)

                header
                    .frame(width: contentWidth, height: 52)
                    .offset(x: contentX)

                VStack {
                    Spacer()
                    actions
                        .frame(width: min(contentWidth, 220))
                        .premiumTextReveal(isTextVisible, yOffset: 18, blur: 8)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12))
                }
                .frame(width: contentWidth, height: proxy.size.height)
                .offset(x: contentX)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            runTextEntrance()
            player.load(url: audioURL)
            midiURL = try? MIDIExporter.export(hum: currentHum)
        }
        .onDisappear {
            player.stop()
            chordPlayer.stop()
        }
    }

    private var currentHum: Hum {
        var hum = hum
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { hum.name = trimmed }
        return hum
    }

    private var compactTitle: String {
        currentHum.name
    }

    private var compactTitleProgress: Double {
        min(max(Double((-scrollContentOffset - 28) / 44), 0), 1)
    }

    private var recordedDateLabel: String {
        "Recorded \(hum.createdAt.formatted(date: .abbreviated, time: .shortened))"
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.light()
                switch mode {
                case .fresh(_, _, let onClose): leaveResults(onClose)
                case .saved(_, let onBack): leaveResults(onBack)
                }
            } label: {
                darkMaterialIcon(systemName: "chevron.left", accessibilityLabel: "Back")
            }
            .buttonStyle(.plain)

            Text(compactTitle)
                .font(.system(size: 24, weight: .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)

            Color.clear
                .frame(width: 44, height: 44)
        }
    }

   
    
    // MARK: - Hum info

    private var humInfo: some View {
        VStack(alignment: .center, spacing: 0) {
            if case .fresh = mode {
                TextField("Name your hum", text: $name)
                    .font(.system(size: 32, weight: .regular))
                    .kerning(-0.48)
                    .foregroundStyle(Color.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .submitLabel(.done)
                    .onSubmit {
                        midiURL = try? MIDIExporter.export(hum: currentHum)
                    }
            } else {
                Text(hum.name)
                    .font(.system(size: 32, weight: .regular))
                    .kerning(-0.48)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var metaRow: some View {
        HStack(spacing: 8) {
            MetaChip(label: "KEY", value: hum.key)
            MetaChip(label: "BPM", value: "~\(hum.bpm)")
            MetaChip(label: "TIME", value: hum.timeSignature)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

   

    // MARK: - Chords

    private var chordSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
                spacing: 12            ) {
                ForEach(Array(hum.chords.enumerated()), id: \.offset) { _, chord in
                    ChordCard(symbol: chord) {
                        Haptics.selection()
                        chordPlayer.play(chord: chord)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Playback

    private var playbackCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Button {
                    Haptics.selection()
                    player.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(player.isPlaying ? 0.28 : 0.18))
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                            .frame(width: 42, height: 42)
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .offset(x: player.isPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

                VStack(alignment: .leading, spacing: 4) {
                    Text(recordedDateLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .lineLimit(1)

                    Text("\(player.currentTime.clockString) / \(max(player.duration, hum.duration).clockString)")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.opacity(0.34))
                }

                Spacer()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(Color.white.opacity(0.86))
                        .frame(width: max(0, proxy.size.width * player.progress))
                }
            }
            .frame(height: 5)
        }
        .padding(18)
        .resultCardChrome(isPressed: false)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        switch mode {
        case .fresh(let onSave, _, _):
            actionBar {
                exportButton
                micPlaybackButton

                Button {
                    let humToSave = currentHum
                    Haptics.success()
                    leaveResults {
                        onSave(humToSave)
                    }
                } label: {
                    actionLabel(systemName: "checkmark", title: "Save")
                }
                .buttonStyle(ResultActionButtonStyle())
            }

        case .saved(let onDelete, _):
            actionBar {
                exportButton
                micPlaybackButton

                Button(role: .destructive) {
                    Haptics.warning()
                    leaveResults(onDelete)
                } label: {
                    actionLabel(systemName: "trash", title: "Delete Hum")
                }
                .buttonStyle(ResultActionButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func actionBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 6) {
            content()
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.3), in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var micPlaybackButton: some View {
        Button {
            Haptics.selection()
            player.toggle()
        } label: {
            Image(systemName: player.isPlaying ? "pause.fill" : "mic.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.white.opacity(player.isPlaying ? 0.9 : 0.82))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .accessibilityLabel(player.isPlaying ? "Pause hum" : "Play hum")
        }
        .buttonStyle(ResultActionButtonStyle())
    }

    private func darkMaterialIcon(systemName: String, accessibilityLabel: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.86))
            .frame(width: 44, height: 44)
            .background(Color.black.opacity(0.3), in: Circle())
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .contentShape(Circle())
            .accessibilityLabel(accessibilityLabel)
    }

    private func actionLabel(systemName: String, title: String) -> some View {
        Label(title, systemImage: systemName)
            .labelStyle(.iconOnly)
            .font(.system(size: 20, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .accessibilityLabel(title)
    }

    @ViewBuilder
    private var exportButton: some View {
        if let midiURL {
            ShareLink(item: midiURL) {
                actionLabel(systemName: "square.and.arrow.up", title: "Export MIDI")
            }
            .buttonStyle(ResultActionButtonStyle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    Haptics.light()
                }
            )
        } else {
            Button {} label: {
                actionLabel(systemName: "square.and.arrow.up", title: "Export MIDI")
            }
            .buttonStyle(ResultActionButtonStyle())
            .disabled(true)
        }
    }

    private var resultsGlow: some View {
        VStack {
            Spacer()
            Circle()
                .fill(Color.white.opacity(0.11))
                .frame(width: 460, height: 460)
                .blur(radius: 92)
                .offset(y: 170)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func runTextEntrance() {
        isLeaving = false
        isTextVisible = false
        withAnimation(HumMotion.textReveal) {
            isTextVisible = true
        }
    }

    private func leaveResults(_ completion: @escaping () -> Void) {
        guard !isLeaving else { return }
        isLeaving = true
        player.stop()
        chordPlayer.stop()
        withAnimation(HumMotion.textExit) {
            isTextVisible = false
        }
        Task {
            try? await Task.sleep(for: HumMotion.textExitDelay)
            await MainActor.run {
                completion()
            }
        }
    }
}

private struct ResultsScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Components

private extension View {
    func resultCardChrome(isPressed: Bool) -> some View {
        background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(isPressed ? 0.045 : 0.07))
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(isPressed ? 0.24 : 0))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(isPressed ? 0.08 : 0.09), lineWidth: 1)
        )
    }
}

struct ChordCard: View {
    let symbol: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(symbol)
                    .font(.system(size: 36, weight: .light))
                    .kerning(0.37)
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    ForEach(Array(["↓", "↑", "↓", "↑"].enumerated()), id: \.offset) { _, arrow in
                        Text(arrow)
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.36))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .frame(height: 112)
        }
        .buttonStyle(ChordCardButtonStyle())
    }
}

struct ChordCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .resultCardChrome(isPressed: configuration.isPressed)
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.28 : 0.08), radius: configuration.isPressed ? 14 : 4, y: configuration.isPressed ? 10 : 2)
            .animation(.spring(response: 0.24, dampingFraction: 0.74), value: configuration.isPressed)
    }
}

struct ResultActionButtonStyle: ButtonStyle {
    var isPrimary = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white.opacity(isEnabled ? 0.9 : 0.3))
            .background(
                Capsule()
                    .fill(Color.white.opacity(backgroundOpacity(isPressed: configuration.isPressed)))
            )
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.76), value: configuration.isPressed)
    }

    private func backgroundOpacity(isPressed: Bool) -> Double {
        if isPressed { return isPrimary ? 0.2 : 0.1 }
        return isPrimary ? 0.14 : 0
    }
}

struct OutlinePillButtonStyle: ButtonStyle {
    var textColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                Capsule()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0.06))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct FilledPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(HumTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.72 : 0.94)))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

private struct MetaChip: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.34))
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Color.white.opacity(0.005), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
    }
}

#Preview {
    ResultsView(
        hum: Hum(
            id: UUID(),
            name: "Hook Idea",
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
