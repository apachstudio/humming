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

    @EnvironmentObject private var store: HumStore
    @StateObject private var player = PlayerModel()
    @StateObject private var chordPlayer = ChordPreviewPlayer()
    @State private var name: String
    @State private var selectedReaction: String?
    @State private var midiURL: URL?
    @State private var isTextVisible = false
    @State private var isLeaving = false
    @State private var isReactionStripVisible = false
    @State private var isReactionPickerPresented = false
    @State private var scrollContentOffset: CGFloat = 0

    private let contentInset: CGFloat = 24
    private static let fallbackReactions = ["❤️", "🔥", "✨", "😭", "😍", "🫶", "🎵", "💡", "🚀", "🌙", "👏", "😌"]

    init(hum: Hum, audioURL: URL, mode: Mode) {
        self.hum = hum
        self.audioURL = audioURL
        self.mode = mode
        _name = State(initialValue: hum.name)
        _selectedReaction = State(initialValue: hum.emojiReaction)
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
                Group {
                    HumTheme.charcoal.ignoresSafeArea()
                    resultsGlow

                    VStack(spacing: 0) {
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 24) {
                                title
                                    .premiumTextReveal(isTextVisible, yOffset: 16, blur: 8)
                                metaRow
                                    .premiumTextReveal(isTextVisible, yOffset: 16, blur: 9)
                                chordSection
                                    .premiumTextReveal(isTextVisible, yOffset: 20, blur: 10)
                                playbackCard
                                    .premiumTextReveal(isTextVisible, yOffset: 22, blur: 10)
                                actions
                                    .premiumTextReveal(isTextVisible, yOffset: 22, blur: 10)
                            }
                            .frame(width: contentWidth, alignment: .leading)
                            .padding(.top, 94)
                            .padding(.bottom, 40)
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
                        .frame(width: contentWidth, height: 80)
                        .offset(x: contentX)
                }
                .blur(radius: isReactionPickerPresented ? 8 : 0)
                .animation(.easeInOut(duration: 0.22), value: isReactionPickerPresented)

                if isReactionPickerPresented {
                    reactionPickerOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .zIndex(3)
                }
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
        hum.emojiReaction = selectedReaction
        return hum
    }

    private var topReactions: [String] {
        let ranked = Dictionary(grouping: store.hums.compactMap(\.emojiReaction), by: { $0 })
            .map { reaction, uses in (reaction: reaction, count: uses.count) }
            .sorted {
                if $0.count == $1.count { return $0.reaction < $1.reaction }
                return $0.count > $1.count
            }
            .map { $0.reaction }

        return Array((ranked + Self.fallbackReactions).uniqued().prefix(4))
    }

    private var recordedDateLabel: String {
        "Recorded \(hum.createdAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private var recordedHeadlineLabel: String {
        if Calendar.current.isDateInToday(hum.createdAt) {
            return "Recorded Today"
        }
        return "Recorded \(hum.createdAt.formatted(date: .abbreviated, time: .omitted))"
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

            Spacer()

            reactionButton
        }
        .overlay(alignment: .topTrailing) {
            if isReactionStripVisible {
                quickReactionStrip
                    .padding(.top, 54)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .zIndex(2)
            }
        }
    }

   
    
    // MARK: - Hum info

    private var title: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(currentHum.name)
                .foregroundStyle(HumTheme.greetingGray)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(recordedHeadlineLabel)
                .foregroundStyle(Color.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.system(size: 32, weight: .regular))
        .kerning(-0.5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

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
        .frame(maxWidth: .infinity, alignment: .leading)
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
        case .fresh(_, _, let onClose):
            VStack(spacing: 14) {
                exportButton
                deleteHumButton(action: onClose)
            }
        case .saved(let onDelete, _):
            VStack(spacing: 14) {
                exportButton
                deleteHumButton(action: onDelete)
            }
        }
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

    private var reactionButton: some View {
        Button {
            Haptics.light()
            presentReactionPicker()
        } label: {
            reactionIconLabel
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                Haptics.selection()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    isReactionStripVisible.toggle()
                }
            }
        )
    }

    private var reactionIconLabel: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.3))
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))

            if let selectedReaction {
                Text(selectedReaction)
                    .font(.system(size: 18))
            } else {
                Image(systemName: "face.smiling")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.86))
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .accessibilityLabel(selectedReaction == nil ? "Add reaction" : "Change reaction")
    }

    private var quickReactionStrip: some View {
        HStack(spacing: 8) {
            ForEach(topReactions, id: \.self) { reaction in
                Button {
                    selectReaction(reaction)
                } label: {
                    Text(reaction)
                        .font(.system(size: 20))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(reaction == selectedReaction ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("React with \(reaction)")
            }

            Button {
                presentReactionPicker()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.86))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More reactions")
        }
        .padding(8)
        .background(Color.black.opacity(0.3), in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.24), radius: 18, y: 10)
    }

    private var reactionPickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.38)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissReactionPicker()
                }

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Reaction")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))

                    Spacer()

                    Button {
                        dismissReactionPicker()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.78))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close reactions")
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(Self.fallbackReactions, id: \.self) { reaction in
                        Button {
                            selectReaction(reaction)
                        } label: {
                            Text(reaction)
                                .font(.system(size: 28))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(reaction == selectedReaction ? Color.white.opacity(0.16) : Color.white.opacity(0.07))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Color.white.opacity(reaction == selectedReaction ? 0.18 : 0.08), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("React with \(reaction)")
                    }
                }

                if selectedReaction != nil {
                    Button("Remove reaction") {
                        selectReaction(nil)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
            .frame(maxWidth: 320)
            .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 28, y: 18)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var exportButton: some View {
        if let midiURL {
            ShareLink(item: midiURL) {
                downloadMIDILabel
            }
            .buttonStyle(DownloadMIDIButtonStyle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    Haptics.light()
                }
            )
        } else {
            Button {} label: {
                downloadMIDILabel
            }
            .buttonStyle(DownloadMIDIButtonStyle())
            .disabled(true)
        }
    }

    private var downloadMIDILabel: some View {
        Text("Download MIDI file")
            .font(.system(size: 16, weight: .medium))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .contentShape(Capsule())
            .accessibilityLabel("Download MIDI file")
    }

    private func deleteHumButton(action: @escaping () -> Void) -> some View {
        Button(role: .destructive) {
            Haptics.warning()
            leaveResults(action)
        } label: {
            Text("Delete hum")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.42))
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func presentReactionPicker() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            isReactionStripVisible = false
            isReactionPickerPresented = true
        }
    }

    private func dismissReactionPicker() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isReactionPickerPresented = false
        }
    }

    private func selectReaction(_ reaction: String?) {
        selectedReaction = reaction
        if case .saved = mode {
            store.setReaction(reaction, for: hum)
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            isReactionStripVisible = false
            isReactionPickerPresented = false
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

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
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

struct DownloadMIDIButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white.opacity(isEnabled ? 0.9 : 0.32))
            .background(Color.black.opacity(configuration.isPressed ? 0.38 : 0.3), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.76), value: configuration.isPressed)
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
    .environmentObject(HumStore())
}
