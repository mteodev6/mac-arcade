//
//  Game.swift
//  MacArcade
//
//  Created for MacArcade.
//

import Foundation
import SwiftUI

public enum GameType: String, Codable, CaseIterable {
    case swf = "swf"
    case html5 = "html5"
    
    public var displayName: String {
        switch self {
        case .swf: return "Flash SWF"
        case .html5: return "HTML5 Game"
        }
    }
    
    public var shortBadge: String {
        switch self {
        case .swf: return "SWF"
        case .html5: return "HTML5"
        }
    }
    
    public var badgeColor: Color {
        switch self {
        case .swf: return Color(red: 1.0, green: 0.35, blue: 0.1) // Flash Orange
        case .html5: return Color(red: 0.0, green: 0.85, blue: 0.95) // Neon Cyan
        }
    }
    
    public var systemImage: String {
        switch self {
        case .swf: return "bolt.fill"
        case .html5: return "globe"
        }
    }
}

public enum GameCategory: String, Codable, CaseIterable, Identifiable {
    case all = "all"
    case arcade = "arcade"
    case action = "action"
    case puzzle = "puzzle"
    case retro = "retro"
    case flash = "flash"
    case shooter = "shooter"
    case classic = "classic"
    case casual = "casual"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .all: return "All Categories"
        case .arcade: return "Arcade"
        case .action: return "Action"
        case .puzzle: return "Puzzle & Brain"
        case .retro: return "Retro Classics"
        case .flash: return "Flash Legacy"
        case .shooter: return "Shooters"
        case .classic: return "Classic"
        case .casual: return "Casual"
        }
    }
    
    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .arcade: return "gamecontroller.fill"
        case .action: return "flame.fill"
        case .puzzle: return "puzzlepiece.fill"
        case .retro: return "tv.fill"
        case .flash: return "bolt.shield.fill"
        case .shooter: return "scope"
        case .classic: return "star.fill"
        case .casual: return "sparkles"
        }
    }
}

public enum GameAspectRatio: String, Codable, CaseIterable, Identifiable {
    case auto = "auto"
    case standard4x3 = "standard4x3"
    case widescreen16x9 = "widescreen16x9"
    case square1x1 = "square1x1"
    case fill = "fill"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .auto: return "Auto (Original)"
        case .standard4x3: return "4:3 (CRT / Classic)"
        case .widescreen16x9: return "16:9 (Widescreen)"
        case .square1x1: return "1:1 (Square)"
        case .fill: return "Stretch to Fit"
        }
    }
    
    public var ratioValue: CGFloat? {
        switch self {
        case .auto: return nil
        case .standard4x3: return 4.0 / 3.0
        case .widescreen16x9: return 16.0 / 9.0
        case .square1x1: return 1.0
        case .fill: return nil
        }
    }
}

public struct Game: Identifiable, Codable, Hashable {
    public var id: UUID
    public var title: String
    public var type: GameType
    public var entryPath: String // Relative path to main file in directory (e.g. "index.html" or "game.swf")
    public var directoryName: String // Folder name in Games directory
    public var isBuiltIn: Bool
    public var dateAdded: Date
    public var lastPlayed: Date?
    public var playCount: Int
    public var totalPlayTime: TimeInterval // In seconds
    public var isFavorite: Bool
    public var category: GameCategory
    public var tags: [String]
    public var notes: String
    public var customAspectRatio: GameAspectRatio
    public var accentColorHex: String
    public var fileSize: Int64
    public var customThumbnailFilename: String?
    
    public init(
        id: UUID = UUID(),
        title: String,
        type: GameType,
        entryPath: String,
        directoryName: String,
        isBuiltIn: Bool = false,
        dateAdded: Date = Date(),
        lastPlayed: Date? = nil,
        playCount: Int = 0,
        totalPlayTime: TimeInterval = 0,
        isFavorite: Bool = false,
        category: GameCategory = .arcade,
        tags: [String] = [],
        notes: String = "",
        customAspectRatio: GameAspectRatio = .auto,
        accentColorHex: String = "#00f2fe",
        fileSize: Int64 = 0,
        customThumbnailFilename: String? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.entryPath = entryPath
        self.directoryName = directoryName
        self.isBuiltIn = isBuiltIn
        self.dateAdded = dateAdded
        self.lastPlayed = lastPlayed
        self.playCount = playCount
        self.totalPlayTime = totalPlayTime
        self.isFavorite = isFavorite
        self.category = category
        self.tags = tags
        self.notes = notes
        self.customAspectRatio = customAspectRatio
        self.accentColorHex = accentColorHex
        self.fileSize = fileSize
        self.customThumbnailFilename = customThumbnailFilename
    }
    
    public var accentColor: Color {
        Color(hex: accentColorHex) ?? type.badgeColor
    }
    
    public var formattedFileSize: String {
        if fileSize <= 0 { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    public var formattedPlayTime: String {
        if totalPlayTime < 60 {
            return "\(Int(totalPlayTime))s"
        } else if totalPlayTime < 3600 {
            let mins = Int(totalPlayTime / 60)
            return "\(mins) min"
        } else {
            let hours = Int(totalPlayTime / 3600)
            let mins = Int((totalPlayTime.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(mins)m"
        }
    }
    
    public var lastPlayedDescription: String {
        guard let lastPlayed = lastPlayed else { return "Never played" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastPlayed, relativeTo: Date())
    }
}

// Color Hex Extension
extension Color {
    public init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        let r, g, b, a: Double
        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
