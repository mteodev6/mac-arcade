import Foundation
import Darwin
import UniformTypeIdentifiers

/// A small HTTP server bound only to 127.0.0.1. Serving games over a real local
/// origin lets WKWebView load HTML assets and Ruffle's WebAssembly files reliably,
/// without requiring an internet connection or weakening file:// origin rules.
final class LocalGameServer {
    private struct Request {
        let method: String
        let target: String
        let headers: [String: String]
    }

    private struct Response {
        var status: Int
        var reason: String
        var contentType: String
        var data: Data
        var headers: [String: String] = [:]
    }

    private enum ServerError: LocalizedError {
        case socket(String)
        case bind(String)
        case listen(String)
        case portUnavailable
        case runtimeMissing

        var errorDescription: String? {
            switch self {
            case .socket(let message): return "Could not create the local game server socket: \(message)"
            case .bind(let message): return "Could not bind the local game server: \(message)"
            case .listen(let message): return "Could not start listening for local game requests: \(message)"
            case .portUnavailable: return "The local game server did not receive a usable port."
            case .runtimeMissing: return "The bundled Ruffle player is missing. Re-open the MacArcade Xcode project and build it again."
            }
        }
    }

    private let gamesDirectoryURL: URL
    private let ruffleDirectoryURL: URL
    private let listenerQueue = DispatchQueue(label: "com.macarcade.local-game-server.listener", qos: .userInitiated)
    private let clientsQueue = DispatchQueue(label: "com.macarcade.local-game-server.clients", qos: .userInitiated, attributes: .concurrent)
    private let stateLock = NSLock()
    private var listenerDescriptor: Int32 = -1
    private var isRunning = false
    private(set) var port: UInt16?

    private let allowedRuffleFiles: Set<String> = [
        "ruffle.js",
        "core.ruffle.c80159b526e567babaf5.js",
        "core.ruffle.f000070ea72f8ae4fe3a.js",
        "72a20ef1c0b8ceb37720.wasm",
        "826bb0938097485a2c9d.wasm"
    ]

    init(gamesDirectoryURL: URL, ruffleDirectoryURL: URL) {
        self.gamesDirectoryURL = gamesDirectoryURL
        self.ruffleDirectoryURL = ruffleDirectoryURL
    }

    deinit {
        stop()
    }

    func start(preferredPort: UInt16? = nil) throws {
        let runtimeIsPresent = allowedRuffleFiles.allSatisfy {
            FileManager.default.fileExists(atPath: ruffleDirectoryURL.appendingPathComponent($0).path)
        }
        guard runtimeIsPresent else { throw ServerError.runtimeMissing }

        let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw ServerError.socket(String(cString: strerror(errno)))
        }

