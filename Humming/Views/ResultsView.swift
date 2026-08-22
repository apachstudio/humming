import SwiftUI
import UIKit

/// Dark results screen: analyzed hum name, detected meta, chord grid, playback and actions.
struct ResultsView: View {
    enum EntrySource {
        case library
        case processing
    }

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
    let entrySource: EntrySource

    @EnvironmentObject private var store: HumStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var player = PlayerModel()
    @StateObject private var chordPlayer = ChordPreviewPlayer()
    @State private var name: String
    @State private var selectedReaction: String?
    @State private var midiURL: URL?
    @State private var isHeadlineVisible = false
    @State private var isTextVisible = false
    @State private var isLeaving = false
    @State private var scrollContentOffset: CGFloat = 0
    @State private var resultsScrollView: UIScrollView?
    @State private var isAutoScrolling = false
    @State private var selectedSpeed: ScrollSpeed?
    @State private var activeRadialMenu: RadialMenu?
    @State private var expandedRadialMenu: RadialMenu?
    @State private var radialEntryFrames: [RadialMenu: CGRect] = [:]
    @State private var reactionBurst: ReactionBurst?
    @State private var autoScrollCompletionTask: Task<Void, Never>?
    @State private var showChordReveal: Bool
    @State private var showingDeleteConfirmation = false
    @State private var pendingDeleteAction: (() -> Void)?
    @Namespace private var radialGlassNamespace

    private let contentInset: CGFloat = 24
    private let autoScrollBottomID = "resultsAutoScrollBottom"
    // Previews snapshot the first frame, so time-based entrance reveals would leave the page blank there.
    private static let isRunningInPreviews = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    private static let addReactionOption = "+"
    private static let fallbackReactions = ["❤️", "🔥", "✨", "😭", "😍", "🫶", "🎵", "💡", "🚀", "🌙", "👏", "😌"]

    private enum RadialMenu: Hashable {
        case reaction
        case speed
    }

    private struct ReactionBurst: Identifiable {
        let id = UUID()
        let emoji: String
        let originOffset: CGSize
    }

    fileprivate enum ScrollSpeed: Double, CaseIterable, Hashable {
        case slow = 0.5
        case normal = 1
        case fast = 1.5

        var label: String {
            rawValue == floor(rawValue) ? "\(Int(rawValue))x" : "\(rawValue)x"
        }
    }

    init(hum: Hum, audioURL: URL, mode: Mode, entrySource: EntrySource = .library) {
        self.hum = hum
        self.audioURL = audioURL
        self.mode = mode
        self.entrySource = entrySource
        _name = State(initialValue: hum.name)
        _selectedReaction = State(initialValue: hum.emojiReaction)
        _showChordReveal = State(initialValue: false)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 42) {
                    title
                        .premiumTextReveal(isHeadlineVisible, yOffset: 16, blur: 8)
                        .opacity(1 - titleCollapseProgress)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: titleCollapseProgress)

