import SwiftUI

/// The hum library: view saved hums, open their chords, delete them.
/// Styled after the light "Chords Ready" theme.
struct LibraryView: View {
    @EnvironmentObject private var store: HumStore
    @Environment(\.dismiss) private var dismiss

    private let onClose: (() -> Void)?

    private enum LibraryFilter {
        case all
        case reacted
        case unreacted

        var title: String {
            switch self {
            case .all: "All Hums"
            case .reacted: "With Reaction"
            case .unreacted: "No Reaction"
            }
        }
    }

    @Namespace private var navigationNamespace
    @State private var selectedHum: Hum?
    @State private var activeReactionHumID: UUID?
    @State private var searchText = ""
    @State private var isSearchVisible = false
    @State private var filter: LibraryFilter = .all
    @State private var isTextVisible = false
    @State private var isClosing = false
    @State private var isReactionMenuExpanded = false
    @State private var scrollContentOffset: CGFloat = 0

    private let fallbackReactions = ["❤️", "🔥", "✨", "😭", "😍", "🫶", "🎵", "💡", "🚀", "🌙", "👏", "😌"]

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    var body: some View {
        humList
            .premiumTextReveal(isTextVisible, yOffset: 18, blur: 9)
            .background(Color.white.ignoresSafeArea())
            .blur(radius: activeReactionHumID == nil ? 0 : 6)
            .animation(.easeInOut(duration: 0.2), value: activeReactionHumID)
            .overlay {
                if activeReactionHumID != nil {
                    reactionDimmingLayer
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .overlayPreferenceValue(ReactionAnchorPreferenceKey.self) { anchors in
                reactionMenuOverlay(anchors: anchors)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .tint(HumTheme.ink)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Haptics.light()
                        closeLibrary()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Back")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Haptics.light()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSearchVisible.toggle()
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search")
                }

                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .navigationBarTrailing)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("All Hums") {
                            Haptics.selection()
                            filter = .all
                        }
                        Button("With Reaction") {
                            Haptics.selection()
                            filter = .reacted
                        }
                        Button("No Reaction") {
                            Haptics.selection()
                            filter = .unreacted
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .accessibilityLabel("Filter")
                }
            }
            .navigationDestination(item: $selectedHum) { hum in
                ResultsView(
                    hum: hum,
                    audioURL: store.audioURL(for: hum),
                    mode: .saved(
                        onDelete: {
                            store.delete(hum)
                            returnFromHum()
                        },
                        onBack: returnFromHum
                    )
                )
                .humNavigationZoomDestination(sourceID: hum.id, in: navigationNamespace)
                .navigationBarBackButtonHidden(true)
            }
            .preferredColorScheme(.light)
            .onAppear(perform: runTextEntrance)
    }


    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HumTheme.grayText)

            TextField("Search hums", text: $searchText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(HumTheme.ink)
                .textInputAutocapitalization(.never)
                .kerning(-0.28)

            if !searchText.isEmpty {
                Button {
                    Haptics.light()
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HumTheme.grayText.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color.black.opacity(0.035), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.black.opacity(0.06), lineWidth: 1))
    }

    private var visibleHums: [Hum] {
        let filtered = store.hums.filter { hum in
            switch filter {
            case .all:
                true
            case .reacted:
                hum.emojiReaction != nil
            case .unreacted:
                hum.emojiReaction == nil
            }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return filtered }

        return filtered.filter { hum in
            hum.name.localizedCaseInsensitiveContains(query)
            || hum.chords.joined(separator: " ").localizedCaseInsensitiveContains(query)
        }
    }

    private var activeReactionHum: Hum? {
        guard let activeReactionHumID else { return nil }
        return store.hums.first { $0.id == activeReactionHumID }
    }

    private var titleCollapseProgress: CGFloat {
        min(max(-scrollContentOffset / 78, 0), 1)
    }

    private var topReactions: [String] {
        let ranked = Dictionary(grouping: store.hums.compactMap(\.emojiReaction), by: { $0 })
            .map { reaction, uses in (reaction: reaction, count: uses.count) }
            .sorted {
                if $0.count == $1.count { return $0.reaction < $1.reaction }
                return $0.count > $1.count
            }
            .map { $0.reaction }

        return Array((ranked + fallbackReactions).uniqued().prefix(5))
    }

    private var reactionOptions: [String] {
        isReactionMenuExpanded ? (topReactions + fallbackReactions).uniqued() : topReactions
    }

    private var reactionDimmingLayer: some View {
        Color.black.opacity(0.12)
            .background(.ultraThinMaterial)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: dismissReactionMenu)
    }

    @ViewBuilder
    private func reactionMenuOverlay(anchors: [UUID: Anchor<CGRect>]) -> some View {
        GeometryReader { proxy in
            if let hum = activeReactionHum, let anchor = anchors[hum.id] {
                let rect = proxy[anchor]
                let menuWidth = isReactionMenuExpanded ? min(proxy.size.width - 112, 420) : 258
                HStack(spacing: 8) {
                    inlineReactionMenu(for: hum)
                        .frame(width: menuWidth, alignment: .trailing)

                    Button {
                        dismissReactionMenu()
                    } label: {
                        ReactionIcon(reaction: hum.emojiReaction)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close reactions")
                }
                    .position(
                        x: min(proxy.size.width - 24 - (menuWidth + 40) / 2, max(24 + (menuWidth + 40) / 2, rect.maxX - (menuWidth + 40) / 2)),
                        y: rect.midY
                    )
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .zIndex(2)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: activeReactionHumID)
    }

    private func inlineReactionMenu(for hum: Hum) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(reactionOptions, id: \.self) { reaction in
                    Button {
                        Haptics.selection()
                        store.setReaction(reaction == hum.emojiReaction ? nil : reaction, for: hum)
                        dismissReactionMenu()
                    } label: {
                        Text(reaction)
                            .font(.system(size: 32))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("React with \(reaction)")
                }

                if !isReactionMenuExpanded {
                    Button {
                        Haptics.light()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            isReactionMenuExpanded = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(HumTheme.ink.opacity(0.74))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.black.opacity(0.035)))
                            .overlay(Circle().strokeBorder(Color.black.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More reactions")
                } else if hum.emojiReaction != nil {
                    Button {
                        Haptics.light()
                        store.setReaction(nil, for: hum)
                        dismissReactionMenu()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(HumTheme.ink.opacity(0.58))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.black.opacity(0.035)))
                            .overlay(Circle().strokeBorder(Color.black.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove reaction")
                }
            }
            .padding(7)
        }
        .background(Color.white.opacity(0.86), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.black.opacity(0.07), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
    }


    private var humList: some View {
        List {
            libraryHeader
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 24, bottom: 24, trailing: 24))
                .listRowBackground(Color.clear)

            if isSearchVisible {
                searchBar
                    .premiumTextReveal(isTextVisible, yOffset: 10, blur: 6)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
                    .listRowBackground(Color.clear)
            }

            if visibleHums.isEmpty {
                emptyState
                    .premiumTextReveal(isTextVisible, yOffset: 18, blur: 9)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
                    .listRowBackground(Color.clear)
            } else {
                ForEach(visibleHums) { hum in
                    HumRow(
                        hum: hum,
                        onOpen: { openHum(hum) },
                        onReactionTap: {
                            Haptics.light()
                            presentReactionMenu(for: hum)
                        }
                    )
                    .humMatchedTransitionSource(id: hum.id, in: navigationNamespace)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 100, leading: 24, bottom: 26, trailing: 24))
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
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var libraryHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Your hums,")
                .foregroundStyle(HumTheme.grayText2)
            Text("ready to play")
                .fontWeight(.regular)
                .foregroundStyle(HumTheme.ink)
        }
        .font(.system(size: 32, weight: .regular))
        .kerning(-0.4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 32)
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

    private func runTextEntrance() {
        isClosing = false
        isTextVisible = false
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(HumMotion.textReveal) {
                isTextVisible = true
            }
        }
    }

    private func closeLibrary() {
        guard !isClosing else { return }
        isClosing = true
        withAnimation(HumMotion.textExit) {
            isTextVisible = false
        }
        Task {
            try? await Task.sleep(for: HumMotion.textExitDelay)
            if let onClose {
                onClose()
            } else {
                dismiss()
            }
        }
    }

    private func openHum(_ hum: Hum) {
        guard !isClosing else { return }
        isClosing = true
        Haptics.selection()
        withAnimation(HumMotion.textExit) {
            isTextVisible = false
        }
        Task {
            try? await Task.sleep(for: HumMotion.textExitDelay)
            selectedHum = hum
            isClosing = false
        }
    }

    private func returnFromHum() {
        selectedHum = nil
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            runTextEntrance()
        }
    }

    private func presentReactionMenu(for hum: Hum) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            activeReactionHumID = hum.id
            isReactionMenuExpanded = false
        }
    }

    private func dismissReactionMenu() {
        withAnimation(.easeInOut(duration: 0.18)) {
            activeReactionHumID = nil
            isReactionMenuExpanded = false
        }
    }
}

