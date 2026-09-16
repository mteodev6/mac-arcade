//
//  AddGameSheet.swift
//  MacArcade
//
//  Created for MacArcade.
//

import SwiftUI
import AppKit

public struct AddGameSheet: View {
    @ObservedObject var library: GameLibrary
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFileURL: URL?
    @State private var gameTitle: String = ""
    @State private var selectedCategory: GameCategory = .arcade
    @State private var selectedAspectRatio: GameAspectRatio = .auto
    @State private var notes: String = ""
    @State private var isTargeted = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))
                        .font(.system(size: 20))
                    
                    Text("ADD GAME TO ARCADE")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(.white)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(red: 0.06, green: 0.07, blue: 0.14))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Drop Zone / File Picker Box
                    VStack(spacing: 12) {
                        if let url = selectedFileURL {
                            HStack(spacing: 14) {
                                Image(systemName: iconForURL(url))
                                    .font(.system(size: 32))
                                    .foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(url.lastPathComponent)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(url.pathExtension.uppercased() + " Game File")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("Change") {
                                    openFilePicker()
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.08, green: 0.12, blue: 0.22)))
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "arrow.down.doc.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))
                                
                                Text("DRAG & DROP GAME FILE HERE")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                
                                Text("Supports Flash (.swf), HTML5 (.html), and game zip archives (.zip)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                
                                Button("Choose File...") {
                                    openFilePicker()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color(red: 0.0, green: 0.75, blue: 0.9))
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.07, green: 0.08, blue: 0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                isTargeted ? Color(red: 0.0, green: 0.95, blue: 1.0) : Color.white.opacity(0.15),
                                                style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                                            )
                                    )
                            )
                            .onDrop(of: ["public.file-url"], isTargeted: $isTargeted) { providers in
                                handleDrop(providers: providers)
                            }
                        }
                    }
                    
                    // Metadata Inputs
                    VStack(alignment: .leading, spacing: 14) {
                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            Text("GAME TITLE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                            
                            TextField("Enter game title", text: $gameTitle)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        // Category & Aspect Ratio
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("CATEGORY")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: $selectedCategory) {
                                    ForEach(GameCategory.allCases.filter { $0 != .all }) { cat in
                                        Text(cat.displayName).tag(cat)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ASPECT RATIO")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: $selectedAspectRatio) {
                                    ForEach(GameAspectRatio.allCases) { ratio in
                                        Text(ratio.displayName).tag(ratio)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        
                        // Notes & Controls
                        VStack(alignment: .leading, spacing: 6) {
                            Text("HOW TO PLAY & KEY CONTROLS (OPTIONAL)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $notes)
                                .font(.system(size: 12))
                                .frame(height: 70)
                                .padding(4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                    }
                    
                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Bottom Action Bar
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: saveGame) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("ADD TO LIBRARY")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedFileURL != nil && !gameTitle.isEmpty ? Color(red: 0.0, green: 0.95, blue: 1.0) : Color.gray.opacity(0.4))
                    )
                }
                .buttonStyle(.plain)
                .disabled(selectedFileURL == nil || gameTitle.trimmingCharacters(in: .whitespaces).isEmpty || isProcessing)
            }
            .padding(16)
            .background(Color(red: 0.06, green: 0.07, blue: 0.14))
        }
        .frame(width: 520, height: 530)
        .background(Color(red: 0.04, green: 0.05, blue: 0.1))
    }
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = []
        panel.prompt = "Select Game"
        
        if panel.runModal() == .OK, let url = panel.url {
            selectURL(url)
        }
    }
    
    private func selectURL(_ url: URL) {
        selectedFileURL = url
        let detected = FileImportService.shared.cleanTitle(from: url.deletingPathExtension().lastPathComponent)
        if gameTitle.isEmpty {
            gameTitle = detected
        }
        if url.pathExtension.lowercased() == "swf" {
            selectedCategory = .flash
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
            guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                self.selectURL(url)
            }
        }
        return true
    }
    
    private func iconForURL(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ext == "swf" { return "bolt.shield.fill" }
        if ext == "zip" { return "archivebox.fill" }
        return "globe"
    }
    
    private func saveGame() {
        guard let url = selectedFileURL else { return }
        isProcessing = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var game = try FileImportService.shared.importGame(
                    from: url,
                    customTitle: gameTitle,
                    category: selectedCategory
                )
                game.notes = notes
                game.customAspectRatio = selectedAspectRatio
                
                DispatchQueue.main.async {
                    library.games.insert(game, at: 0)
                    library.selectedGameId = game.id
                    library.saveLibrary()
                    isProcessing = false
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                }
            }
        }
    }
}
