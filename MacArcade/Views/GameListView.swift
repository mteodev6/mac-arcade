//
//  GameListView.swift
//  MacArcade
//
//  Created for MacArcade.
//

import SwiftUI

public struct GameListView: View {
    @ObservedObject var library: GameLibrary
    public let onPlayGame: (Game) -> Void
    
    public var body: some View {
        Table(library.filteredGames, selection: $library.selectedGameId) {
            TableColumn("Title") { game in
                HStack(spacing: 10) {
                    Circle()
                        .fill(game.accentColor)
                        .frame(width: 8, height: 8)
                    Text(game.title)
                        .fontWeight(.semibold)
                    if game.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 11))
                    }
                }
            }
            .width(min: 180, ideal: 240)
            
            TableColumn("Type") { game in
                Text(game.type.shortBadge)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(game.type.badgeColor))
            }
            .width(60)
            
            TableColumn("Category") { game in
                Text(game.category.displayName)
                    .foregroundColor(.secondary)
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Plays") { game in
                Text("\(game.playCount)")
                    .font(.system(size: 12, design: .monospaced))
            }
            .width(50)
            
            TableColumn("Last Played") { game in
                Text(game.lastPlayedDescription)
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
            }
            .width(min: 100, ideal: 120)
            
            TableColumn("Size") { game in
                Text(game.formattedFileSize)
                    .foregroundColor(.secondary)
                    .font(.system(size: 11, design: .monospaced))
            }
            .width(min: 70, ideal: 80)
            
            TableColumn("Action") { game in
                Button(action: { onPlayGame(game) }) {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .width(40)
        }
        .contextMenu(forSelectionType: Game.ID.self) { selection in
            if let id = selection.first, let game = library.games.first(where: { $0.id == id }) {
                Button("Play Now") { onPlayGame(game) }
                Divider()
                Button(game.isFavorite ? "Unfavorite" : "Favorite") { library.toggleFavorite(for: game) }
                Button("Edit Details...") {
                    library.gameToEdit = game
                    library.isEditGameSheetPresented = true
                }
                Button("Show in Finder") { library.showInFinder(game) }
                Divider()
                Button("Delete Game", role: .destructive) { library.deleteGame(game) }
            }
        }
    }
}