private struct LibraryScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// A single saved hum row with name, chord metadata, and an inline emoji reaction.
struct HumRow: View {
    let hum: Hum
    let onOpen: () -> Void
    let onReactionTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(hum.name)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(HumTheme.ink.opacity(0.9))
                        .kerning(-0.4)
                        .lineLimit(1)

                    Text(chordSummary)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(HumTheme.grayText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onReactionTap) {
                ReactionIcon(reaction: hum.emojiReaction)
            }
            .buttonStyle(.plain)
            .anchorPreference(key: ReactionAnchorPreferenceKey.self, value: .bounds) { anchor in
                [hum.id: anchor]
            }
            .accessibilityLabel(hum.emojiReaction == nil ? "Add reaction" : "Change reaction")
        }
    }

    private var chordSummary: String {
        hum.chords.prefix(4).joined(separator: " · ")
    }
}

private struct ReactionAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: Anchor<CGRect>] = [:]

    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private struct ReactionIcon: View {
    let reaction: String?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.72))
                .overlay(Circle().strokeBorder(Color.black.opacity(0.00), lineWidth: 1.5))

            if let reaction {
                Text(reaction)
                    .font(.system(size: 12))
            } else {
                Image(systemName: "face.smiling")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.34))

              
            }
        }
        .frame(width: 32, height: 32)
        .contentShape(Circle())
        
    }
}

#Preview {
    NavigationStack {
        LibraryView()
            .environmentObject(HumStore())
    }
}
