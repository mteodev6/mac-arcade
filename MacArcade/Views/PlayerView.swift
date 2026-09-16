//
//  PlayerView.swift
//  MacArcade
//
//  Created for MacArcade.
//

import SwiftUI
import WebKit
import AppKit

public class ArcadePlayerController: ObservableObject {
    public weak var webView: WKWebView?
    
    public init() {}
    
    public func pause() {
        webView?.evaluateJavaScript("if (typeof window.arcadePause === 'function') { window.arcadePause(); }", completionHandler: nil)
    }
    
    public func resume() {
        webView?.evaluateJavaScript("if (typeof window.arcadeResume === 'function') { window.arcadeResume(); }", completionHandler: nil)
    }
    
    public func restart(game: Game) {
        if game.type == .swf {
            webView?.evaluateJavaScript("if (typeof window.arcadeRestart === 'function') { window.arcadeRestart(); } else { location.reload(); }", completionHandler: nil)
        } else {
            webView?.reload()
        }
    }
    
    public func setMuted(_ muted: Bool) {
        let js = "if (typeof window.arcadeMute === 'function') { window.arcadeMute(\(muted)); }"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
    
    public func takeSnapshot(completion: @escaping (NSImage?) -> Void) {
        let config = WKSnapshotConfiguration()
        webView?.takeSnapshot(with: config) { image, _ in
            completion(image)
        }
    }
}

public struct PlayerView: View {
    public let game: Game
    @ObservedObject var library: GameLibrary
    @ObservedObject var settings: ArcadeSettings
    public let onExit: () -> Void
    
    @StateObject private var controller = ArcadePlayerController()
    @State private var isPaused = false
    @State private var sessionStartTime = Date()
    @State private var showControlsHUD = true
    @State private var hudTimer: Timer?
    @State private var isFullscreen = false
    
    public var body: some View {
        ZStack {
            // Main Cabinet Frame
            ArcadeCabinetBezel(game: game, settings: settings) {
                ZStack {
                    // Game Canvas (WKWebView container)
                    GeometryReader { geo in
                        let targetAspect = settings.defaultAspectRatio.ratioValue
                        
                        ZStack {
                            Color.black
                            
                            ArcadeWebViewRepresentable(
                                game: game,
                                controller: controller
                            )
                            .aspectRatio(targetAspect, contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            
                            // CRT Scanlines & Glow Overlay
                            if settings.crtScanlinesEnabled {
                                CRTShaderOverlay(
                                    opacity: settings.crtScanlineOpacity,
                                    showGlow: settings.crtGlowEnabled
                                )
                            }
                        }
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            
            // Floating Player HUD Controls
            VStack {
                if showControlsHUD {
                    PlayerControlsBar(
                        game: game,
                        settings: settings,
                        isPaused: $isPaused,
                        onBack: exitPlayer,
                        onRestart: restartGame,
                        onTogglePause: togglePause,
                        onToggleMute: toggleMute,
                        onTakeScreenshot: captureScreenshot,
                        onToggleFullscreen: toggleFullscreen
                    )
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
            }
        }
        .onAppear {
            sessionStartTime = Date()
            revealHUDTemporarily()
        }
        .onDisappear {
            let elapsed = Date().timeIntervalSince(sessionStartTime)
            library.recordPlaySession(for: game, duration: elapsed)
        }
        .onContinuousHover { _ in
            revealHUDTemporarily()
        }
    }
    
    // MARK: - Controls Actions
    
    private func exitPlayer() {
        let elapsed = Date().timeIntervalSince(sessionStartTime)
        library.recordPlaySession(for: game, duration: elapsed)
        onExit()
    }
    
    private func restartGame() {
        isPaused = false
        controller.restart(game: game)
    }
    
    private func togglePause() {
        isPaused.toggle()
        if isPaused {
            controller.pause()
        } else {
            controller.resume()
        }
    }
    
    private func toggleMute() {
        settings.soundMuted.toggle()
        controller.setMuted(settings.soundMuted)
    }
    
    private func captureScreenshot() {
        controller.takeSnapshot { image in
            guard let image = image else { return }
            var updated = game
            try? ThumbnailService.shared.saveThumbnail(image: image, for: &updated)
            library.updateGame(updated)
            NSSound.beep()
        }
    }
    
    private func toggleFullscreen() {
        isFullscreen.toggle()
        if let window = NSApplication.shared.windows.first {
            window.toggleFullScreen(nil)
        }
    }
    
    private func revealHUDTemporarily() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showControlsHUD = true
        }
        hudTimer?.invalidate()
        hudTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                if !isPaused {
                    showControlsHUD = false
                }
            }
        }
    }
}

// MARK: - NSViewRepresentable for WKWebView
struct ArcadeWebViewRepresentable: NSViewRepresentable {
    let game: Game
    let controller: ArcadePlayerController
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.preferences.setValue(true, forKey: "webGLEnabled")
        
        // Add custom scheme handler
        let schemeHandler = ArcadeSchemeHandler()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: ArcadeSchemeHandler.scheme)
        
        // Add script message handler for bridge
        let userContent = config.userContentController
        userContent.add(context.coordinator, name: "arcadeBridge")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        
        controller.webView = webView
        context.coordinator.loadGame(game, in: webView)
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKScriptMessageHandler {
        let parent: ArcadeWebViewRepresentable
        
        init(_ parent: ArcadeWebViewRepresentable) {
            self.parent = parent
        }
        
        func loadGame(_ game: Game, in webView: WKWebView) {
            let port = ArcadeServer.shared.port
            let baseURLString = "http://127.0.0.1:\(port)"
            
            let targetURL: URL
            if game.type == .swf {
                // Flash SWF: Route through Ruffle wrapper player.html
                let swfPath = "/games/\(game.directoryName)/\(game.entryPath)"
                var components = URLComponents(string: "\(baseURLString)/player.html")!
                components.queryItems = [
                    URLQueryItem(name: "swf", value: swfPath)
                ]
                targetURL = components.url!
            } else {
                // HTML5: Route directly to game entry file
                let cleanEntry = game.entryPath.hasPrefix("/") ? String(game.entryPath.dropFirst()) : game.entryPath
                let urlString = "\(baseURLString)/games/\(game.directoryName)/\(cleanEntry)"
                targetURL = URL(string: urlString) ?? URL(string: "\(baseURLString)/games/\(game.directoryName)/index.html")!
            }
            
            let request = URLRequest(url: targetURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            webView.load(request)
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "arcadeBridge", let body = message.body as? [String: Any] {
                let event = body["event"] as? String ?? ""
                NSLog("[ArcadeBridge] Received event: %@", event)
            }
        }
    }
}
