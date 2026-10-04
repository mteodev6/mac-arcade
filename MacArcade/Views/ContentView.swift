import AppKit
import SwiftUI

private enum ArcadePalette {
    static let canvas = Color(red: 0.047, green: 0.055, blue: 0.075)
    static let sidebar = Color(red: 0.035, green: 0.041, blue: 0.057)
    static let card = Color(red: 0.085, green: 0.095, blue: 0.125)
    static let field = Color(red: 0.075, green: 0.084, blue: 0.112)
    static let violet = Color(red: 0.50, green: 0.37, blue: 0.98)
    static let blue = Color(red: 0.28, green: 0.56, blue: 0.98)
    static let mint = Color(red: 0.35, green: 0.84, blue: 0.69)
    static let text = Color(red: 0.94, green: 0.95, blue: 0.98)
    static let muted = Color(red: 0.59, green: 0.62, blue: 0.69)
}

struct ContentView: View {
    @StateObject private var library = GameLibrary()
    @State private var selectedSection: LibrarySection? = .all
    @State private var searchText = ""
    @State private var gamePendingRemoval: ArcadeGame?

    var body: some View {
        NavigationSplitView {
            ArcadeSidebar(library: library, selection: $selectedSection)
                .navigationSplitViewColumnWidth(min: 210, ideal: 232, max: 270)
        } detail: {
            Group {
                if let game = library.activeGame {
                    GamePlayerView(game: game, library: library)
                } else {
                    LibraryHomeView(
                        library: library,
                        section: selectedSection ?? .all,
                        searchText: $searchText,
                        onRemove: { gamePendingRemoval = $0 }
                    )
                }
            }
            .frame(minWidth: 590, minHeight: 420)
            .background(ArcadePalette.canvas)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(ArcadePalette.violet)
        .preferredColorScheme(.dark)
        .alert("Mac Arcade", isPresented: Binding(
            get: { library.errorMessage != nil },
            set: { if !$0 { library.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { library.errorMessage = nil }
        } message: {
            Text(library.errorMessage ?? "")
        }
        .confirmationDialog(
            "Remove \(gamePendingRemoval?.title ?? "this game")?",
            isPresented: Binding(
                get: { gamePendingRemoval != nil },
                set: { if !$0 { gamePendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove Game", role: .destructive) {
                if let gamePendingRemoval { library.remove(gamePendingRemoval) }
                gamePendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { gamePendingRemoval = nil }
        } message: {
            Text("The copy stored by Mac Arcade will be deleted. Your original file will not be changed.")
        }
    }
}

private struct ArcadeSidebar: View {
    @ObservedObject var library: GameLibrary
    @Binding var selection: LibrarySection?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [ArcadePalette.violet, ArcadePalette.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MAC ARCADE")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(ArcadePalette.text)
                    Text("YOUR GAME LIBRARY")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(ArcadePalette.muted)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 18)
            .padding(.bottom, 24)

            Button {
                library.presentImportPanel()
            } label: {
                Label("Import Games", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(colors: [ArcadePalette.violet, Color(red: 0.38, green: 0.43, blue: 0.94)], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 5)
            .padding(.bottom, 22)

            List(selection: $selection) {
                Section("LIBRARY") {
                    SidebarRow(section: .all, count: library.games.count)
                        .tag(LibrarySection.all)
                    SidebarRow(section: .html, count: library.games.filter { $0.format == .html }.count)
                        .tag(LibrarySection.html)
                    SidebarRow(section: .flash, count: library.games.filter { $0.format == .flash }.count)
                        .tag(LibrarySection.flash)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(library.serverError == nil ? ArcadePalette.mint : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(library.serverError == nil ? "PLAYER READY" : "PLAYER UNAVAILABLE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(library.serverError == nil ? ArcadePalette.mint : Color.orange)
                }
                Text("HTML + Flash games\nplay locally on this Mac")
                    .font(.system(size: 11))
                    .foregroundStyle(ArcadePalette.muted)
                    .lineSpacing(2)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ArcadePalette.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(.white.opacity(0.055), lineWidth: 1)
            }
            .padding(.top, 12)
            .padding(.horizontal, 4)
            .padding(.bottom, 14)
        }
        .padding(.horizontal, 11)
        .background(ArcadePalette.sidebar)
    }
}

private struct SidebarRow: View {
    let section: LibrarySection
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Label(section.title, systemImage: section.symbolName)
                .font(.system(size: 13, weight: .medium))
            Spacer(minLength: 6)
            Text("\(count)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(ArcadePalette.muted)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.white.opacity(0.055), in: Capsule())
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}

private struct LibraryHomeView: View {
    @ObservedObject var library: GameLibrary
    let section: LibrarySection
    @Binding var searchText: String
    let onRemove: (ArcadeGame) -> Void

    private let columns = [GridItem(.adaptive(minimum: 205, maximum: 310), spacing: 17, alignment: .top)]

    private var visibleGames: [ArcadeGame] {
        library.games.filter { game in
            section.includes(game) && (searchText.isEmpty || game.title.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                if let notice = library.noticeMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ArcadePalette.mint)
                        Text(notice)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ArcadePalette.text)
                        Spacer()
                        Button {
                            library.noticeMessage = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(ArcadePalette.muted)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(ArcadePalette.mint.opacity(0.09), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(ArcadePalette.mint.opacity(0.15), lineWidth: 1)
                    }
                }

                if let serverError = library.serverError {
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("The game player couldn't start")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(ArcadePalette.text)
                            Text(serverError)
                                .font(.system(size: 11))
                                .foregroundStyle(ArcadePalette.muted)
                                .textSelection(.enabled)
                        }
                        Spacer()
                    }
                    .padding(13)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }

                if visibleGames.isEmpty {
                    EmptyLibraryView(
                        hasAnyGames: !library.games.isEmpty,
                        hasSearch: !searchText.isEmpty,
                        section: section,
                        searchText: searchText,
                        onImport: { library.presentImportPanel() },
                        onClearSearch: { searchText = "" }
                    )
                    .frame(maxWidth: .infinity, minHeight: 390)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 17) {
                        ForEach(visibleGames) { game in
                            GameCard(game: game, onPlay: { library.play(game) }, onRemove: { onRemove(game) })
                        }
                    }
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 32)
            .padding(.bottom, 36)
        }
        .background(ArcadePalette.canvas)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(section == .all ? "Your Arcade" : section.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(-0.7)
                    .foregroundStyle(ArcadePalette.text)
                Text(sectionSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(ArcadePalette.muted)
            }

            Spacer(minLength: 14)

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ArcadePalette.muted)
                TextField("Search games", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 142)
                    .accessibilityLabel("Search games")
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(ArcadePalette.field, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.white.opacity(0.07), lineWidth: 1)
            }

            Button {
                library.presentImportPanel()
            } label: {
                Label("Import Game", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(ArcadePalette.violet, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("o", modifiers: .command)
            .help("Import an HTML or SWF game (⌘O)")
        }
    }

    private var sectionSubtitle: String {
        let count = visibleGames.count
        let itemLabel = count == 1 ? "game" : "games"
        switch section {
        case .all: return "Your locally stored collection · \(count) \(itemLabel)"
        case .html: return "Browser-based games · \(count) \(itemLabel)"
        case .flash: return "Flash games powered by Ruffle · \(count) \(itemLabel)"
        }
    }
}

private struct EmptyLibraryView: View {
    let hasAnyGames: Bool
    let hasSearch: Bool
    let section: LibrarySection
    let searchText: String
    let onImport: () -> Void
    let onClearSearch: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(ArcadePalette.violet.opacity(0.13))
                    .frame(width: 92, height: 92)
                Circle()
                    .stroke(ArcadePalette.violet.opacity(0.22), lineWidth: 1)
                    .frame(width: 92, height: 92)
                Image(systemName: hasSearch ? "magnifyingglass" : "gamecontroller.fill")
                    .font(.system(size: 31, weight: .medium))
                    .foregroundStyle(ArcadePalette.violet.opacity(0.95))
            }
            .padding(.bottom, 3)

            Text(emptyTitle)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundStyle(ArcadePalette.text)

            Text(emptyMessage)
                .font(.system(size: 13))
                .foregroundStyle(ArcadePalette.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 390)

            if hasSearch {
                Button("Clear Search", action: onClearSearch)
                    .buttonStyle(.bordered)
                    .tint(ArcadePalette.violet)
                    .padding(.top, 2)
            } else {
                Button(action: onImport) {
                    Label("Import a Game", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 39)
                        .foregroundStyle(.white)
                        .background(ArcadePalette.violet, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private var emptyTitle: String {
        if hasSearch { return "No games found" }
        if !hasAnyGames && section == .all { return "Your arcade is waiting" }
        return "No \(section.title.lowercased()) yet"
    }

    private var emptyMessage: String {
        if hasSearch { return "Nothing matches “\(searchText)”. Try another title or clear your search." }
        if hasAnyGames { return "Import a game to add it to this collection." }
        return "Bring your favorite browser and Flash games together. Import an HTML file or SWF to get started."
    }
}

private struct GameCard: View {
    let game: ArcadeGame
    let onPlay: () -> Void
    let onRemove: () -> Void
    @State private var isHovered = false

    private var accent: Color {
        game.format == .flash ? ArcadePalette.violet : ArcadePalette.blue
    }

    var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(
                            colors: [accent.opacity(0.33), accent.opacity(0.11), ArcadePalette.card],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    Circle()
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                        .frame(width: 142, height: 142)
                        .offset(x: 113, y: -60)
                    Circle()
                        .stroke(.white.opacity(0.055), lineWidth: 1)
                        .frame(width: 190, height: 190)
                        .offset(x: 140, y: -83)

                    Image(systemName: game.format.symbolName)
                        .font(.system(size: 39, weight: .light))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: accent.opacity(0.55), radius: 18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Text(game.format.badgeTitle)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.05)
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.27), in: Capsule())
                        .overlay {
                            Capsule().stroke(.white.opacity(0.13), lineWidth: 1)
                        }
                        .padding(12)

                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 35, height: 35)
                        .background(accent, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: accent.opacity(0.38), radius: 12, y: 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(12)
                }
                .frame(height: 142)
                .clipped()

                VStack(alignment: .leading, spacing: 7) {
                    Text(game.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ArcadePalette.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 9, weight: .medium))
                        Text("Added \(game.importedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(ArcadePalette.muted)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 13)
            }
            .background(ArcadePalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(isHovered ? .white.opacity(0.17) : .white.opacity(0.065), lineWidth: 1)
            }
            .shadow(color: .black.opacity(isHovered ? 0.28 : 0.12), radius: isHovered ? 17 : 10, y: isHovered ? 8 : 5)
            .scaleEffect(isHovered ? 1.015 : 1)
            .animation(.easeOut(duration: 0.16), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(action: onPlay) {
                Label("Play", systemImage: "play.fill")
            }
            Divider()
            Button(role: .destructive, action: onRemove) {
                Label("Remove from Library…", systemImage: "trash")
            }
        }
        .accessibilityLabel("Play \(game.title), \(game.format.title)")
    }
}

private struct GamePlayerView: View {
    let game: ArcadeGame
    @ObservedObject var library: GameLibrary
    @State private var reloadToken = 0
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            playerToolbar
            Rectangle()
                .fill(.white.opacity(0.07))
                .frame(height: 1)

            if let pageURL = library.pageURL(for: game) {
                ZStack {
                    ArcadeWebView(
                        url: pageURL,
                        reloadToken: reloadToken,
                        isLoading: $isLoading,
                        errorMessage: $loadError
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(ArcadePalette.violet)
                            Text("Starting \(game.title)…")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(ArcadePalette.text)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
                        .allowsHitTesting(false)
                    }

                    if let loadError {
                        VStack(spacing: 13) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 26))
                                .foregroundStyle(ArcadePalette.violet)
                            Text("Couldn't open this game")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(ArcadePalette.text)
                            Text(loadError)
                                .font(.system(size: 12))
                                .foregroundStyle(ArcadePalette.muted)
                                .multilineTextAlignment(.center)
                                .textSelection(.enabled)
                            Button {
                                self.loadError = nil
                                reloadToken += 1
                            } label: {
                                Label("Try Again", systemImage: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 14)
                                    .frame(height: 35)
                                    .foregroundStyle(.white)
                                    .background(ArcadePalette.violet, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(26)
                        .frame(maxWidth: 430)
                        .background(ArcadePalette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
                    }
                }
                .background(Color(red: 0.025, green: 0.03, blue: 0.04))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
                .padding(17)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.orange)
                    Text(library.serverError ?? "The local player isn't available.")
                        .font(.system(size: 13))
                        .foregroundStyle(ArcadePalette.muted)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(28)
            }
        }
        .background(ArcadePalette.canvas)
    }

    private var playerToolbar: some View {
        HStack(spacing: 13) {
            Button {
                library.activeGame = nil
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                    Text("Library")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(ArcadePalette.muted)
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Back to your library")

            Rectangle()
                .fill(.white.opacity(0.09))
                .frame(width: 1, height: 25)

            VStack(alignment: .leading, spacing: 3) {
                Text(game.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ArcadePalette.text)
                    .lineLimit(1)
                Text(game.format.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ArcadePalette.muted)
            }

            Spacer(minLength: 10)

            Button {
                reloadToken += 1
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ArcadePalette.text)
                    .frame(width: 35, height: 35)
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Reload game")

            Button {
                NSApp.keyWindow?.toggleFullScreen(nil)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ArcadePalette.text)
                    .frame(width: 35, height: 35)
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Toggle full screen")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(ArcadePalette.sidebar.opacity(0.76))
    }
}
