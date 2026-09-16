//
//  GameDetailView.swift
//  MacArcade
//
//  Created for MacArcade.
//

import SwiftUI

public struct GameDetailView: View {
    public let game: Game
    @ObservedObject var library: GameLibrary
    public let onPlay: () -> Void
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header Cover Art
                ZStack(alignment: .bottomLeading) {
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
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    
                    // Gradient overlay
                    LinearGradient(
                        colors: [Color.clear, Color(red: 0.05, green: 0.06, blue: 0.12).opacity(0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Title and badges
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(game.type.displayName.uppercased())
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(game.type.badgeColor))
                            
                            Text(game.category.displayName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.white.opacity(0.2)))
                            
                            Spacer()
                            
                            Button(action: { library.toggleFavorite(for: game) }) {
                                Image(systemName: game.isFavorite ? "star.fill" : "star")
                                    .font(.system(size: 15))
                                    .foregroundColor(game.isFavorite ? .yellow : .white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Text(game.title)
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(.white)
                    }
                    .padding(16)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                // Play Button
                Button(action: onPlay) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20))
                        Text("INSERT COIN & PLAY")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .tracking(2)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.0, green: 0.95, blue: 1.0), Color(red: 0.0, green: 0.75, blue: 1.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                    )
                    .shadow(color: Color(red: 0.0, green: 0.95, blue: 1.0).opacity(0.5), radius: 10)
                }
                .buttonStyle(.plain)
                
                // Game Notes & Controls
                if !game.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ABOUT & CONTROLS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))
                        
                        Text(game.notes)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(4)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                }
                
                // Details Grid
                VStack(alignment: .leading, spacing: 10) {
                    Text("GAME SPECIFICATIONS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    specRow("Format", value: game.type.displayName)
                    specRow("Category", value: game.category.displayName)
                    specRow("Aspect Ratio", value: game.customAspectRatio.displayName)
                    specRow("Times Played", value: "\(game.playCount)")
                    specRow("Total Playtime", value: game.formattedPlayTime)
                    specRow("Last Played", value: game.lastPlayedDescription)
                    specRow("File Size", value: game.formattedFileSize)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                
                // Action Buttons
                VStack(spacing: 8) {
                    Button(action: {
                        library.gameToEdit = game
                        library.isEditGameSheetPresented = true
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit Game Details")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        library.showInFinder(game)
                    }) {
                        HStack {
                            Image(systemName: "folder")
                            Text("Show Game Files in Finder")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    
                    if !game.isBuiltIn {
                        Button(role: .destructive, action: {
                            library.deleteGame(game)
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Game")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
        .background(Color(red: 0.05, green: 0.06, blue: 0.12))
    }
    
    private func specRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}
