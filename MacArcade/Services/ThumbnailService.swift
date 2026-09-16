//
//  ThumbnailService.swift
//  MacArcade
//
//  Created for MacArcade.
//

import Foundation
import AppKit
import SwiftUI

public final class ThumbnailService {
    public static let shared = ThumbnailService()
    
    public var thumbnailsDirectoryURL: URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return appSupport?.appendingPathComponent("MacArcade/Thumbnails", isDirectory: true)
    }
    
    public init() {
        if let dir = thumbnailsDirectoryURL {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    /// Returns the file URL for a game's custom thumbnail
    public func thumbnailURL(for game: Game) -> URL? {
        if let customName = game.customThumbnailFilename, let dir = thumbnailsDirectoryURL {
            let candidate = dir.appendingPathComponent(customName)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
    
    /// Loads an NSImage for a game (or returns nil if none saved)
    public func loadThumbnailImage(for game: Game) -> NSImage? {
        guard let url = thumbnailURL(for: game) else { return nil }
        return NSImage(contentsOf: url)
    }
    
    /// Saves a snapshot NSImage as the game's thumbnail
    public func saveThumbnail(image: NSImage, for game: inout Game) throws {
        guard let dir = thumbnailsDirectoryURL else { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        
        let filename = "\(game.id.uuidString).png"
        let destURL = dir.appendingPathComponent(filename)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ThumbnailService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to PNG"])
        }
        
        try pngData.write(to: destURL, options: .atomic)
        game.customThumbnailFilename = filename
    }
    
    /// Generates a stylish retro arcade placeholder cover art NSImage
    public func generatePlaceholderCover(title: String, type: GameType, color: Color) -> NSImage {
        let size = NSSize(width: 480, height: 320)
        let image = NSImage(size: size)
        
        image.lockFocus()
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        
        // 1. Dark Gradient Background
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let darkComponents: [CGFloat] = [
            18/255.0, 16/255.0, 32/255.0, 1.0,
            10/255.0, 10/255.0, 18/255.0, 1.0
        ]
        if let gradient = CGGradient(colorSpace: colorSpace, colorComponents: darkComponents, locations: [0.0, 1.0], count: 2) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: 0, y: 0), options: [])
        }
        
        // 2. CRT Scanline subtle pattern
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.25))
        for y in stride(from: 0, to: size.height, by: 4) {
            context.fill(CGRect(x: 0, y: y, width: size.width, height: 2))
        }
        
        // 3. Glowing Cyber Border
        let borderColor = (type == .swf) ? CGColor(red: 1.0, green: 0.4, blue: 0.1, alpha: 0.8) : CGColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.8)
        context.setStrokeColor(borderColor)
        context.setLineWidth(3.0)
        context.stroke(CGRect(x: 6, y: 6, width: size.width - 12, height: size.height - 12))
        
        // 4. Type Badge Top-Left
        let badgeRect = CGRect(x: 20, y: size.height - 50, width: 85, height: 26)
        context.setFillColor((type == .swf) ? CGColor(red: 1.0, green: 0.35, blue: 0.1, alpha: 0.9) : CGColor(red: 0.0, green: 0.85, blue: 0.95, alpha: 0.9))
        let path = CGPath(roundedRect: badgeRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
        context.addPath(path)
        context.fillPath()
        
        let badgeString = type.shortBadge as NSString
        let badgeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: NSColor.black
        ]
        badgeString.draw(at: CGPoint(x: 32, y: size.height - 46), withAttributes: badgeAttrs)
        
        // 5. Arcade Icon Graphic in Center
        let iconName = (type == .swf) ? "bolt.circle.fill" : "gamecontroller.fill"
        if let sfSymbol = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 64, weight: .bold)
            if let configured = sfSymbol.withSymbolConfiguration(config) {
                let iconRect = NSRect(x: (size.width - 80) / 2, y: (size.height - 60) / 2 + 10, width: 80, height: 80)
                configured.draw(in: iconRect)
            }
        }
        
        // 6. Game Title at Bottom
        let titleString = title as NSString
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .heavy),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        let titleRect = CGRect(x: 20, y: 24, width: size.width - 40, height: 35)
        titleString.draw(in: titleRect, withAttributes: titleAttrs)
        
        image.unlockFocus()
        return image
    }
}