        var reuseAddress: Int32 = 1
        _ = withUnsafePointer(to: &reuseAddress) {
            Darwin.setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, $0, socklen_t(MemoryLayout<Int32>.size))
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = preferredPort.map { in_port_t($0).bigEndian } ?? 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            let message = String(cString: strerror(errno))
            Darwin.close(descriptor)
            if preferredPort != nil {
                // Keep a stable port (and game browser storage) when possible;
                // fall back to an ephemeral port if another process owns it.
                try start(preferredPort: nil)
                return
            }
            throw ServerError.bind(message)
        }

        guard Darwin.listen(descriptor, SOMAXCONN) == 0 else {
            let message = String(cString: strerror(errno))
            Darwin.close(descriptor)
            throw ServerError.listen(message)
        }

        var boundAddress = sockaddr_in()
        var addressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.getsockname(descriptor, $0, &addressLength)
            }
        }
        guard nameResult == 0 else {
            Darwin.close(descriptor)
            throw ServerError.portUnavailable
        }

        let assignedPort = UInt16(bigEndian: boundAddress.sin_port)
        guard assignedPort != 0 else {
            Darwin.close(descriptor)
            throw ServerError.portUnavailable
        }

        stateLock.lock()
        listenerDescriptor = descriptor
        isRunning = true
        port = assignedPort
        stateLock.unlock()

        listenerQueue.async { [weak self] in
            self?.acceptConnections(on: descriptor)
        }
    }

    func stop() {
        stateLock.lock()
        let descriptor = listenerDescriptor
        listenerDescriptor = -1
        isRunning = false
        port = nil
        stateLock.unlock()

        guard descriptor >= 0 else { return }
        _ = Darwin.shutdown(descriptor, SHUT_RDWR)
        _ = Darwin.close(descriptor)
    }

    func url(for game: ArcadeGame) -> URL? {
        guard let port else { return nil }
        let origin = "http://127.0.0.1:\(port)"
        let gameID = game.id.uuidString.lowercased()

        switch game.format {
        case .html:
            let path = game.entryFile
                .split(separator: "/", omittingEmptySubsequences: false)
                .map { Self.encodePathComponent(String($0)) }
                .joined(separator: "/")
            return URL(string: "\(origin)/games/\(gameID)/\(path)")
        case .flash:
            guard var components = URLComponents(string: "\(origin)/_player/\(gameID)") else { return nil }
            components.queryItems = [URLQueryItem(name: "file", value: game.entryFile)]
            return components.url
        }
    }

    private func acceptConnections(on listener: Int32) {
        while isServerRunning(on: listener) {
            let client = Darwin.accept(listener, nil, nil)
            if client < 0 {
                if errno == EINTR { continue }
                if !isServerRunning(on: listener) { break }
                break
            }

            clientsQueue.async { [weak self] in
                self?.serve(client)
            }
        }
    }

    private func isServerRunning(on descriptor: Int32) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return isRunning && listenerDescriptor == descriptor
    }

    private func serve(_ client: Int32) {
        defer {
            _ = Darwin.shutdown(client, SHUT_RDWR)
            _ = Darwin.close(client)
        }

        var noSigPipe: Int32 = 1
        _ = withUnsafePointer(to: &noSigPipe) {
            Darwin.setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, $0, socklen_t(MemoryLayout<Int32>.size))
        }

        guard let request = readRequest(from: client) else {
            write(Response(status: 400, reason: "Bad Request", contentType: "text/plain; charset=utf-8", data: Data("Bad Request".utf8)), to: client, method: "GET")
            return
        }

        let response = makeResponse(for: request)
        write(response, to: client, method: request.method)
    }

    private func readRequest(from descriptor: Int32) -> Request? {
        let endOfHeaders = Data([13, 10, 13, 10])
        var received = Data()

        while received.count < 65_536 && received.range(of: endOfHeaders) == nil {
            var buffer = [UInt8](repeating: 0, count: 8_192)
            let count = buffer.withUnsafeMutableBytes { bytes -> Int in
                guard let address = bytes.baseAddress else { return -1 }
                return Darwin.recv(descriptor, address, bytes.count, 0)
            }

            if count < 0 {
                if errno == EINTR { continue }
                return nil
            }
            if count == 0 { return nil }
            received.append(contentsOf: buffer.prefix(count))
        }

        guard let separator = received.range(of: endOfHeaders),
              let headerText = String(data: received[..<separator.lowerBound], encoding: .utf8) else {
            return nil
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let components = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard components.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { headers[name] = value }
        }

        return Request(method: String(components[0]).uppercased(), target: String(components[1]), headers: headers)
    }

    private func makeResponse(for request: Request) -> Response {
        guard request.method == "GET" || request.method == "HEAD" else {
            return Response(status: 405, reason: "Method Not Allowed", contentType: "text/plain; charset=utf-8", data: Data("Method Not Allowed".utf8), headers: ["Allow": "GET, HEAD"])
        }
        guard request.target.hasPrefix("/"), !request.target.hasPrefix("//"),
              let components = URLComponents(string: "http://127.0.0.1\(request.target)") else {
            return notFound()
        }

        let rawSegments = components.percentEncodedPath
            .split(separator: "/", omittingEmptySubsequences: true)
        var segments: [String] = []
        for rawSegment in rawSegments {
            guard let decoded = String(rawSegment).removingPercentEncoding,
                  isSafePathComponent(decoded) else {
                return forbidden()
            }
            segments.append(decoded)
        }

        guard let first = segments.first else { return notFound() }
        if first == "_ruffle" {
            guard segments.count == 2, allowedRuffleFiles.contains(segments[1]) else { return notFound() }
            return fileResponse(at: ruffleDirectoryURL.appendingPathComponent(segments[1]))
        }

        if first == "_player" {
            guard segments.count == 2, let gameID = UUID(uuidString: segments[1]),
                  let relativeFile = components.queryItems?.first(where: { $0.name == "file" })?.value,
                  let fileParts = safeRelativePathComponents(relativeFile),
                  fileParts.last?.lowercased().hasSuffix(".swf") == true,
                  safeFileURL(in: gameDirectory(for: gameID), pathComponents: fileParts) != nil else {
                return notFound()
            }

            let normalizedID = gameID.uuidString.lowercased()
            let encodedFile = fileParts.map(Self.encodePathComponent).joined(separator: "/")
            let moviePath = "/games/\(normalizedID)/\(encodedFile)"
            let gameBasePath = "/games/\(normalizedID)/"
            let html = playerDocument(moviePath: moviePath, basePath: gameBasePath)
            return Response(status: 200, reason: "OK", contentType: "text/html; charset=utf-8", data: Data(html.utf8), headers: ["Cache-Control": "no-store"])
        }

        if first == "games" {
            guard segments.count >= 3, let gameID = UUID(uuidString: segments[1]) else { return notFound() }
            let relativeParts = Array(segments.dropFirst(2))
            guard let fileURL = safeFileURL(in: gameDirectory(for: gameID), pathComponents: relativeParts) else { return notFound() }
            return fileResponse(at: fileURL, rangeHeader: request.headers["range"])
        }

        return notFound()
    }

    private func fileResponse(at url: URL, rangeHeader: String? = nil) -> Response {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return notFound() }
        var response = Response(status: 200, reason: "OK", contentType: Self.mimeType(for: url), data: data)
        response.headers["Accept-Ranges"] = "bytes"
        response.headers["Cache-Control"] = url.pathExtension.lowercased() == "wasm" || url.pathExtension.lowercased() == "js" ? "public, max-age=3600" : "no-store"

        guard let rangeHeader, let requestedRange = Self.byteRange(from: rangeHeader, dataLength: data.count) else {
            if rangeHeader != nil {
                return Response(status: 416, reason: "Range Not Satisfiable", contentType: "text/plain; charset=utf-8", data: Data(), headers: ["Content-Range": "bytes */\(data.count)", "Accept-Ranges": "bytes"])
            }
            return response
        }

        response.status = 206
        response.reason = "Partial Content"
        response.data = data.subdata(in: requestedRange)
        response.headers["Content-Range"] = "bytes \(requestedRange.lowerBound)-\(requestedRange.upperBound - 1)/\(data.count)"
        return response
    }

    private func safeFileURL(in root: URL, pathComponents: [String]) -> URL? {
        guard !pathComponents.isEmpty,
              pathComponents.allSatisfy(isSafePathComponent) else { return nil }

        var candidate = root
        for component in pathComponents {
            candidate.appendPathComponent(component, isDirectory: false)
        }
        candidate = candidate.standardizedFileURL.resolvingSymlinksInPath()

        let resolvedRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let rootPath = resolvedRoot.path.hasSuffix("/") ? resolvedRoot.path : resolvedRoot.path + "/"
        guard candidate.path.hasPrefix(rootPath) else { return nil }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory) else { return nil }
        if isDirectory.boolValue {
            candidate.appendPathComponent("index.html", isDirectory: false)
            candidate = candidate.standardizedFileURL.resolvingSymlinksInPath()
            guard candidate.path.hasPrefix(rootPath), FileManager.default.fileExists(atPath: candidate.path) else { return nil }
        }
        return candidate
    }

    private func gameDirectory(for id: UUID) -> URL {
        gamesDirectoryURL.appendingPathComponent(id.uuidString.lowercased(), isDirectory: true)
    }

    private func isSafePathComponent(_ component: String) -> Bool {
        !component.isEmpty && component != "." && component != ".." &&
        !component.contains("/") && !component.contains("\\") && !component.contains("\0")
    }

    private func safeRelativePathComponents(_ path: String) -> [String]? {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\") else { return nil }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !parts.isEmpty, parts.allSatisfy(isSafePathComponent) else { return nil }
        return parts
    }

    private func playerDocument(moviePath: String, basePath: String) -> String {
        let movieJSON = Self.jsonString(moviePath)
        let baseJSON = Self.jsonString(basePath)
        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
          <meta name="color-scheme" content="dark">
          <title>Mac Arcade Flash Player</title>
          <style>
            html, body, #stage { width: 100%; height: 100%; margin: 0; overflow: hidden; }
            body { background: #090b10; color: #e8eaf2; font: 14px -apple-system, BlinkMacSystemFont, sans-serif; }
            #stage { display: flex; align-items: center; justify-content: center; }
            ruffle-player { display: block; width: 100%; height: 100%; }
            #message { position: absolute; inset: auto 20px 18px; text-align: center; color: #a9adbc; pointer-events: none; }
            #error { display: none; max-width: 560px; padding: 22px; border: 1px solid #49333a; border-radius: 14px; background: #1b1419; color: #ffd4dc; line-height: 1.5; }
          </style>
          <script>
            window.RufflePlayer = window.RufflePlayer || {};
            window.RufflePlayer.config = {
              autoplay: "on",
              unmuteOverlay: "visible",
              letterbox: "on",
              backgroundColor: "#090b10",
              allowScriptAccess: true,
              showSwfDownload: false,
              warnOnUnsupportedContent: true
            };
          </script>
          <script src="/_ruffle/ruffle.js"></script>
        </head>
        <body>
          <main id="stage"><div id="error" role="alert"></div></main>
          <script>
            const moviePath = \(movieJSON);
            const movieBase = \(baseJSON);
            const showError = (message) => {
              const panel = document.getElementById("error");
              panel.textContent = message;
              panel.style.display = "block";
            };
            window.addEventListener("DOMContentLoaded", async () => {
              try {
                if (!window.RufflePlayer || !window.RufflePlayer.newest) {
                  throw new Error("The bundled Flash player could not be loaded.");
                }
                const player = window.RufflePlayer.newest().createPlayer();
                player.style.width = "100%";
                player.style.height = "100%";
                document.getElementById("stage").appendChild(player);
                await player.ruffle().load({
                  url: moviePath,
                  base: movieBase,
                  autoplay: "on",
                  letterbox: "on",
                  backgroundColor: "#090b10",
                  warnOnUnsupportedContent: true
                });
              } catch (error) {
                showError("This SWF could not be started. It may use Flash features that Ruffle does not yet support. " + (error && error.message ? error.message : ""));
              }
            });
          </script>
        </body>
        </html>
        """
    }

    private func notFound() -> Response {
        Response(status: 404, reason: "Not Found", contentType: "text/plain; charset=utf-8", data: Data("Not Found".utf8))
    }

    private func forbidden() -> Response {
        Response(status: 403, reason: "Forbidden", contentType: "text/plain; charset=utf-8", data: Data("Forbidden".utf8))
    }

    private func write(_ response: Response, to descriptor: Int32, method: String) {
        var headers = [
            "HTTP/1.1 \(response.status) \(response.reason)",
            "Content-Type: \(response.contentType)",
            "Content-Length: \(response.data.count)",
            "Connection: close",
            "X-Content-Type-Options: nosniff",
            "Referrer-Policy: no-referrer"
        ]
        for (name, value) in response.headers {
            headers.append("\(name): \(value)")
        }
        headers.append("")
        headers.append("")
        send(Data(headers.joined(separator: "\r\n").utf8), to: descriptor)
        if method != "HEAD" && !response.data.isEmpty {
            send(response.data, to: descriptor)
        }
    }

    private func send(_ data: Data, to descriptor: Int32) {
        data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            var sent = 0
            while sent < bytes.count {
                let result = Darwin.send(descriptor, baseAddress.advanced(by: sent), bytes.count - sent, 0)
                if result < 0 {
                    if errno == EINTR { continue }
                    break
                }
                if result == 0 { break }
                sent += result
            }
        }
    }

    private static func encodePathComponent(_ component: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return component.addingPercentEncoding(withAllowedCharacters: allowed) ?? component
    }

    private static func jsonString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value], options: []),
              let json = String(data: data, encoding: .utf8), json.count >= 2 else {
            return "\"\""
        }
        return String(json.dropFirst().dropLast())
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "js", "mjs": return "text/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "wasm": return "application/wasm"
        case "json", "map": return "application/json; charset=utf-8"
        case "svg": return "image/svg+xml"
        case "swf": return "application/x-shockwave-flash"
        default:
            return UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        }
    }

    private static func byteRange(from header: String, dataLength: Int) -> Range<Int>? {
        guard dataLength > 0,
              header.lowercased().hasPrefix("bytes="),
              !header.contains(",") else { return nil }
        let value = String(header.dropFirst("bytes=".count))
        let bounds = value.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard bounds.count == 2 else { return nil }

        if bounds[0].isEmpty {
            guard let suffixLength = Int(bounds[1]), suffixLength > 0 else { return nil }
            let start = max(0, dataLength - suffixLength)
            return start..<dataLength
        }

        guard let start = Int(bounds[0]), start >= 0, start < dataLength else { return nil }
        let end: Int
        if bounds[1].isEmpty {
            end = dataLength - 1
        } else if let requestedEnd = Int(bounds[1]), requestedEnd >= start {
            end = min(requestedEnd, dataLength - 1)
        } else {
            return nil
        }
        return start..<(end + 1)
    }
}
