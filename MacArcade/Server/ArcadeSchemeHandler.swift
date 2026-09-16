//
//  ArcadeSchemeHandler.swift
//  MacArcade
//
//  Created for MacArcade.
//

import Foundation
import WebKit

/// Custom WKURLSchemeHandler supporting `arcade://` URLs directly inside WKWebView.
public class ArcadeSchemeHandler: NSObject, WKURLSchemeHandler {
    public static let scheme = "arcade"
    
    public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(NSError(domain: "ArcadeScheme", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        // Convert to local file resolution via ArcadeServer
        let path = url.path
        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        
        var targetFileURL: URL?
        if trimmedPath == "player.html" || trimmedPath.isEmpty {
            targetFileURL = ArcadeServer.shared.ruffleDirectoryURL?.appendingPathComponent("player.html")
        } else if trimmedPath.hasPrefix("ruffle/") {
            let sub = String(trimmedPath.dropFirst("ruffle/".count))
            targetFileURL = ArcadeServer.shared.ruffleDirectoryURL?.appendingPathComponent(sub)
        } else if trimmedPath.hasPrefix("games/") {
            let sub = String(trimmedPath.dropFirst("games/".count))
            if let userDir = ArcadeServer.shared.gamesDirectoryURL {
                let candidate = userDir.appendingPathComponent(sub)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    targetFileURL = candidate
                }
            }
            if targetFileURL == nil, let builtInDir = ArcadeServer.shared.builtInGamesDirectoryURL {
                let candidate = builtInDir.appendingPathComponent(sub)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    targetFileURL = candidate
                }
            }
        }
        
        guard let file = targetFileURL, FileManager.default.fileExists(atPath: file.path) else {
            urlSchemeTask.didFailWithError(NSError(domain: "ArcadeScheme", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found"]))
            return
        }
        
        do {
            let data = try Data(contentsOf: file)
            let mimeType = mimeType(for: file.pathExtension)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": mimeType,
                    "Content-Length": "\(data.count)",
                    "Access-Control-Allow-Origin": "*"
                ]
            )!
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }
    
    public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Nothing to abort for synchronous read
    }
    
    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "js", "mjs": return "application/javascript"
        case "wasm": return "application/wasm"
        case "swf": return "application/x-shockwave-flash"
        case "css": return "text/css; charset=utf-8"
        case "json": return "application/json"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        default: return "application/octet-stream"
        }
    }
}
