//
//  AppDelegate.swift
//  MacArcade
//
//  Created for MacArcade.
//

import Cocoa
import SwiftUI

public class AppDelegate: NSObject, NSApplicationDelegate {
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupDirectoriesAndServer()
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        ArcadeServer.shared.stop()
    }
    
    /// Handle files opened via Finder "Open With" or dragged onto the Dock icon (URLs)
    public func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            GameLibrary.shared.importGame(from: url)
        }
    }
    
    /// Handle files opened via Finder "Open With" (file paths)
    public func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for path in filenames {
            let url = URL(fileURLWithPath: path)
            GameLibrary.shared.importGame(from: url)
        }
        sender.reply(toOpenOrPrint: .success)
    }
    
    private func setupDirectoriesAndServer() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let baseDir = appSupport.appendingPathComponent("MacArcade", isDirectory: true)
        let gamesDir = baseDir.appendingPathComponent("Games", isDirectory: true)
        let thumbsDir = baseDir.appendingPathComponent("Thumbnails", isDirectory: true)
        
        try? fileManager.createDirectory(at: gamesDir, withIntermediateDirectories: true, attributes: nil)
        try? fileManager.createDirectory(at: thumbsDir, withIntermediateDirectories: true, attributes: nil)
        
        ArcadeServer.shared.gamesDirectoryURL = gamesDir
        ArcadeServer.shared.thumbnailsDirectoryURL = thumbsDir
        
        // Locate bundled Ruffle and BuiltInGames
        if let bundleRuffle = Bundle.main.url(forResource: "Ruffle", withExtension: nil) ??
                                Bundle.main.resourceURL?.appendingPathComponent("Ruffle") {
            ArcadeServer.shared.ruffleDirectoryURL = bundleRuffle
        }
        
        if let bundleBuiltIn = Bundle.main.url(forResource: "BuiltInGames", withExtension: nil) ??
                                Bundle.main.resourceURL?.appendingPathComponent("BuiltInGames") {
            ArcadeServer.shared.builtInGamesDirectoryURL = bundleBuiltIn
        }
        
        // Start local server
        do {
            try ArcadeServer.shared.start()
        } catch {
            NSLog("[AppDelegate] Failed to start ArcadeServer: %@", error.localizedDescription)
        }
    }
}
