//
//  MainView.swift
//  MacArcade
//
//  Created for MacArcade.
//

import SwiftUI
import AppKit

public struct MainView: View {
    @StateObject private var library = GameLibrary.shared
    @StateObject private var settings = ArcadeSettings.shared
    @State private var isWindowDropTargeted = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            if let activeGame = library.activePlayingGame {
                // Game Playing Mode
                PlayerView(
                    game: activeGame,
                    library: library,
                    settings: settings,
                    onExit: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            library.activePlayingGame = nil
                        }
                    }
                )
                .transition(.opacity)
            } else {
                // Arcade Library Browser Mode
                NavigationSplitView {
                    SidebarView(library: library, settings: settings)
                        .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)
                } content: {
                    GameGridView(library: library, settings: settings) { game in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            library.activePlayingGame = game
                        }
                    }
                    .frame(minWidth: 400)
                } detail: {
                    if let selected = library.selectedGame {
                        GameDetailView(game: selected, library: library) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                library.activePlayingGame = selected
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "gamecontroller")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("Select a game to view details")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(red: 0.05, green: 0.06, blue: 0.12))
                    }
                }
                .navigationTitle("Mac Arcade")
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button(action: { library.isSettingsSheetPresented = true }) {
                            Image(systemName: "gearshape")
                        }
                        .help("Arcade Preferences")
                    }
                }
            }
            
            // Drag and Drop Overlay
            DropZoneOverlay(isTargeted: isWindowDropTargeted)
        }
        .sheet(isPresented: $library.isAddGameSheetPresented) {
            AddGameSheet(library: library)
        }
        .sheet(isPresented: $library.isEditGameSheetPresented) {
            if let game = library.gameToEdit {
                EditGameSheet(library: library, game: game)
            }
        }
        .sheet(isPresented: $library.isSettingsSheetPresented) {
            SettingsView(settings: settings, library: library)
        }
        .alert("Arcade Notice", isPresented: $library.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(library.errorMessage ?? "An error occurred.")
        }
        .onDrop(of: ["public.file-url"], isTargeted: $isWindowDropTargeted) { providers in
            handleWindowDrop(providers: providers)
        }
    }
    
    private func handleWindowDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
            guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                library.importGame(from: url)
            }
        }
        return true
    }
}