                    metaRow
                        .premiumTextReveal(isTextVisible, yOffset: 16, blur: 9, delay: 0.1)
                }
                chordSection
                    .premiumTextReveal(isTextVisible, yOffset: 16, blur: 9, delay: 0.1)
                VStack(spacing: 24) {
                    playbackCard
                        .premiumTextReveal(isTextVisible, yOffset: 22, blur: 10, delay: 0.32)
                    actions
                        .premiumTextReveal(isTextVisible, yOffset: 22, blur: 10, delay: 0.44)
                }
                .padding(.top, 8)
                Color.clear
                    .frame(height: 1)
                    .id(autoScrollBottomID)
            }
            .padding(.horizontal, contentInset)
            .padding(.top, 32)
            .padding(.bottom, 32)
            .background(
                GeometryReader { scrollProxy in
                    Color.clear.preference(
                        key: ResultsScrollOffsetPreferenceKey.self,
                        value: scrollProxy.frame(in: .named("resultsScroll")).minY
                    )
                }
            )
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .background {
            ZStack {
                HumTheme.charcoal.ignoresSafeArea()
                resultsGlow
            }
        }
        .overlay {
            ZStack {
                reactionParticleOverlay
                    .zIndex(1)
                radialMenuOverlay
                    .zIndex(2)
            }
        }
        .navigationTitle(collapsedNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .tint(Color.white.opacity(0.86))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    Haptics.light()
                    switch mode {
                    case .fresh(let onSave, _, _): leaveResults { onSave(currentHum) }
                    case .saved(_, let onBack): leaveResults(onBack)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Back")
                .opacity(isLeaving ? 0 : 1)
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                autoScrollButton
                    .id("autoScrollButton-\(selectedSpeed?.label ?? "idle")-\(isAutoScrolling)")
                    .opacity(isLeaving ? 0 : 1)
            }

            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .navigationBarTrailing)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                reactionButton
                    .opacity(isLeaving ? 0 : 1)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            runTextEntrance()
            player.load(url: audioURL)
            midiURL = try? MIDIExporter.export(hum: currentHum)
        }
        .task {
            if reduceMotion || Self.isRunningInPreviews {
                showChordReveal = true
                return
            }

            showChordReveal = false
            try? await Task.sleep(for: .milliseconds(980))
            withAnimation(.easeOut(duration: 1.18)) {
                showChordReveal = true
            }
        }
        .onChange(of: name) { _, _ in
            handleNameChange()
        }
        .onDisappear {
            autoScrollCompletionTask?.cancel()
            player.stop()
            chordPlayer.stop()
        }
        .alert("Delete hum?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { pendingDeleteAction = nil }
            Button("Delete", role: .destructive) {
                Haptics.warning()
                performDelete()
            }
        } message: {
            Text("This recording and its audio file will be permanently removed.")
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

        return Array((ranked + Self.fallbackReactions).uniqued().prefix(3))
    }

    private var reactionOptions: [String] {
        Array((topReactions + Self.fallbackReactions).uniqued().prefix(3)) + [Self.addReactionOption]
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

    private var titleCollapseProgress: CGFloat {
        min(max(-scrollContentOffset / 78, 0), 1)
    }

    private var collapsedNavigationTitle: String {
        titleCollapseProgress > 0.55 ? currentHum.name : ""
    }

    // MARK: - Hum info

    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(currentHum.name)
                .font(.system(size: 32, weight: .regular))
                .kerning(-0.4)
                .foregroundStyle(Color.white.opacity(0.45))
                .lineLimit(1)
                .truncationMode(.tail)
            Text(recordedHeadlineLabel)
                .font(.system(size: 32, weight: .regular))
                .kerning(-0.4)
                .foregroundStyle(Color.white.opacity(0.78))
                .lineLimit(1)
                .truncationMode(.tail)
        }
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
                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())],
                spacing: 14
            ) {
                ForEach(Array(hum.chords.enumerated()), id: \.offset) { _, chord in
                    ChordCard(symbol: chord, isContentVisible: showChordReveal) {
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
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    Haptics.selection()
                    player.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().fill(Color.black.opacity(player.isPlaying ? 0.24 : 0.14)))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.075), lineWidth: 1))
                            .frame(width: 42, height: 42)
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.38))
                            .offset(x: player.isPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

                VStack(alignment: .leading, spacing: 8) {
                    Text(recordedDateLabel)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .lineLimit(1)

                    Text("\(player.currentTime.clockString) / \(max(player.duration, hum.duration).clockString)")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.opacity(0.42))
                }

                Spacer()
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        switch mode {
        case .fresh(_, _, let onClose):
            VStack(spacing: 24) {
                exportButton
                deleteHumButton(action: onClose)
            }
        case .saved(let onDelete, _):
            VStack(spacing: 24) {
                exportButton
                deleteHumButton(action: onDelete)
            }
        }
    }

    private var autoScrollButton: some View {
        Button {
                Haptics.light()
                if isAutoScrolling {
                    stopAutoScroll()
                } else if activeRadialMenu == .speed {
                    dismissSpeedMenu()
                } else {
                    presentSpeedMenu()
                }
            } label: {
                autoScrollIconLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isAutoScrolling ? "Pause auto-scroll" : "Start auto-scroll")
            .background(navEntryFrameReader(for: .speed))
    }

    private var autoScrollIconLabel: some View {
        Group {
            if let selectedSpeed {
                Text(selectedSpeed.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .fixedSize()
            } else {
                Image(systemName: "speedometer")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white)
            }
        }
        .frame(minWidth: selectedSpeed == nil ? 44 : 52, minHeight: 44)
        .contentShape(Capsule())
    }

    private func presentSpeedMenu() {
        guard activeRadialMenu != .speed else { return }
        Haptics.selection()
        showRadialMenu(.speed)
    }

    private func dismissSpeedMenu() {
        hideRadialMenu(.speed)
    }

    private func showRadialMenu(_ menu: RadialMenu) {
        expandedRadialMenu = nil
        activeRadialMenu = menu

        Task { @MainActor in
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(1))
            }
            guard activeRadialMenu == menu else { return }
            withAnimation(radialExpandAnimation) {
                expandedRadialMenu = menu
            }
        }
    }

    private func hideRadialMenu(_ menu: RadialMenu) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            if expandedRadialMenu == menu {
                expandedRadialMenu = nil
            }
        }

        Task { @MainActor in
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(180))
            }
            guard activeRadialMenu == menu, expandedRadialMenu == nil else { return }
            activeRadialMenu = nil
        }
    }

    private func startAutoScroll(speed: ScrollSpeed) {
        guard let scrollView = resultsScrollView else {
            selectedSpeed = nil
            return
        }
        autoScrollCompletionTask?.cancel()
        scrollView.layer.removeAllAnimations()

        let maxOffsetY = max(
            -scrollView.adjustedContentInset.top,
            scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )
        let distance = maxOffsetY - scrollView.contentOffset.y
        guard distance > 1 else {
            isAutoScrolling = false
            selectedSpeed = nil
            return
        }

        isAutoScrolling = true
        let duration = autoScrollDuration(distance: distance, speed: speed)

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
                selectedSpeed = nil
                autoScrollCompletionTask = nil
            }
        }
    }

    private func stopAutoScroll() {
        autoScrollCompletionTask?.cancel()
        autoScrollCompletionTask = nil
        isAutoScrolling = false
        selectedSpeed = nil
        expandedRadialMenu = nil
        activeRadialMenu = nil
        guard let scrollView = resultsScrollView else { return }
        // Mid-animation the model offset already sits at the destination; freeze at the
        // visually current offset from the presentation layer instead of jumping to the end.
        let visibleOffset = scrollView.layer.presentation()?.bounds.origin ?? scrollView.contentOffset
        scrollView.layer.removeAllAnimations()
        scrollView.setContentOffset(visibleOffset, animated: false)
    }

    // Constant reading pace: the same speed always scrolls at the same points-per-second,
    // no matter how long the page is or where the scroll starts.
    private func autoScrollDuration(distance: CGFloat, speed: ScrollSpeed) -> Double {
        let pointsPerSecond = 80.0 * speed.rawValue
        return max(Double(distance) / pointsPerSecond, 0.5)
    }

    private var reactionButton: some View {
        Button {
                Haptics.light()
                if activeRadialMenu == .reaction {
                    dismissReactionMenu()
                } else {
                    presentReactionMenu()
                }
            } label: {
                reactionIconLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selectedReaction == nil ? "Add reaction" : "Change reaction")
            .background(navEntryFrameReader(for: .reaction))
    }

    private var reactionIconLabel: some View {
        Group {
            if let selectedReaction {
                Text(selectedReaction)
                    .font(.system(size: 18))
                    .id(selectedReaction)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
            } else {
                Image(systemName: "face.smiling")
                    .symbolVariant(.none)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.7), value: selectedReaction)
        .accessibilityLabel(selectedReaction == nil ? "Add reaction" : "Change reaction")
    }

    private var radialMenuOverlay: some View {
        GeometryReader { proxy in
            ZStack {
                if activeRadialMenu != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: dismissRadialMenus)
                }

                if let activeRadialMenu {
                    switch activeRadialMenu {
                    case .reaction:
                        reactionRadialMenu(in: proxy)
                    case .speed:
                        speedRadialMenu(in: proxy)
                    }
                }
            }
        }
        .allowsHitTesting(activeRadialMenu != nil)
    }

    private var reactionParticleOverlay: some View {
        GeometryReader { proxy in
            if let reactionBurst {
                let menuCenter = radialCenter(for: .reaction, in: proxy)
                let origin = CGPoint(
                    x: menuCenter.x + reactionBurst.originOffset.width,
                    y: menuCenter.y + reactionBurst.originOffset.height
                )

                ReactionParticleBurstView(emoji: reactionBurst.emoji, burstID: reactionBurst.id)
                    .position(origin)
                    .allowsHitTesting(false)
            }
        }
        .allowsHitTesting(false)
    }

    private func reactionRadialMenu(in proxy: GeometryProxy) -> some View {
        let options = reactionOptions
        let center = radialCenter(for: .reaction, in: proxy)
        let isExpanded = expandedRadialMenu == .reaction

        return Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 34) {
                    ZStack {
                        reactionRadialOptions(options: options, isExpanded: isExpanded, usesNativeGlass: true)
                        radialEntryPoint(for: .reaction, usesNativeGlass: true)
                    }
                }
            } else {
                ZStack {
                    reactionRadialOptions(options: options, isExpanded: isExpanded, usesNativeGlass: false)
                    radialEntryPoint(for: .reaction, usesNativeGlass: false)
                }
            }
        }
        .position(center)
    }

    private func speedRadialMenu(in proxy: GeometryProxy) -> some View {
        let options = ScrollSpeed.allCases
        let center = radialCenter(for: .speed, in: proxy)
        let isExpanded = expandedRadialMenu == .speed

        return Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 34) {
                    ZStack {
                        speedRadialOptions(options: options, isExpanded: isExpanded, usesNativeGlass: true)
                        radialEntryPoint(for: .speed, usesNativeGlass: true)
                    }
                }
            } else {
                ZStack {
                    speedRadialOptions(options: options, isExpanded: isExpanded, usesNativeGlass: false)
                    radialEntryPoint(for: .speed, usesNativeGlass: false)
                }
            }
        }
        .position(center)
    }

    private func reactionRadialOptions(options: [String], isExpanded: Bool, usesNativeGlass: Bool) -> some View {
        ZStack {
            ForEach(Array(options.enumerated()), id: \.element) { index, reaction in
                let offset = radialOffset(for: .reaction, index: index, count: options.count)
                radialReactionOption(
                    reaction,
                    isHovered: false,
                    isSelected: reaction != Self.addReactionOption && selectedReaction == reaction,
                    usesNativeGlass: usesNativeGlass
                )
                    .opacity(isExpanded ? 1 : 0)
                    .scaleEffect(isExpanded ? 1 : 0.24)
                    .blur(radius: isExpanded ? 0 : 10)
                    .offset(isExpanded ? offset : .zero)
                    .animation(radialOptionAnimation(index: index), value: isExpanded)
            }
        }
    }

    private func speedRadialOptions(options: [ScrollSpeed], isExpanded: Bool, usesNativeGlass: Bool) -> some View {
        ZStack {
            ForEach(Array(options.enumerated()), id: \.element) { index, speed in
                let offset = radialOffset(for: .speed, index: index, count: options.count)
                radialSpeedOption(speed, isHovered: false, isSelected: selectedSpeed == speed, usesNativeGlass: usesNativeGlass)
                    .opacity(isExpanded ? 1 : 0)
                    .scaleEffect(isExpanded ? 1 : 0.24)
                    .blur(radius: isExpanded ? 0 : 10)
                    .offset(isExpanded ? offset : .zero)
                    .animation(radialOptionAnimation(index: index), value: isExpanded)
            }
        }
    }

    private func radialReactionOption(_ reaction: String, isHovered: Bool, isSelected: Bool, usesNativeGlass: Bool) -> some View {
        Button {
            if reaction == Self.addReactionOption {
                selectReaction(nil)
            } else {
                selectReaction(reaction == selectedReaction ? nil : reaction)
            }
        } label: {
            reactionOptionLabel(reaction)
                .frame(width: 52, height: 52)
                .radialMenuGlassChrome(
                    id: "reaction-\(reaction)",
                    namespace: radialGlassNamespace,
                    usesNativeGlass: usesNativeGlass,
                    isHovered: isHovered,
                    isSelected: isSelected
                )
                .scaleEffect(isHovered ? 1.18 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(reaction == Self.addReactionOption ? "Clear reaction" : "React with \(reaction)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func radialSpeedOption(_ speed: ScrollSpeed, isHovered: Bool, isSelected: Bool, usesNativeGlass: Bool) -> some View {
        Button {
            Haptics.light()
            selectedSpeed = speed
            hideRadialMenu(.speed)
            startAutoScroll(speed: speed)
        } label: {
            Text(speed.label)
                .font(.system(size: isHovered ? 15 : 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(isHovered || isSelected ? 0.95 : 0.72))
                .frame(width: 52, height: 52)
                .radialMenuGlassChrome(
                    id: "speed-\(speed.label)",
                    namespace: radialGlassNamespace,
                    usesNativeGlass: usesNativeGlass,
                    isHovered: isHovered,
                    isSelected: isSelected
                )
                .scaleEffect(isHovered ? 1.18 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Auto-scroll at \(speed.label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func reactionOptionLabel(_ reaction: String) -> some View {
        if reaction == Self.addReactionOption {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.88))
        } else {
            Text(reaction)
                .font(.system(size: 24))
        }
    }

    private func radialEntryPoint(for menu: RadialMenu, usesNativeGlass: Bool) -> some View {
        Button {
            Haptics.light()
            switch menu {
            case .reaction:
                dismissReactionMenu()
            case .speed:
                dismissSpeedMenu()
            }
        } label: {
            Color.clear
            .frame(width: 52, height: 52)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func radialOffset(for menu: RadialMenu, index: Int, count: Int) -> CGSize {
        let radius: CGFloat
        let start: Double
        let end: Double

        switch menu {
        case .reaction:
            radius = 134
            start = 178
            end = 100
        case .speed:
            // 26 (option radius) + 26 (entry radius) + 24pt gap
            radius = 76
            start = 92
            end = 170
        }

        let angle = start + (end - start) * Double(index) / Double(max(count - 1, 1))
        let radians = angle * .pi / 180

        return CGSize(
            width: cos(radians) * radius,
            height: sin(radians) * radius
        )
    }

    private func radialOptionAnimation(index: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        return .spring(duration: 1.05 + Double(index) * 0.1, bounce: 0.24)
    }

    private var radialExpandAnimation: Animation? {
        reduceMotion ? nil : .spring(duration: 0.9, bounce: 0.24)
    }

    private func radialCenter(for menu: RadialMenu, in proxy: GeometryProxy) -> CGPoint {
        if let entryFrame = radialEntryFrames[menu] {
            let overlayFrame = proxy.frame(in: .global)
            return CGPoint(
                x: entryFrame.midX - overlayFrame.minX,
                y: entryFrame.midY - overlayFrame.minY
            )
        }

        let safeTop = proxy.safeAreaInsets.top
        switch menu {
        case .reaction:
            return CGPoint(x: proxy.size.width - 34, y: safeTop + 28)
        case .speed:
            return CGPoint(x: proxy.size.width - 92, y: safeTop + 28)
        }
    }

    private func navEntryFrameReader(for menu: RadialMenu) -> some View {
        GlobalFrameReader { frame in
            guard frame.width > 0, frame.height > 0 else { return }
            if radialEntryFrames[menu] != frame {
                radialEntryFrames[menu] = frame
            }
        }
        .allowsHitTesting(false)
    }

    private func dismissRadialMenus() {
        if activeRadialMenu == .reaction { dismissReactionMenu() }
        if activeRadialMenu == .speed { dismissSpeedMenu() }
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
            .font(.system(size: 14, weight: .regular))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .contentShape(Capsule())
            .accessibilityLabel("Download MIDI file")
    }

    private func deleteHumButton(action: @escaping () -> Void) -> some View {
        Button(role: .destructive) {
            Haptics.light()
            pendingDeleteAction = action
            showingDeleteConfirmation = true
        } label: {
            Text("Delete this hum")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.42))
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func performDelete() {
        guard let pendingDeleteAction else { return }
        self.pendingDeleteAction = nil
        leaveResults(pendingDeleteAction)
    }

    private func handleNameChange() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        midiURL = try? MIDIExporter.export(hum: currentHum)
        if case .saved = mode {
            store.rename(hum, to: trimmed)
        }
    }

    private func presentReactionMenu() {
        showRadialMenu(.reaction)
    }

    private func dismissReactionMenu() {
        hideRadialMenu(.reaction)
    }

    private func selectReaction(_ reaction: String?) {
        let previousReaction = selectedReaction
        selectedReaction = reaction
        if case .saved = mode {
            store.setReaction(reaction, for: hum)
        }
        if let reaction, reaction != previousReaction {
            triggerReactionBurst(for: reaction)
        }
        hideRadialMenu(.reaction)
    }

    private func triggerReactionBurst(for reaction: String) {
        guard !reduceMotion else { return }
        let options = reactionOptions
        let optionIndex = options.firstIndex(of: reaction) ?? 0
        reactionBurst = ReactionBurst(
            emoji: reaction,
            originOffset: radialOffset(for: .reaction, index: optionIndex, count: options.count)
        )

        let burstID = reactionBurst?.id
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1400))
            guard reactionBurst?.id == burstID else { return }
            reactionBurst = nil
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
        isHeadlineVisible = false
        isTextVisible = false
        if reduceMotion || Self.isRunningInPreviews {
            isHeadlineVisible = true
            isTextVisible = true
            return
        }

        Task {
            try? await Task.sleep(for: .milliseconds(70))
            withAnimation(.easeOut(duration: 0.52)) {
                isHeadlineVisible = true
            }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(HumMotion.textReveal) {
                isTextVisible = true
            }
        }
    }

    private func leaveResults(_ completion: @escaping () -> Void) {
        guard !isLeaving else { return }
        isLeaving = true
        player.stop()
        chordPlayer.stop()
        withAnimation(HumMotion.textExit) {
            isHeadlineVisible = false
            isTextVisible = false
            showChordReveal = false
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

private struct GlobalFrameReader: UIViewRepresentable {
    let onChange: (CGRect) -> Void

    func makeUIView(context: Context) -> GlobalFrameReportingView {
        let view = GlobalFrameReportingView()
        view.onFrameChange = onChange
        return view
    }

    func updateUIView(_ uiView: GlobalFrameReportingView, context: Context) {
        uiView.onFrameChange = onChange
        uiView.reportFrame()
    }
}

private final class GlobalFrameReportingView: UIView {
    var onFrameChange: ((CGRect) -> Void)?
    private var lastFrame: CGRect = .null

    override func layoutSubviews() {
        super.layoutSubviews()
        reportFrame()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        reportFrame()
    }

    func reportFrame() {
        guard let window else { return }
        let frame = window.convert(bounds, from: self)
        guard frame != lastFrame else { return }
        lastFrame = frame

        DispatchQueue.main.async { [weak self] in
            self?.onFrameChange?(frame)
        }
    }
}

private struct ReactionParticleBurstView: View {
    let emoji: String
    let burstID: UUID
    @State private var isExpanded = false

    private let particles: [ReactionParticle] = [
        .init(x: -28, y: -92, size: 17, delay: 0.0, rotation: -18, opacity: 0.92),
        .init(x: 18, y: -108, size: 15, delay: 0.04, rotation: 14, opacity: 0.84),
        .init(x: -8, y: -132, size: 13, delay: 0.08, rotation: -8, opacity: 0.72),
        .init(x: 36, y: -78, size: 12, delay: 0.12, rotation: 22, opacity: 0.68),
        .init(x: -42, y: -62, size: 12, delay: 0.16, rotation: -24, opacity: 0.62),
        .init(x: 6, y: -72, size: 18, delay: 0.02, rotation: 6, opacity: 0.86)
    ]

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Text(emoji)
                    .font(.system(size: particle.size))
                    .opacity(isExpanded ? 0 : particle.opacity)
                    .scaleEffect(isExpanded ? 1.12 : 0.28)
                    .rotationEffect(.degrees(isExpanded ? particle.rotation : 0))
                    .blur(radius: isExpanded ? 5 : 0)
                    .offset(
                        x: isExpanded ? particle.x : 0,
                        y: isExpanded ? particle.y : 0
                    )
                    .animation(
                        .easeOut(duration: 1.05).delay(particle.delay),
                        value: isExpanded
                    )
            }
        }
        .id(burstID)
        .onAppear {
            isExpanded = false
            Task { @MainActor in
                await Task.yield()
                isExpanded = true
            }
        }
    }
}

private struct ReactionParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let delay: Double
    let rotation: Double
    let opacity: Double
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

        // The accessor sits in a `.background`, where the scroll view is a
        // sibling rather than an ancestor — search each ancestor's subtree.
        candidate = superview
        while let view = candidate {
            if let scrollView = view.firstScrollViewDescendant {
                return scrollView
            }
            candidate = view.superview
        }
        return nil
    }

    var firstScrollViewDescendant: UIScrollView? {
        if let scrollView = self as? UIScrollView {
            return scrollView
        }
        for subview in subviews {
            if let scrollView = subview.firstScrollViewDescendant {
                return scrollView
            }
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

private extension AnyTransition {
    static func gooeyFanOption(from finalOffset: CGSize) -> AnyTransition {
        .modifier(
            active: GooeyFanOptionModifier(
                opacity: 0,
                scale: 0.24,
                blur: 10,
                offset: CGSize(width: -finalOffset.width, height: -finalOffset.height)
            ),
            identity: GooeyFanOptionModifier(
                opacity: 1,
                scale: 1,
                blur: 0,
                offset: .zero
            )
        )
    }
}

private struct GooeyFanOptionModifier: ViewModifier {
    let opacity: Double
    let scale: CGFloat
    let blur: CGFloat
    let offset: CGSize

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .blur(radius: blur)
            .offset(offset)
    }
}

// MARK: - Components

private extension View {
    func resultCardChrome(isPressed: Bool) -> some View {
        background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(isPressed ? 0.045 : 0.07))
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(isPressed ? 0.24 : 0))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(isPressed ? 0.08 : 0.09), lineWidth: 1)
        )
    }

    @ViewBuilder
    func radialMenuGlassChrome(
        id: String,
        namespace: Namespace.ID,
        usesNativeGlass: Bool,
        isHovered: Bool,
        isSelected: Bool
    ) -> some View {
        if #available(iOS 26.0, *), usesNativeGlass {
            self
                .glassEffect(
                    .regular
                        .tint(Color.white.opacity(isHovered ? 0.2 : isSelected ? 0.11 : 0.085))
                        .interactive(),
                    in: Circle()
                )
                .glassEffectID(id, in: namespace)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(isSelected ? 0.5 : isHovered ? 0.24 : 0.08), lineWidth: isSelected ? 1.5 : 1)
                )
                .shadow(color: .black.opacity(isHovered || isSelected ? 0.2 : 0.14), radius: isHovered || isSelected ? 16 : 12, y: 7)
        } else {
            self
                .background(Circle().fill(Color.black.opacity(isHovered ? 0.38 : isSelected ? 0.25 : 0.22)))
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(isSelected ? 0.5 : isHovered ? 0.22 : 0.1), lineWidth: isSelected ? 1.5 : 1))
                .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
        }
    }
}

