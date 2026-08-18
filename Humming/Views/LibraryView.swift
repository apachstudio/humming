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
    @State private var reactionHum: Hum?
    @State private var searchText = ""
    @State private var isSearchVisible = false
    @State private var filter: LibraryFilter = .all
    @State private var isTextVisible = false
    @State private var isClosing = false

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                libraryBackdrop

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 24)
                        .frame(height: 80)

                    title
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, isSearchVisible ? 12 : 24)

                    if isSearchVisible {
                        searchBar
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                            .premiumTextReveal(isTextVisible, yOffset: 10, blur: 6)
                    }

                    if visibleHums.isEmpty {
                        emptyState
                            .premiumTextReveal(isTextVisible, yOffset: 18, blur: 9)
                    } else {
                        humList
                            .premiumTextReveal(isTextVisible, yOffset: 18, blur: 9)
                    }
                }
            }
            .sheet(item: $reactionHum) { hum in
                EmojiReactionPicker(
                    selectedReaction: hum.emojiReaction,
                    onSelect: { reaction in
                        store.setReaction(reaction, for: hum)
                        reactionHum = nil
                    },
                    onRemove: {
                        store.setReaction(nil, for: hum)
                        reactionHum = nil
                    }
                )
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
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
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .preferredColorScheme(.light)
        .onAppear(perform: runTextEntrance)
    }

    private var libraryBackdrop: some View {
        Color.white
            .ignoresSafeArea()
    }

    private var header: some View {
        HStack {
            LiquidGlassNavIconButton(
                systemName: "chevron.left",
                accessibilityLabel: "Back",
                tone: .light
            ) {
                Haptics.light()
                closeLibrary()
            }

            Spacer()

            LiquidGlassNavIconButton(
                systemName: "magnifyingglass",
                accessibilityLabel: "Search",
                tone: .light
            ) {
                Haptics.light()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearchVisible.toggle()
                }
            }

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
                topNavIconLabel(systemName: "line.3.horizontal.decrease", accessibilityLabel: "Filter")
            }
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your hums,")
                .foregroundStyle(HumTheme.greetingGray)
            Text("ready to play")
                .foregroundStyle(HumTheme.ink)
        }
        .font(.system(size: 32, weight: .regular))
        .kerning(-0.5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumTextReveal(isTextVisible, yOffset: 16, blur: 8)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HumTheme.grayText)

            TextField("Search hums", text: $searchText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(HumTheme.ink)
                .textInputAutocapitalization(.never)

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

    @ViewBuilder
    private func topNavIconLabel(systemName: String, accessibilityLabel: String) -> some View {
        let label = Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(HumTheme.ink)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .accessibilityLabel(accessibilityLabel)

        if #available(iOS 26.0, *) {
            label.glassEffect(.regular.interactive(), in: Circle())
        } else {
            label
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(HumTheme.ink.opacity(0.9), lineWidth: 1))
        }
    }

    private var humList: some View {
        List {
            ForEach(visibleHums) { hum in
                HumRow(
                    hum: hum,
                    onOpen: { openHum(hum) },
                    onReactionTap: {
                        Haptics.light()
                        reactionHum = hum
                    }
                )
                .humMatchedTransitionSource(id: hum.id, in: navigationNamespace)
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
}

/// A single saved hum row with name, chord metadata, and an inline emoji reaction.
struct HumRow: View {
    let hum: Hum
    let onOpen: () -> Void
    let onReactionTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(hum.name)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(HumTheme.ink)
                        .lineLimit(1)

                    Text(chordSummary)
                        .font(.system(size: 12))
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
            .accessibilityLabel(hum.emojiReaction == nil ? "Add reaction" : "Change reaction")
        }
        .padding(.vertical, 16)
    }

    private var chordSummary: String {
        hum.chords.prefix(4).joined(separator: " · ")
    }
}

private struct ReactionIcon: View {
    let reaction: String?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.72))
                .overlay(Circle().strokeBorder(Color.black.opacity(0.07), lineWidth: 1.5))

            if let reaction {
                Text(reaction)
                    .font(.system(size: 16))
            } else {
                Image(systemName: "face.smiling")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.34))

                Image(systemName: "plus")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.38))
                    .offset(x: 8, y: 7)
            }
        }
        .frame(width: 32, height: 32)
        .contentShape(Circle())
    }
}

private struct EmojiReactionPicker: View {
    let selectedReaction: String?
    let onSelect: (String) -> Void
    let onRemove: () -> Void

    private let reactions = ["❤️", "🔥", "✨", "😭", "😍", "🫶", "🎵", "💡", "🚀", "🌙", "👏", "😌"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Reaction")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(HumTheme.ink)

                Spacer()

                if selectedReaction != nil {
                    Button("Remove") {
                        Haptics.light()
                        onRemove()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(HumTheme.grayText)
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(reactions, id: \.self) { reaction in
                    Button {
                        Haptics.selection()
                        onSelect(reaction)
                    } label: {
                        Text(reaction)
                            .font(.system(size: 28))
                            .frame(width: 44, height: 44)
                            .background(
                                Circle().fill(reaction == selectedReaction ? Color.black.opacity(0.08) : Color.black.opacity(0.035))
                            )
                            .overlay(
                                Circle().strokeBorder(
                                    reaction == selectedReaction ? HumTheme.ink.opacity(0.16) : Color.black.opacity(0.05),
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 18)
    }
}

#Preview {
    LibraryView()
        .environmentObject(HumStore())
}
