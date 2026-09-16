//
//  MacArcadeApp.swift
//  MacArcade
//
//  Created for MacArcade.
//

import SwiftUI

@main
struct MacArcadeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var library = GameLibrary.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 1000, idealWidth: 1200, minHeight: 680, idealHeight: 800)
                .background(Color(red: 0.04, green: 0.05, blue: 0.09))
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Game to Arcade...") {
                    library.isAddGameSheetPresented = true
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
            
            CommandMenu("Arcade") {
                Button("Preferences...") {
                    library.isSettingsSheetPresented = true
                }
                .keyboardShortcut(",", modifiers: [.command])
                
                Divider()
                
                Button("Show Games Folder in Finder") {
                    if let url = FileImportService.shared.gamesDirectoryURL {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
            }
        }
    }
}