struct ChordCard: View {
    let symbol: String
    let isContentVisible: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                Text(symbol)
                    .font(.system(size: 32, weight: .light))
                    .kerning(0.42)
                    .foregroundStyle(.white)
                    .opacity(0.85)

                HStack(spacing: 6) {
                    ForEach(Array(["↓", "↑", "↓", "↑"].enumerated()), id: \.offset) { _, arrow in
                        Text(arrow)
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.36))
            }
            .blur(radius: isContentVisible ? 0 : 16)
            .opacity(isContentVisible ? 1 : 0)
            .offset(y: isContentVisible ? 0 : 10)
            .animation(.easeOut(duration: 1.18), value: isContentVisible)
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
            .foregroundStyle(Color.white.opacity(isEnabled ? 0.92 : 0.35))
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.02), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.1 : 0.18), radius: 16, y: 8)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
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
                .foregroundStyle(Color.white.opacity(0.78))
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Color.white.opacity(0.04), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

#Preview {
    NavigationStack {
        ResultsView(
            hum: Hum(
                id: UUID(),
                name: "Hook Idea",
                createdAt: .now,
                duration: 15,
                key: "Am",
                bpm: 96,
                timeSignature: "4/4",
                chords: ["Am", "F", "C", "G", "Em", "Dm", "Am7", "Fmaj7", "Cadd9", "G7"],
                notes: [],
                audioFileName: ""
            ),
            audioURL: URL(fileURLWithPath: "/dev/null"),
            mode: .fresh(onSave: { _ in }, onRecordAgain: {}, onClose: {})
        )
        .environmentObject(HumStore())
    }
}
