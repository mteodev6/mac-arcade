//
//  ArcadeServer.swift
//  MacArcade
//
//  Created for MacArcade.
//

import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Lightweight embedded HTTP/1.1 server running on 127.0.0.1.
/// Serves HTML5 games, Adobe Flash SWFs, and Ruffle WebAssembly assets
/// cleanly to WKWebView without CORS, sandbox, or file:// SOP issues.
public final class ArcadeServer {
    public static let shared = ArcadeServer()
    
    private var serverSocket: Int32 = -1
    public private(set) var port: UInt16 = 0
    public private(set) var isRunning: Bool = false
    
    private let queue = DispatchQueue(label: "com.macarcade.server.accept", qos: .userInteractive)
    private let workerQueue = DispatchQueue(label: "com.macarcade.server.worker", attributes: .concurrent)
    
    public var gamesDirectoryURL: URL?
    public var thumbnailsDirectoryURL: URL?
    public var ruffleDirectoryURL: URL?
    public var builtInGamesDirectoryURL: URL?
    
    public init() {}
    
    /// Starts the local HTTP server on a random free port on loopback (127.0.0.1)
    public func start() throws {
        guard !isRunning else { return }
        
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw NSError(domain: "ArcadeServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create socket"])
        }
        
        var opt: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))
        #if canImport(Darwin)
        setsockopt(serverSocket, SOL_SOCKET, SO_NOSIGPIPE, &opt, socklen_t(MemoryLayout<Int32>.size))
        #endif
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0 // Ephemeral port
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard bindResult == 0 else {
            close(serverSocket)
            serverSocket = -1
            throw NSError(domain: "ArcadeServer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to bind socket"])
        }
        
        guard listen(serverSocket, 64) == 0 else {
            close(serverSocket)
            serverSocket = -1
            throw NSError(domain: "ArcadeServer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to listen on socket"])
        }
        
        var assignedAddr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &assignedAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(serverSocket, $0, &len)
            }
        }
        self.port = UInt16(bigEndian: assignedAddr.sin_port)
        self.isRunning = true
        
        NSLog("[ArcadeServer] Server running on http://127.0.0.1:%d", self.port)
        
        queue.async { [weak self] in
            self?.acceptLoop()
        }
    }
    
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        if serverSocket >= 0 {
            #if canImport(Darwin)
            Darwin.shutdown(serverSocket, SHUT_RDWR)
            #endif
            close(serverSocket)
            serverSocket = -1
        }
    }
    
    private func acceptLoop() {
        while isRunning {
            var clientAddr = sockaddr_in()
            var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(serverSocket, $0, &clientLen)
                }
            }
            
            guard clientSocket >= 0 else {
                if !isRunning { break }
                continue
            }
            
            #if canImport(Darwin)
            var opt: Int32 = 1
            setsockopt(clientSocket, SOL_SOCKET, SO_NOSIGPIPE, &opt, socklen_t(MemoryLayout<Int32>.size))
            #endif
            
            workerQueue.async { [weak self] in
                self?.handleClient(clientSocket)
            }
        }
    }
    
    private func handleClient(_ clientSocket: Int32) {
        defer {
            close(clientSocket)
        }
        
        var buffer = [UInt8](repeating: 0, count: 8192)
        let bytesRead = recv(clientSocket, &buffer, buffer.count - 1, 0)
        guard bytesRead > 0 else { return }
        buffer[bytesRead] = 0
        
        guard let requestString = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? String(bytes: buffer[0..<bytesRead], encoding: .isoLatin1) else {
            sendResponse(clientSocket, statusCode: 400, statusText: "Bad Request", headers: [:], body: Data("Bad Request".utf8))
            return
        }
        
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first, !requestLine.isEmpty else { return }
        
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return }
        let method = parts[0]
        let rawUri = parts[1]
        
        // Parse headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            if let colonIdx = line.firstIndex(of: ":") {
                let name = String(line[..<colonIdx]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                headers[name] = value
            }
        }
        
        if method == "OPTIONS" {
            var corsHeaders = [
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
                "Access-Control-Allow-Headers": "*"
            ]
            sendResponse(clientSocket, statusCode: 200, statusText: "OK", headers: corsHeaders, body: Data())
            return
        }
        
        guard method == "GET" || method == "HEAD" else {
            sendResponse(clientSocket, statusCode: 405, statusText: "Method Not Allowed", headers: [:], body: Data())
            return
        }
        
        // Extract path (strip query params)
        let pathOnly = rawUri.components(separatedBy: "?").first ?? "/"
        guard let decodedPath = pathOnly.removingPercentEncoding else {
            sendResponse(clientSocket, statusCode: 400, statusText: "Bad Request", headers: [:], body: Data())
            return
        }
        
        resolveAndServe(clientSocket: clientSocket, path: decodedPath, rangeHeader: headers["range"], isHeadOnly: method == "HEAD")
    }
    
    private func resolveAndServe(clientSocket: Int32, path: String, rangeHeader: String?, isHeadOnly: Bool) {
        // Prevent path traversal
        if path.contains("..") {
            sendResponse(clientSocket, statusCode: 403, statusText: "Forbidden", headers: [:], body: Data("Forbidden".utf8))
            return
        }
        
        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        var targetFileURL: URL?
        
        // 1. Ruffle files: /ruffle/... or /player.html
        if trimmedPath == "player.html" {
            if let ruffleDir = ruffleDirectoryURL {
                targetFileURL = ruffleDir.appendingPathComponent("player.html")
            }
        } else if trimmedPath.hasPrefix("ruffle/") {
            let subpath = String(trimmedPath.dropFirst("ruffle/".count))
            if let ruffleDir = ruffleDirectoryURL {
                targetFileURL = ruffleDir.appendingPathComponent(subpath)
            }
        }
        // 2. Thumbnails: /thumbnails/...
        else if trimmedPath.hasPrefix("thumbnails/") {
            let filename = String(trimmedPath.dropFirst("thumbnails/".count))
            if let thumbDir = thumbnailsDirectoryURL {
                targetFileURL = thumbDir.appendingPathComponent(filename)
            }
        }
        // 3. User & Built-in Games: /games/...
        else if trimmedPath.hasPrefix("games/") {
            let subpath = String(trimmedPath.dropFirst("games/".count))
            
            // First check user games directory
            if let gamesDir = gamesDirectoryURL {
                let candidate = gamesDir.appendingPathComponent(subpath)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    targetFileURL = candidate
                }
            }
            
            // If not found, check built-in games directory
            if targetFileURL == nil, let builtInDir = builtInGamesDirectoryURL {
                let candidate = builtInDir.appendingPathComponent(subpath)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    targetFileURL = candidate
                }
            }
        }
        // Direct root fallback for Ruffle wasm chunks if requested without /ruffle/ prefix
        else if trimmedPath.hasSuffix(".wasm") || trimmedPath.hasPrefix("core.ruffle.") {
            if let ruffleDir = ruffleDirectoryURL {
                let candidate = ruffleDir.appendingPathComponent(trimmedPath)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    targetFileURL = candidate
                }
            }
        }
        
        guard let fileURL = targetFileURL, FileManager.default.fileExists(atPath: fileURL.path) else {
            sendResponse(clientSocket, statusCode: 404, statusText: "Not Found", headers: [:], body: Data("File Not Found: \(path)".utf8))
            return
        }
        
        // Check if directory - if so, look for index.html
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), isDir.boolValue {
            let indexCandidate = fileURL.appendingPathComponent("index.html")
            if FileManager.default.fileExists(atPath: indexCandidate.path) {
                serveFile(clientSocket: clientSocket, fileURL: indexCandidate, rangeHeader: rangeHeader, isHeadOnly: isHeadOnly)
                return
            } else {
                sendResponse(clientSocket, statusCode: 403, statusText: "Directory Listing Denied", headers: [:], body: Data())
                return
            }
        }
        
        serveFile(clientSocket: clientSocket, fileURL: fileURL, rangeHeader: rangeHeader, isHeadOnly: isHeadOnly)
    }
    
    private func serveFile(clientSocket: Int32, fileURL: URL, rangeHeader: String?, isHeadOnly: Bool) {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard let fileSize = attributes[.size] as? Int64 else {
                sendResponse(clientSocket, statusCode: 500, statusText: "Internal Server Error", headers: [:], body: Data())
                return
            }
            
            let mimeType = mimeType(for: fileURL.pathExtension)
            var responseHeaders: [String: String] = [
                "Content-Type": mimeType,
                "Access-Control-Allow-Origin": "*",
                "Accept-Ranges": "bytes",
                "Cache-Control": "no-cache"
            ]
            
            // Check for Range request
            if let rangeHeader = rangeHeader, rangeHeader.hasPrefix("bytes=") {
                let rangeSpec = String(rangeHeader.dropFirst("bytes=".count))
                let parts = rangeSpec.components(separatedBy: "-")
                if parts.count >= 1, let startInt = Int64(parts[0]) {
                    var endInt = fileSize - 1
                    if parts.count > 1, !parts[1].isEmpty, let reqEnd = Int64(parts[1]) {
                        endInt = min(reqEnd, fileSize - 1)
                    }
                    
                    let lengthToRead = endInt - startInt + 1
                    if lengthToRead > 0 && startInt < fileSize {
                        let handle = try FileHandle(forReadingFrom: fileURL)
                        try handle.seek(toOffset: UInt64(startInt))
                        let rangeData = handle.readData(ofLength: Int(lengthToRead))
                        try? handle.close()
                        
                        responseHeaders["Content-Range"] = "bytes \(startInt)-\(endInt)/\(fileSize)"
                        responseHeaders["Content-Length"] = "\(rangeData.count)"
                        
                        sendResponse(clientSocket, statusCode: 206, statusText: "Partial Content", headers: responseHeaders, body: isHeadOnly ? Data() : rangeData)
                        return
                    }
                }
            }
            
            // Full file read
            let fileData = try Data(contentsOf: fileURL)
            responseHeaders["Content-Length"] = "\(fileData.count)"
            sendResponse(clientSocket, statusCode: 200, statusText: "OK", headers: responseHeaders, body: isHeadOnly ? Data() : fileData)
        } catch {
            sendResponse(clientSocket, statusCode: 500, statusText: "Internal Error", headers: [:], body: Data(error.localizedDescription.utf8))
        }
    }
    
    private func sendResponse(_ socket: Int32, statusCode: Int, statusText: String, headers: [String: String], body: Data) {
        var headerString = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        for (k, v) in headers {
            headerString += "\(k): \(v)\r\n"
        }
        if headers["Content-Length"] == nil {
            headerString += "Content-Length: \(body.count)\r\n"
        }
        headerString += "Connection: close\r\n\r\n"
        
        let headerData = Data(headerString.utf8)
        headerData.withUnsafeBytes { rawBuffer in
            _ = send(socket, rawBuffer.baseAddress, rawBuffer.count, 0)
        }
        
        if !body.isEmpty {
            body.withUnsafeBytes { rawBuffer in
                _ = send(socket, rawBuffer.baseAddress, rawBuffer.count, 0)
            }
        }
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
        case "webp": return "image/webp"
        case "ico": return "image/x-icon"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "ogg": return "audio/ogg"
        case "mp4": return "video/mp4"
        case "webm": return "video/webm"
        case "txt": return "text/plain; charset=utf-8"
        case "sol": return "application/octet-stream"
        default: return "application/octet-stream"
        }
    }
}
