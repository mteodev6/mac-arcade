//
//  FileImportService.swift
//  MacArcade
//
//  Created for MacArcade.
//

import Foundation

public final class FileImportService {
    public static let shared = FileImportService()
    
    public var gamesDirectoryURL: URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return appSupport?.appendingPathComponent("MacArcade/Games", isDirectory: true)
    }
    
    public init() {
        if let dir = gamesDirectoryURL {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    public struct ImportResult {
        public let game: Game
        public let detectedTitle: String
    }
    
    /// Imports a game file or archive (.swf, .html, .zip, or folder) into the arcade library
    public func importGame(from sourceURL: URL, customTitle: String? = nil, category: GameCategory? = nil) throws -> Game {
        guard let gamesDir = gamesDirectoryURL else {
            throw NSError(domain: "FileImportService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Games directory unavailable"])
        }
        
        let ext = sourceURL.pathExtension.lowercased()
        let rawTitle = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ?
            customTitle! : cleanTitle(from: sourceURL.deletingPathExtension().lastPathComponent)
        
        let gameId = UUID()
        let dirName = gameId.uuidString
        let destGameDir = gamesDir.appendingPathComponent(dirName, isDirectory: true)
        
        try FileManager.default.createDirectory(at: destGameDir, withIntermediateDirectories: true, attributes: nil)
        
        var detectedType: GameType = .html5
        var entryFilename = "index.html"
        var finalCategory: GameCategory = category ?? .arcade
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDir), isDir.boolValue {
            // Folder import
            try copyDirectoryContents(from: sourceURL, to: destGameDir)
            if let entry = findEntryFile(in: destGameDir) {
                entryFilename = entry.filename
                detectedType = entry.type
            }
        } else if ext == "swf" {
            // Single SWF file
            detectedType = .swf
            entryFilename = "game.swf"
            finalCategory = category ?? .flash
            let targetURL = destGameDir.appendingPathComponent("game.swf")
            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
        } else if ext == "html" || ext == "htm" {
            // Single HTML file
            detectedType = .html5
            entryFilename = "index.html"
            let targetURL = destGameDir.appendingPathComponent("index.html")
            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
        } else if ext == "zip" {
            // ZIP archive
            try ZipExtractor.unzip(sourceURL: sourceURL, destinationURL: destGameDir)
            if let entry = findEntryFile(in: destGameDir) {
                entryFilename = entry.filename
                detectedType = entry.type
            }
        } else {
            throw NSError(domain: "FileImportService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unsupported file format (.\(ext)). Please choose .swf, .html, or .zip"])
        }
        
        // Calculate total folder size
        let totalSize = folderSize(destGameDir)
        
        let game = Game(
            id: gameId,
            title: rawTitle,
            type: detectedType,
            entryPath: entryFilename,
            directoryName: dirName,
            isBuiltIn: false,
            dateAdded: Date(),
            lastPlayed: nil,
            playCount: 0,
            totalPlayTime: 0,
            isFavorite: false,
            category: finalCategory,
            tags: [detectedType.rawValue, finalCategory.rawValue],
            notes: "Imported from \(sourceURL.lastPathComponent)",
            customAspectRatio: .auto,
            accentColorHex: detectedType == .swf ? "#ff6600" : "#00f2fe",
            fileSize: totalSize
        )
        
        return game
    }
    
    private func findEntryFile(in directory: URL) -> (filename: String, type: GameType)? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return nil
        }
        
        var candidateHTML: URL?
        var candidateSWF: URL?
        
        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent.lowercased()
            if name == "index.html" || name == "index.htm" {
                let rel = relativePath(from: directory, to: fileURL)
                return (filename: rel, type: .html5)
            } else if name.hasSuffix(".html") || name.hasSuffix(".htm") {
                if candidateHTML == nil { candidateHTML = fileURL }
            } else if name.hasSuffix(".swf") {
                if candidateSWF == nil { candidateSWF = fileURL }
            }
        }
        
        if let swf = candidateSWF {
            return (filename: relativePath(from: directory, to: swf), type: .swf)
        }
        if let html = candidateHTML {
            return (filename: relativePath(from: directory, to: html), type: .html5)
        }
        
        return nil
    }
    
    private func relativePath(from base: URL, to target: URL) -> String {
        let basePath = base.standardizedFileURL.path
        let targetPath = target.standardizedFileURL.path
        if targetPath.hasPrefix(basePath) {
            var sub = String(targetPath.dropFirst(basePath.count))
            if sub.hasPrefix("/") { sub = String(sub.dropFirst()) }
            return sub
        }
        return target.lastPathComponent
    }
    
    private func copyDirectoryContents(from source: URL, to dest: URL) throws {
        let items = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        for item in items {
            let destItem = dest.appendingPathComponent(item.lastPathComponent)
            try FileManager.default.copyItem(at: item, to: destItem)
        }
    }
    
    private func folderSize(_ url: URL) -> Int64 {
        var size: Int64 = 0
        let fm = FileManager.default
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        return size
    }
    
    public func cleanTitle(from filename: String) -> String {
        var clean = filename
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ".", with: " ")
        
        // Remove trailing numbers or artifacts like "v1", "final"
        clean = clean.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { $0.capitalized }
            .joined(separator: " ")
        
        return clean.isEmpty ? "Untitled Game" : clean
    }
}
