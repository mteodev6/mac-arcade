//
//  ZipExtractor.swift
//  MacArcade
//
//  Created for MacArcade.
//

import Foundation

public final class ZipExtractor {
    /// Extracts a zip file at sourceURL into destinationURL using macOS built-in unzip utility
    public static func unzip(sourceURL: URL, destinationURL: URL) throws {
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", "-o", sourceURL.path, "-d", destinationURL.path]
        
        let pipe = Pipe()
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unzip failed with exit code \(process.terminationStatus)"
            throw NSError(domain: "ZipExtractor", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
    }
}
