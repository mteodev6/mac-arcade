//
//  GameCardView.swift
//  MacArcade
//
//  Created for MacArcade.
//

import SwiftUI
import AppKit

public struct GameCardView: View {
    public let game: Game
    @ObservedObject var library: GameLibrary
    public let onPlay: () -> Void
    
    @State private var isHovered = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail / Cover Art Area
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image = ThumbnailService.shared.loadThumbnailImage(for: game) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(nsImage: ThumbnailService.shared.generatePlaceholderCover(title: game.title, type: game.type, color: game.accentColor))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
                .frame(height: 150)
                .clipped()
                
                // Top-Left Type Badge
                HStack {
                    Text(game.type.shortBadge)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(game.type.badgeColor))
                        .shadow(color: game.type.badgeColor.opacity(0.8), radius: 6)
                    
                    Spacer()
                    
                    // Favorite button
                    Button(action: {
                        library.toggleFavorite(for: game)
                    }) {
                        Image(systemName: game.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(game.isFavorite ? Color(red: 1.0, green: 0.85, blue: 0.0) : .white.opacity(0.7))
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                
                // Hover Play Overlay
                if isHovered {
                    ZStack {
                        Color.black.opacity(0.5)
                        
                        Button(action: onPlay) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14))
                                Text("PLAY")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .tracking(2)
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(game.accentColor))
                            .shadow(color: game.accentColor, radius: 12)
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity)
                }
            }
            .frame(height: 150)
            
            // Card Content Area
            VStack(alignment: .leading, spacing: 6) {
                Text(game.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(game.category.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 3, height: 3)
                    
                    if game.playCount > 0 {
                        Text("\(game.playCount) \(game.playCount == 1 ? "play" : "plays")")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    } else {
                        Text("New")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))
                    }
                    
                    Spacer()
                }
            }
            .padding(12)
            .background(Color(red: 0.08, green: 0.09, blue: 0.15))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isHovered ? game.accentColor : Color.white.opacity(0.1),
                    lineWidth: isHovered ? 2 : 1
                )
        )
        .shadow(
            color: isHovered ? game.accentColor.opacity(0.4) : Color.black.opacity(0.3),
            radius: isHovered ? 12 : 6,
            y: 4
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            library.selectedGameId = game.id
        }
        .contextMenu {
            Button("Play Now") { onPlay() }
            Divider()
            Button(game.isFavorite ? "Remove from Favorites" : "Mark as Favorite") {
                library.toggleFavorite(for: game)
            }
            Button("Edit Game Details...") {
                library.gameToEdit = game
                library.isEditGameSheetPresented = true
            }
            Button("Show in Finder") {
                library.showInFinder(game)
            }
            Button("Export Game...") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.canCreateDirectories = true
                panel.prompt = "Export Here"
                if panel.runModal() == .OK, let target = panel.url {
                    library.exportGame(game, to: target)
                }
            }
            Divider()
            Button("Delete Game", role: .destructive) {
                library.deleteGame(game)
            }
        }
    }
}
