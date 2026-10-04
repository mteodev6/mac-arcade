import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class GameLibrary: ObservableObject {
    private static let serverPortPreferenceKey = "MacArcade.LocalGameServerPort"

    @Published private(set) var games: [ArcadeGame] = []
    @Published var activeGame: ArcadeGame?
    @Published var errorMessage: String?
    @Published var noticeMessage: String?
    @Published private(set) var serverError: String?

    let gamesDirectoryURL: URL

    private let libraryFileURL: URL
    private let fileManager: FileManager
    private let webServer: LocalGameServer

    init(fileManager: FileManager = .default, bundle: Bundle = .main) {
        self.fileManager = fileManager

        let supportDirectory = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        let appDirectory = supportDirectory.appendingPathComponent("MacArcade", isDirectory: true)
        let gamesDirectory = appDirectory.appendingPathComponent("Games", isDirectory: true)
        let libraryFile = appDirectory.appendingPathComponent("library.json", isDirectory: false)
        let resourceDirectory = bundle.resourceURL?.appendingPathComponent("Ruffle", isDirectory: true)
            ?? bundle.bundleURL.appendingPathComponent("Contents/Resources/Ruffle", isDirectory: true)

        self.gamesDirectoryURL = gamesDirectory
        self.libraryFileURL = libraryFile
        self.webServer = LocalGameServer(gamesDirectoryURL: gamesDirectory, ruffleDirectoryURL: resourceDirectory)

        do {
            try fileManager.createDirectory(at: gamesDirectory, withIntermediateDirectories: true)
        } catch {
            self.errorMessage = "Mac Arcade couldn't create its game library: \(error.localizedDescription)"
        }

        loadLibrary()

        let storedPort = UserDefaults.standard.integer(forKey: Self.serverPortPreferenceKey)
        let preferredPort = storedPort > 0 ? UInt16(exactly: storedPort) : nil
        do {
            try webServer.start(preferredPort: preferredPort)
            if let port = webServer.port {
                UserDefaults.standard.set(Int(port), forKey: Self.serverPortPreferenceKey)
            }
        } catch {
            self.serverError = error.localizedDescription
        }
    }

    func presentImportPanel() {
        let htmlType = UTType.html
        let htmType = UTType(filenameExtension: "htm") ?? htmlType
        let swfType = UTType("com.macarcade.swf")
            ?? UTType(filenameExtension: "swf", conformingTo: .data)
            ?? .data

        let panel = NSOpenPanel()
        panel.title = "Import Games"
        panel.message = "Choose HTML or SWF game files. Keep each game's local assets beside the selected file."
        panel.prompt = "Import"
        panel.allowedContentTypes = [htmlType, htmType, swfType]
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK else { return }
        importGames(from: panel.urls)
    }

    func importGames(from urls: [URL]) {
        guard !urls.isEmpty else { return }
        errorMessage = nil
        noticeMessage = nil

        var importedGames: [ArcadeGame] = []
        var failures: [String] = []

        for url in urls {
            let hasSecurityScope = url.startAccessingSecurityScopedResource()
            do {
                defer {
                    if hasSecurityScope {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                importedGames.append(try importGame(at: url))
            } catch {
                failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if !importedGames.isEmpty {
            let previousGames = games
            let updatedGames = (importedGames + games).sorted { $0.importedAt > $1.importedAt }
            do {
                try saveLibrary(updatedGames)
                games = updatedGames
                noticeMessage = importedGames.count == 1
                    ? "\(importedGames[0].title) is ready to play."
                    : "\(importedGames.count) games are ready to play."
            } catch {
                games = previousGames
                for game in importedGames {
                    try? fileManager.removeItem(at: gameDirectory(for: game))
                }
                failures.append("The library could not be saved: \(error.localizedDescription)")
            }
        }

        if !failures.isEmpty {
            errorMessage = failures.joined(separator: "\n\n")
        }
    }

    func play(_ game: ArcadeGame) {
        guard serverError == nil else {
            errorMessage = "The local game player isn't available. \(serverError ?? "")"
            return
        }
        guard let entryURL = existingEntryURL(for: game), fileManager.fileExists(atPath: entryURL.path) else {
            errorMessage = "The files for \(game.title) are missing. Remove it from the library and import it again."
            return
        }
        guard webServer.url(for: game) != nil else {
            errorMessage = "Mac Arcade couldn't prepare a player page for \(game.title)."
            return
        }

        noticeMessage = nil
        activeGame = game
    }

    func pageURL(for game: ArcadeGame) -> URL? {
        webServer.url(for: game)
    }

    func remove(_ game: ArcadeGame) {
        let updatedGames = games.filter { $0.id != game.id }
        do {
            try saveLibrary(updatedGames)
            games = updatedGames
            if activeGame?.id == game.id { activeGame = nil }

            let folder = gameDirectory(for: game)
            if fileManager.fileExists(atPath: folder.path) {
                do {
                    try fileManager.removeItem(at: folder)
                } catch {
                    errorMessage = "\(game.title) was removed from the library, but its copied files couldn't be deleted: \(error.localizedDescription)"
                }
            }
            noticeMessage = "\(game.title) was removed from your library."
        } catch {
            errorMessage = "Couldn't remove \(game.title): \(error.localizedDescription)"
        }
    }

    private func importGame(at sourceURL: URL) throws -> ArcadeGame {
        guard let format = GameFormat.from(fileExtension: sourceURL.pathExtension) else {
            throw ImportError.unsupportedFile
        }
        let sourceValues = try sourceURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard sourceValues.isRegularFile == true, sourceValues.isSymbolicLink != true else {
            throw ImportError.notARegularFile
        }

        let id = UUID()
        let game = ArcadeGame(
            id: id,
            title: sourceURL.deletingPathExtension().lastPathComponent,
            entryFile: sourceURL.lastPathComponent,
            format: format,
            importedAt: Date()
        )
        let destinationDirectory = gameDirectory(for: game)
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        do {
            // Copy the selected file's neighbors for both formats: HTML needs its
            // scripts/styles/images, and some SWFs load sidecar media at runtime.
            let sourceDirectory = sourceURL.deletingLastPathComponent()
            let siblings = try fileManager.contentsOfDirectory(
                at: sourceDirectory,
                includingPropertiesForKeys: [.isSymbolicLinkKey],
                options: []
            )
            for sibling in siblings {
                if sibling.lastPathComponent == ".DS_Store" { continue }
                let values = try? sibling.resourceValues(forKeys: [.isSymbolicLinkKey])
                if values?.isSymbolicLink == true { continue }
                try fileManager.copyItem(
                    at: sibling,
                    to: destinationDirectory.appendingPathComponent(sibling.lastPathComponent)
                )
            }

            guard let copiedEntry = existingEntryURL(for: game), fileManager.fileExists(atPath: copiedEntry.path) else {
                throw ImportError.copyDidNotContainEntry
            }
            return game
        } catch {
            try? fileManager.removeItem(at: destinationDirectory)
            throw error
        }
    }

    private func loadLibrary() {
        guard fileManager.fileExists(atPath: libraryFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: libraryFileURL)
            let loadedGames = try JSONDecoder().decode([ArcadeGame].self, from: data)
            games = loadedGames.sorted { $0.importedAt > $1.importedAt }
        } catch {
            errorMessage = "Mac Arcade couldn't read its library file: \(error.localizedDescription)"
        }
    }

    private func saveLibrary(_ games: [ArcadeGame]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(games)
        try data.write(to: libraryFileURL, options: .atomic)
    }

    private func gameDirectory(for game: ArcadeGame) -> URL {
        gamesDirectoryURL.appendingPathComponent(game.id.uuidString.lowercased(), isDirectory: true)
    }

    private func existingEntryURL(for game: ArcadeGame) -> URL? {
        let components = game.entryFile.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("\\") && !$0.contains("\0") }) else {
            return nil
        }

        var entry = gameDirectory(for: game)
        for component in components {
            entry.appendPathComponent(component)
        }
        entry = entry.standardizedFileURL.resolvingSymlinksInPath()

        let root = gameDirectory(for: game).standardizedFileURL.resolvingSymlinksInPath()
        let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard entry.path.hasPrefix(rootPrefix) else { return nil }
        return entry
    }

    private enum ImportError: LocalizedError {
        case unsupportedFile
        case notARegularFile
        case copyDidNotContainEntry

        var errorDescription: String? {
            switch self {
            case .unsupportedFile:
                return "Choose an .html, .htm, or .swf file."
            case .notARegularFile:
                return "The selected item isn't a regular file."
            case .copyDidNotContainEntry:
                return "The selected game file wasn't found in the copied game folder."
            }
        }
    }
}
