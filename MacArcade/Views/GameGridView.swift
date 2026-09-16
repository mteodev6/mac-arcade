//
//  GameGridView.swift
//  MacArcade
//
//  Created for MacArcade.
//

import SwiftUI

public struct GameGridView: View {
    @ObservedObject var library: GameLibrary
    @ObservedObject var settings: ArcadeSettings
    public let onPlayGame: (Game) -> Void
    
    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 16)
    ]
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Control Bar
            HStack(spacing: 12) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search arcade games, tags...", text: $library.searchQuery)
                        .textFieldStyle(.plain)
                    if !library.searchQuery.isEmpty {
                        Button(action: { library.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.1, green: 0.12, blue: 0.2)))
                .frame(maxWidth: 280)
                
                Spacer()
                
                // Sort picker
                Picker("Sort", selection: $library.sortOption) {
                    ForEach(SortOption.allCases) { opt in
                        Text(opt.displayName).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                
                // View Mode toggle
                Picker("View", selection: $library.viewMode) {
                    Image(systemName: "square.grid.2x2").tag(ViewMode.grid)
                    Image(systemName: "list.bullet").tag(ViewMode.list)
                }
                .pickerStyle(.segmented)
                .frame(width: 75)
                
                // Add Game Button
                ArcadeButton("Add Game", systemImage: "plus") {
                    library.isAddGameSheetPresented = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(red: 0.05, green: 0.06, blue: 0.12))
            
            Divider()
            
            // Content
            if library.filteredGames.isEmpty {
                emptyStateView
            } else if library.viewMode == .grid {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(library.filteredGames) { game in
                            GameCardView(game: game, library: library) {
                                onPlayGame(game)
                            }
                        }
                    }
                    .padding(20)
                }
            } else {
                GameListView(library: library, onPlayGame: onPlayGame)
            }
        }
        .background(Color(red: 0.04, green: 0.05, blue: 0.09))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "gamecontroller")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Games Found")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text("Drag & drop any .SWF, .HTML, or .ZIP game files here, or click Add Game")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            
            ArcadeButton("Upload Game", systemImage: "plus.circle") {
                library.isAddGameSheetPresented = true
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
