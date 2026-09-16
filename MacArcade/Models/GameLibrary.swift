//
//  GameLibrary.swift
//  MacArcade
//
//  Created for MacArcade.
//

import Foundation
import SwiftUI
import AppKit
import Combine

public enum SidebarFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case flash = "flash"
    case html5 = "html5"
    case favorites = "favorites"
    case recent = "recent"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .all: return "All Games"
        case .flash: return "Flash (SWF)"
        case .html5: return "HTML5 Games"
        case .favorites: return "Favorites"
        case .recent: return "Recently Played"
        }
    }
    
    public var iconName: String {
        switch self {
        case .all: return "arcade.stick.console.fill"
        case .flash: return "bolt.fill"
        case .html5: return "globe"
        case .favorites: return "star.fill"
        case .recent: return "clock.fill"
        }
    }
}

public enum SortOption: String, CaseIterable, Identifiable {
    case recentAdded = "recentAdded"
    case recentPlayed = "recentPlayed"
    case titleAZ = "titleAZ"
    case titleZA = "titleZA"
    case mostPlayed = "mostPlayed"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .recentAdded: return "Recently Added"
        case .recentPlayed: return "Recently Played"
        case .titleAZ: return "Title (A - Z)"
        case .titleZA: return "Title (Z - A)"
        case .mostPlayed: return "Most Played"
        }
    }
}

public enum ViewMode: String, CaseIterable, Identifiable {
    case grid = "grid"
    case list = "list"
    public var id: String { rawValue }
}

public class GameLibrary: ObservableObject {
    public static let shared = GameLibrary()
    
    @Published public var games: [Game] = []
    @Published public var selectedGameId: UUID? = nil
    @Published public var activePlayingGame: Game? = nil
    
    @Published public var selectedFilter: SidebarFilter = .all
    @Published public var selectedCategory: GameCategory = .all
    @Published public var searchQuery: String = ""
    @Published public var sortOption: SortOption = .recentAdded
    @Published public var viewMode: ViewMode = .grid
    
    @Published public var isAddGameSheetPresented: Bool = false
    @Published public var isSettingsSheetPresented: Bool = false
    @Published public var isEditGameSheetPresented: Bool = false
    @Published public var gameToEdit: Game? = nil
    @Published public var errorMessage: String? = nil
    @Published public var showErrorAlert: Bool = false
    
