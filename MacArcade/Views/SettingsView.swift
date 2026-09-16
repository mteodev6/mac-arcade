//
//  SettingsView.swift
//  MacArcade
//
//  Created for MacArcade.
//

import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var settings: ArcadeSettings
    @ObservedObject var library: GameLibrary
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))
                    Text("ARCADE PREFERENCES")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(.white)
                }
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
            
            TabView {
                // Cabinet & Video Tab
                videoSettingsTab
                    .tabItem {
                        Label("Cabinet & Display", systemImage: "tv")
                    }
                
                // Audio Tab
                audioSettingsTab
                    .tabItem {
                        Label("Audio & Sound", systemImage: "speaker.wave.2")
                    }
                
                // Library & Storage Tab
                storageSettingsTab
                    .tabItem {
                        Label("Library & Games", systemImage: "folder")
                    }
            }
            .padding(20)
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.0, green: 0.75, blue: 0.9))
            }
            .padding(16)
            .background(Color(red: 0.06, green: 0.07, blue: 0.14))
        }
        .frame(width: 520, height: 440)
        .background(Color(red: 0.04, green: 0.05, blue: 0.1))
    }
    
    private var videoSettingsTab: some View {
        Form {
            Section(header: Text("Cabinet Bezel Frame")) {
                Picker("Cabinet Frame Style", selection: $settings.bezelMode) {
                    ForEach(BezelMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                
                TextField("Cabinet Marquee Text", text: $settings.cabinetMarqueeText)
            }
            
            Section(header: Text("CRT Simulation Effects")) {
                Toggle("Enable CRT Scanline Effect", isOn: $settings.crtScanlinesEnabled)
                
                if settings.crtScanlinesEnabled {
                    Slider(value: $settings.crtScanlineOpacity, in: 0.2...1.0) {
                        Text("Scanline Intensity")
                    }
                    
                    Toggle("Phosphor Tube Corner Vignette", isOn: $settings.crtGlowEnabled)
                }
            }
            
            Section(header: Text("Default Aspect Ratio")) {
                Picker("Aspect Ratio", selection: $settings.defaultAspectRatio) {
                    ForEach(GameAspectRatio.allCases) { ratio in
                        Text(ratio.displayName).tag(ratio)
                    }
                }
            }
        }
    }
    
    private var audioSettingsTab: some View {
        Form {
            Section(header: Text("Sound & Volume")) {
                Slider(value: $settings.soundVolume, in: 0.0...1.0) {
                    Text("Master Volume")
                }
                
                Toggle("Mute Audio by Default", isOn: $settings.soundMuted)
                Toggle("25¢ Coin Insert Sound Effect", isOn: $settings.coinSoundEnabled)
            }
        }
    }
    
    private var storageSettingsTab: some View {
        Form {
            Section(header: Text("Storage Location")) {
                Button("Show Games Folder in Finder") {
                    if let url = FileImportService.shared.gamesDirectoryURL {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
                
                Button("Reinstall Built-in Sample Games") {
                    library.installBuiltInGamesIfNeeded()
                }
            }
            
            Section(header: Text("About MacArcade")) {
                Text("Native macOS Arcade & Flash Player")
                    .font(.headline)
                Text("Runs Adobe Flash SWFs via embedded Ruffle WebAssembly emulator and modern HTML5 games via WebKit.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
