//
//  PlayerControlsBar.swift
//  MacArcade
//
//  Created for MacArcade.
//

import SwiftUI

public struct PlayerControlsBar: View {
    public let game: Game
    @ObservedObject var settings: ArcadeSettings
    @Binding var isPaused: Bool
    public let onBack: () -> Void
    public let onRestart: () -> Void
    public let onTogglePause: () -> Void
    public let onToggleMute: () -> Void
    public let onTakeScreenshot: () -> Void
    public let onToggleFullscreen: () -> Void
    
    public var body: some View {
        HStack(spacing: 14) {
            // Back Button
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .black))
                    Text("ARCADE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            
            // Game Title
            HStack(spacing: 8) {
                Text(game.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(game.type.shortBadge)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(game.type.badgeColor))
            }
            
            Spacer()
            
            // Player Controls
            HStack(spacing: 8) {
                // Restart
                hudButton(icon: "arrow.counterclockwise", title: "Restart", action: onRestart)
                
                // Pause / Resume
                hudButton(
                    icon: isPaused ? "play.fill" : "pause.fill",
                    title: isPaused ? "Resume" : "Pause",
                    highlight: isPaused,
                    action: onTogglePause
                )
                
                // Sound / Mute
                hudButton(
                    icon: settings.soundMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    title: settings.soundMuted ? "Unmute" : "Mute",
                    action: onToggleMute
                )
                
                Divider()
                    .frame(height: 18)
                
                // Aspect Ratio Menu
                Menu {
                    ForEach(GameAspectRatio.allCases) { ratio in
                        Button(action: { settings.defaultAspectRatio = ratio }) {
                            HStack {
                                Text(ratio.displayName)
                                if settings.defaultAspectRatio == ratio {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "aspectratio")
                        Text(settings.defaultAspectRatio.displayName)
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 140)
                
                // Bezel Mode Menu
                Menu {
                    ForEach(BezelMode.allCases) { mode in
                        Button(action: { settings.bezelMode = mode }) {
                            HStack {
                                Label(mode.displayName, systemImage: mode.iconName)
                                if settings.bezelMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: settings.bezelMode.iconName)
                        Text(settings.bezelMode.displayName)
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 140)
                
                // CRT Scanlines Toggle
                Button(action: { settings.crtScanlinesEnabled.toggle() }) {
                    Image(systemName: settings.crtScanlinesEnabled ? "tv.fill" : "tv")
                        .font(.system(size: 12))
                        .foregroundColor(settings.crtScanlinesEnabled ? Color(red: 0.0, green: 0.95, blue: 1.0) : .white.opacity(0.7))
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(settings.crtScanlinesEnabled ? Color(red: 0.0, green: 0.95, blue: 1.0).opacity(0.2) : Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("Toggle CRT Scanline Effect")
                
                // Screenshot / Snapshot
                Button(action: onTakeScreenshot) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("Capture In-Game Snapshot as Thumbnail")
                
                // Fullscreen
                Button(action: onToggleFullscreen) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("Toggle Fullscreen")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.08, green: 0.09, blue: 0.15).opacity(0.92))
                .shadow(color: Color.black.opacity(0.5), radius: 10)
        )
    }
    
    private func hudButton(icon: String, title: String, highlight: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(highlight ? Color(red: 1.0, green: 0.1, blue: 0.6) : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(highlight ? Color(red: 1.0, green: 0.1, blue: 0.6).opacity(0.25) : Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}
