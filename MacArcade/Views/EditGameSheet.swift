//
//  EditGameSheet.swift
//  MacArcade
//
//  Created for MacArcade.
//

import SwiftUI

public struct EditGameSheet: View {
    @ObservedObject var library: GameLibrary
    public let game: Game
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var category: GameCategory
    @State private var aspectRatio: GameAspectRatio
    @State private var notes: String
    @State private var accentHex: String
    
    public init(library: GameLibrary, game: Game) {
        self.library = library
        self.game = game
        _title = State(initialValue: game.title)
        _category = State(initialValue: game.category)
        _aspectRatio = State(initialValue: game.customAspectRatio)
        _notes = State(initialValue: game.notes)
        _accentHex = State(initialValue: game.accentColorHex)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("EDIT GAME DETAILS")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(Color(red: 0.06, green: 0.07, blue: 0.14))
            
            Divider()
            
            Form {
                Section {
                    TextField("Title", text: $title)
                    Picker("Category", selection: $category) {
                        ForEach(GameCategory.allCases.filter { $0 != .all }) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    Picker("Aspect Ratio", selection: $aspectRatio) {
                        ForEach(GameAspectRatio.allCases) { ratio in
                            Text(ratio.displayName).tag(ratio)
                        }
                    }
                }
                
                Section(header: Text("Notes & Key Controls")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .padding(18)
            
            Divider()
            
            // Footer
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Save Changes") {
                    var updated = game
                    updated.title = title
                    updated.category = category
                    updated.customAspectRatio = aspectRatio
                    updated.notes = notes
                    library.updateGame(updated)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.0, green: 0.75, blue: 0.9))
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
            .background(Color(red: 0.06, green: 0.07, blue: 0.14))
        }
        .frame(width: 480, height: 420)
        .background(Color(red: 0.04, green: 0.05, blue: 0.1))
    }
}
