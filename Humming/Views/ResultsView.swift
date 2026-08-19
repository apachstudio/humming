import SwiftUI
import UIKit

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
    @State private var isReactionMenuExpanded = false
    @State private var highlightedReaction: String?
    @State private var reactionOptionFrames: [String: CGRect] = [:]
    @State private var scrollContentOffset: CGFloat = 0
    @State private var resultsScrollView: UIScrollView?
    @State private var isAutoScrolling = false
    @State private var selectedAutoScrollSpeed: Double = 1
    @State private var highlightedAutoScrollSpeed: Double?
    @State private var isAutoScrollSpeedMenuVisible = false
    @State private var autoScrollSpeedFrames: [Double: CGRect] = [:]
    @State private var autoScrollCompletionTask: Task<Void, Never>?

    private let contentInset: CGFloat = 24
    private let autoScrollBottomID = "resultsAutoScrollBottom"
    private let autoScrollSpeeds: [Double] = [1, 1.5, 2, 2.5]
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
                            VStack(alignment: .leading, spacing: 32) {
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
                                Color.clear
                                    .frame(height: 1)
                                    .id(autoScrollBottomID)
                            }
                            .frame(width: contentWidth, alignment: .leading)
                            .padding(.top, 110)
                            .padding(.bottom, 32)
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
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 1).onChanged { _ in
                                if isAutoScrolling {
                                    stopAutoScroll()
                                }
                            }
                        )
                        .onPreferenceChange(ResultsScrollOffsetPreferenceKey.self) { value in
                            scrollContentOffset = value
                        }
                        .background(ScrollViewAccessor { scrollView in
                            resultsScrollView = scrollView
                        })
                        .clipped()
                    }
                    .frame(width: contentWidth, height: proxy.size.height)
                    .offset(x: contentX)

                    header
                        .frame(width: contentWidth, height: 80)
                        .offset(x: contentX)
                }
                .blur(radius: isReactionStripVisible ? 8 : 0)
                .animation(.easeInOut(duration: 0.22), value: isReactionStripVisible)

                if isReactionStripVisible {
                    reactionDimmingLayer
                        .transition(.opacity)
                        .zIndex(1)

                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 8) {
                                quickReactionStrip
                                    .frame(width: isReactionMenuExpanded ? min(contentWidth - 52, 420) : 272, alignment: .trailing)

                                Button {
                                    dismissReactionMenu()
                                } label: {
                                    reactionIconLabel
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 18)
                        .padding(.trailing, proxy.safeAreaInsets.trailing + contentInset)

                        Spacer()
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .zIndex(2)
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
            autoScrollCompletionTask?.cancel()
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

        return Array((ranked + Self.fallbackReactions).uniqued().prefix(5))
    }

    private var reactionOptions: [String] {
        isReactionMenuExpanded ? (topReactions + Self.fallbackReactions).uniqued() : topReactions
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

            if isAutoScrollSpeedMenuVisible {
                autoScrollSpeedMenu
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            autoScrollButton
            reactionButton
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isAutoScrollSpeedMenuVisible)
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

    private var autoScrollButton: some View {
        let speedSelectionGesture = LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                switch value {
                case .first(true):
                    presentAutoScrollSpeedMenu()
                case .second(true, let drag?):
                    presentAutoScrollSpeedMenu()
                    updateAutoScrollSpeedHighlight(at: drag.location)
                default:
                    break
                }
            }
            .onEnded { value in
                switch value {
                case .second(true, let drag?):
                    updateAutoScrollSpeedHighlight(at: drag.location)
                default:
                    break
                }
                applyAutoScrollSpeedSelection()
            }

        return autoScrollIconLabel
            .onTapGesture {
                Haptics.light()
                if isAutoScrolling {
                    stopAutoScroll()
                } else {
                    startAutoScroll(speed: selectedAutoScrollSpeed)
                }
            }
            .gesture(speedSelectionGesture)
    }

    private var autoScrollIconLabel: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.3))
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))

            if isAutoScrolling {
                Text(autoScrollSpeedLabel(selectedAutoScrollSpeed))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .lineLimit(1)
            } else {
                Image(systemName: "arrow.down")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.86))
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .accessibilityLabel(isAutoScrolling ? "Stop auto scroll" : "Auto scroll")
    }

    private var autoScrollSpeedMenu: some View {
        HStack(spacing: 6) {
            ForEach(autoScrollSpeeds, id: \.self) { speed in
                autoScrollSpeedOption(speed)
            }
        }
        .padding(7)
        .background(Color.black.opacity(0.3), in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.24), radius: 18, y: 10)
        .onPreferenceChange(AutoScrollSpeedFramePreferenceKey.self) { frames in
            autoScrollSpeedFrames = frames
        }
    }

    private func autoScrollSpeedOption(_ speed: Double) -> some View {
        let activeSpeed = highlightedAutoScrollSpeed ?? selectedAutoScrollSpeed
        let isActive = activeSpeed == speed
        let fontSize: CGFloat = isActive ? 14 : 12
        let foregroundOpacity: Double = isActive ? 0.95 : 0.66
        let fillOpacity: Double = isActive ? 0.18 : 0.08
        let width: CGFloat = isActive ? 45 : 39
        let height: CGFloat = isActive ? 34 : 30
        let scale: CGFloat = isActive ? 1.06 : 1

        return Text(autoScrollSpeedLabel(speed))
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(Color.white.opacity(foregroundOpacity))
            .frame(width: width, height: height)
            .background(Capsule().fill(Color.white.opacity(fillOpacity)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(fillOpacity), lineWidth: 1))
            .background(autoScrollSpeedFrameReader(for: speed))
            .scaleEffect(scale)
            .animation(.spring(response: 0.2, dampingFraction: 0.78), value: isActive)
    }

    private func autoScrollSpeedFrameReader(for speed: Double) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: AutoScrollSpeedFramePreferenceKey.self,
                value: [speed: proxy.frame(in: .global)]
            )
        }
    }

    private func presentAutoScrollSpeedMenu() {
        guard !isAutoScrollSpeedMenuVisible else { return }
        highlightedAutoScrollSpeed = selectedAutoScrollSpeed
        Haptics.selection()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            isAutoScrollSpeedMenuVisible = true
        }
    }

    private func updateAutoScrollSpeedHighlight(at location: CGPoint) {
        guard let speed = autoScrollSpeedFrames.first(where: { _, frame in
            frame.insetBy(dx: -8, dy: -12).contains(location)
        })?.key else { return }

        if highlightedAutoScrollSpeed != speed {
            highlightedAutoScrollSpeed = speed
            Haptics.selection()
        }
    }

    private func applyAutoScrollSpeedSelection() {
        let speed = highlightedAutoScrollSpeed ?? selectedAutoScrollSpeed
        selectedAutoScrollSpeed = speed
        highlightedAutoScrollSpeed = nil
        withAnimation(.easeInOut(duration: 0.16)) {
            isAutoScrollSpeedMenuVisible = false
        }
        Haptics.light()
        startAutoScroll(speed: speed)
    }

    private func startAutoScroll(speed: Double) {
        guard let scrollView = resultsScrollView else { return }
        let duration = autoScrollDuration(for: speed)
        autoScrollCompletionTask?.cancel()
        isAutoScrolling = true
        isAutoScrollSpeedMenuVisible = false
        scrollView.layer.removeAllAnimations()

        let maxOffsetY = max(
            -scrollView.adjustedContentInset.top,
            scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveLinear, .allowUserInteraction]
        ) {
            scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: maxOffsetY)
        }

        autoScrollCompletionTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                isAutoScrolling = false
                autoScrollCompletionTask = nil
            }
        }
    }

    private func stopAutoScroll() {
        guard let scrollView = resultsScrollView else {
            isAutoScrolling = false
            return
        }
        autoScrollCompletionTask?.cancel()
        autoScrollCompletionTask = nil
        scrollView.layer.removeAllAnimations()
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)
        isAutoScrolling = false
        isAutoScrollSpeedMenuVisible = false
    }

    private func autoScrollDuration(for speed: Double) -> Double {
        max(2.4, 10 / speed)
    }

    private func autoScrollSpeedLabel(_ speed: Double) -> String {
        speed == floor(speed) ? "\(Int(speed))x" : "\(speed)x"
    }

    private var reactionButton: some View {
        let reactionSelectionGesture = LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                switch value {
                case .first(true):
                    presentReactionMenu()
                case .second(true, let drag?):
                    presentReactionMenu()
                    updateReactionHighlight(at: drag.location)
                default:
                    break
                }
            }
            .onEnded { value in
                switch value {
                case .second(true, let drag?):
                    updateReactionHighlight(at: drag.location)
                default:
                    break
                }
                applyReactionSelection()
            }

        return reactionIconLabel
            .onTapGesture {
                Haptics.light()
                presentReactionMenu()
            }
            .gesture(reactionSelectionGesture)
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(reactionOptions, id: \.self) { reaction in
                    reactionOption(reaction)
                }

                if !isReactionMenuExpanded {
                    Button {
                        Haptics.light()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            isReactionMenuExpanded = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.86))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More reactions")
                } else if selectedReaction != nil {
                    Button {
                        selectReaction(nil)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove reaction")
                }
            }
            .padding(8)
        }
        .background(Color.black.opacity(0.3), in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.24), radius: 18, y: 10)
        .onPreferenceChange(ReactionOptionFramePreferenceKey.self) { frames in
            reactionOptionFrames = frames
        }
    }

    private func reactionOption(_ reaction: String) -> some View {
        let isHovered = highlightedReaction == reaction
        let isSelected = selectedReaction == reaction
        let fontSize: CGFloat = isHovered ? 28 : 20
        let frameSize: CGFloat = isHovered ? 44 : 36
        let fillOpacity: Double = isHovered ? 0.22 : (isSelected ? 0.16 : 0.07)
        let strokeOpacity: Double = isHovered ? 0.22 : 0.08

        return Button {
            selectReaction(reaction == selectedReaction ? nil : reaction)
        } label: {
            Text(reaction)
                .font(.system(size: fontSize))
                .frame(width: frameSize, height: frameSize)
                .background(Circle().fill(Color.white.opacity(fillOpacity)))
                .overlay(Circle().strokeBorder(Color.white.opacity(strokeOpacity), lineWidth: 1))
                .shadow(color: .white.opacity(isHovered ? 0.12 : 0), radius: 10, y: 3)
                .background(reactionOptionFrameReader(for: reaction))
                .scaleEffect(isHovered ? 1.05 : 1)
                .animation(.spring(response: 0.2, dampingFraction: 0.76), value: isHovered)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("React with \(reaction)")
    }

    private func reactionOptionFrameReader(for reaction: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: ReactionOptionFramePreferenceKey.self,
                value: [reaction: proxy.frame(in: .global)]
            )
        }
    }

    private var reactionDimmingLayer: some View {
        Color.black.opacity(0.28)
            .background(.ultraThinMaterial)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: dismissReactionMenu)
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

    private func presentReactionMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            isReactionStripVisible = true
            isReactionMenuExpanded = false
            highlightedReaction = selectedReaction
        }
    }

    private func dismissReactionMenu() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isReactionStripVisible = false
            isReactionMenuExpanded = false
            highlightedReaction = nil
        }
    }

    private func selectReaction(_ reaction: String?) {
        selectedReaction = reaction
        if case .saved = mode {
            store.setReaction(reaction, for: hum)
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            isReactionStripVisible = false
            isReactionMenuExpanded = false
            highlightedReaction = nil
        }
    }

    private func updateReactionHighlight(at location: CGPoint) {
        guard let reaction = reactionOptionFrames.first(where: { _, frame in
            frame.insetBy(dx: -10, dy: -14).contains(location)
        })?.key else { return }

        if highlightedReaction != reaction {
            highlightedReaction = reaction
            Haptics.selection()
        }
    }

    private func applyReactionSelection() {
        guard let reaction = highlightedReaction else {
            dismissReactionMenu()
            return
        }

        Haptics.light()
        selectReaction(reaction == selectedReaction ? nil : reaction)
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

private struct AutoScrollSpeedFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Double: CGRect] = [:]

    static func reduce(value: inout [Double: CGRect], nextValue: () -> [Double: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct ReactionOptionFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct ScrollViewAccessor: UIViewRepresentable {
    let onResolve: (UIScrollView) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        resolve(from: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        resolve(from: uiView)
    }

    private func resolve(from view: UIView) {
        DispatchQueue.main.async {
            if let scrollView = view.enclosingScrollView {
                onResolve(scrollView)
            }
        }
    }
}

private extension UIView {
    var enclosingScrollView: UIScrollView? {
        var candidate = superview
        while let view = candidate {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            candidate = view.superview
        }
        return nil
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
