import Foundation

enum GameFormat: String, Codable, CaseIterable, Identifiable {
    case html
    case flash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .html: return "HTML Game"
        case .flash: return "Flash Game"
        }
    }

    var badgeTitle: String {
        switch self {
        case .html: return "HTML"
        case .flash: return "FLASH"
        }
    }

    var symbolName: String {
        switch self {
        case .html: return "globe"
        case .flash: return "bolt.fill"
        }
    }

    static func from(fileExtension: String) -> GameFormat? {
        switch fileExtension.lowercased() {
        case "html", "htm": return .html
        case "swf": return .flash
        default: return nil
        }
    }
}

struct ArcadeGame: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    /// Relative to this game's private folder in Application Support.
    var entryFile: String
    var format: GameFormat
    var importedAt: Date
}

enum LibrarySection: String, CaseIterable, Hashable, Identifiable {
    case all
    case html
    case flash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All Games"
        case .html: return "HTML Games"
        case .flash: return "Flash Games"
        }
    }

    var symbolName: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .html: return "globe"
        case .flash: return "bolt.fill"
        }
    }

    func includes(_ game: ArcadeGame) -> Bool {
        switch self {
        case .all: return true
        case .html: return game.format == .html
        case .flash: return game.format == .flash
        }
    }
}