    private var libraryFileURL: URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return appSupport?.appendingPathComponent("MacArcade/games.json")
    }
    
    public var selectedGame: Game? {
        get { games.first { $0.id == selectedGameId } }
        set {
            if let newValue = newValue, let idx = games.firstIndex(where: { $0.id == newValue.id }) {
                games[idx] = newValue
            }
        }
    }
    
    public init() {
        loadLibrary()
        installBuiltInGamesIfNeeded()
    }
    
    // MARK: - Filtered & Sorted Games
    
    public var filteredGames: [Game] {
        var result = games
        
        // 1. Sidebar Filter
        switch selectedFilter {
        case .all:
            break
        case .flash:
            result = result.filter { $0.type == .swf }
        case .html5:
            result = result.filter { $0.type == .html5 }
        case .favorites:
            result = result.filter { $0.isFavorite }
        case .recent:
            result = result.filter { $0.lastPlayed != nil }
        }
        
        // 2. Category Filter
        if selectedCategory != .all {
            result = result.filter { $0.category == selectedCategory }
        }
        
        // 3. Search Query
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { game in
                game.title.lowercased().contains(query) ||
                game.tags.contains { $0.lowercased().contains(query) } ||
                game.notes.lowercased().contains(query) ||
                game.type.displayName.lowercased().contains(query)
            }
        }
        
        // 4. Sorting
        switch sortOption {
        case .recentAdded:
            result.sort { $0.dateAdded > $1.dateAdded }
        case .recentPlayed:
            result.sort { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
        case .titleAZ:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .titleZA:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        case .mostPlayed:
            result.sort { $0.playCount > $1.playCount }
        }
        
        return result
    }
    
    // MARK: - Game Statistics
    
    public var totalGamesCount: Int { games.count }
    public var flashGamesCount: Int { games.filter { $0.type == .swf }.count }
    public var htmlGamesCount: Int { games.filter { $0.type == .html5 }.count }
    public var favoritesCount: Int { games.filter { $0.isFavorite }.count }
    public var totalPlayCount: Int { games.reduce(0) { $0 + $1.playCount } }
    public var totalPlayDuration: TimeInterval { games.reduce(0) { $0 + $1.totalPlayTime } }
    
    // MARK: - Persistence
    
    public func loadLibrary() {
        guard let url = libraryFileURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Game].self, from: data)
            self.games = decoded
            if selectedGameId == nil, let first = games.first {
                selectedGameId = first.id
            }
        } catch {
            NSLog("[GameLibrary] Failed to load library: %@", error.localizedDescription)
        }
    }
    
    public func saveLibrary() {
        guard let url = libraryFileURL else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            let encoded = try JSONEncoder().encode(games)
            try encoded.write(to: url, options: .atomic)
        } catch {
            NSLog("[GameLibrary] Failed to save library: %@", error.localizedDescription)
        }
    }
    
    // MARK: - Built-in Games Initialization
    
    public func installBuiltInGamesIfNeeded() {
        guard let bundleBuiltInURL = Bundle.main.url(forResource: "BuiltInGames", withExtension: nil) ??
                Bundle.main.resourceURL?.appendingPathComponent("BuiltInGames") else {
            return
        }
        
        guard FileManager.default.fileExists(atPath: bundleBuiltInURL.path) else { return }
        
        do {
            let folders = try FileManager.default.contentsOfDirectory(at: bundleBuiltInURL, includingPropertiesForKeys: nil)
            for folder in folders {
                let metadataURL = folder.appendingPathComponent("metadata.json")
                if FileManager.default.fileExists(atPath: metadataURL.path) {
                    let metaData = try Data(contentsOf: metadataURL)
                    if var game = try? JSONDecoder().decode(Game.self, from: metaData) {
                        game.isBuiltIn = true
                        game.directoryName = folder.lastPathComponent
                        
                        // Check if already in games array
                        if !games.contains(where: { $0.id == game.id }) {
                            games.append(game)
                        }
                    }
                }
            }
            saveLibrary()
            if selectedGameId == nil, let first = games.first {
                selectedGameId = first.id
            }
        } catch {
            NSLog("[GameLibrary] Error loading built-in games: %@", error.localizedDescription)
        }
    }
    
    // MARK: - Library Operations
    
    public func importGame(from sourceURL: URL, title: String? = nil, category: GameCategory? = nil) {
        do {
            let game = try FileImportService.shared.importGame(from: sourceURL, customTitle: title, category: category)
            games.insert(game, at: 0)
            selectedGameId = game.id
            saveLibrary()
        } catch {
            self.errorMessage = error.localizedDescription
            self.showErrorAlert = true
        }
    }
    
    public func toggleFavorite(for game: Game) {
        if let idx = games.firstIndex(where: { $0.id == game.id }) {
            games[idx].isFavorite.toggle()
            saveLibrary()
        }
    }
    
    public func recordPlaySession(for game: Game, duration: TimeInterval) {
        if let idx = games.firstIndex(where: { $0.id == game.id }) {
            games[idx].playCount += 1
            games[idx].lastPlayed = Date()
            games[idx].totalPlayTime += duration
            saveLibrary()
        }
    }
    
    public func updateGame(_ game: Game) {
        if let idx = games.firstIndex(where: { $0.id == game.id }) {
            games[idx] = game
            saveLibrary()
        }
    }
    
    public func deleteGame(_ game: Game, deleteFiles: Bool = true) {
        if deleteFiles && !game.isBuiltIn {
            if let gamesDir = FileImportService.shared.gamesDirectoryURL {
                let folder = gamesDir.appendingPathComponent(game.directoryName)
                try? FileManager.default.removeItem(at: folder)
            }
            if let thumb = game.customThumbnailFilename, let thumbDir = ThumbnailService.shared.thumbnailsDirectoryURL {
                let thumbFile = thumbDir.appendingPathComponent(thumb)
                try? FileManager.default.removeItem(at: thumbFile)
            }
        }
        
        games.removeAll { $0.id == game.id }
        if selectedGameId == game.id {
            selectedGameId = games.first?.id
        }
        if activePlayingGame?.id == game.id {
            activePlayingGame = nil
        }
        saveLibrary()
    }
    
    public func exportGame(_ game: Game, to destinationURL: URL) {
        let fileManager = FileManager.default
        let sourceURL: URL
        if game.isBuiltIn {
            guard let builtInDir = ArcadeServer.shared.builtInGamesDirectoryURL else { return }
            sourceURL = builtInDir.appendingPathComponent(game.directoryName)
        } else {
            guard let userDir = FileImportService.shared.gamesDirectoryURL else { return }
            sourceURL = userDir.appendingPathComponent(game.directoryName)
        }
        
        guard fileManager.fileExists(atPath: sourceURL.path) else { return }
        
        let sanitizedTitle = game.title.replacingOccurrences(of: "/", with: "-")
        let targetFolder = destinationURL.appendingPathComponent(sanitizedTitle, isDirectory: true)
        
        do {
            if fileManager.fileExists(atPath: targetFolder.path) {
                try fileManager.removeItem(at: targetFolder)
            }
            try fileManager.copyItem(at: sourceURL, to: targetFolder)
            NSWorkspace.shared.activateFileViewerSelecting([targetFolder])
        } catch {
            self.errorMessage = "Failed to export game: \(error.localizedDescription)"
            self.showErrorAlert = true
        }
    }
    
    public func showInFinder(_ game: Game) {
        let sourceURL: URL
        if game.isBuiltIn {
            guard let builtInDir = ArcadeServer.shared.builtInGamesDirectoryURL else { return }
            sourceURL = builtInDir.appendingPathComponent(game.directoryName)
        } else {
            guard let userDir = FileImportService.shared.gamesDirectoryURL else { return }
            sourceURL = userDir.appendingPathComponent(game.directoryName)
        }
        
        if FileManager.default.fileExists(atPath: sourceURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([sourceURL])
        }
    }
}
