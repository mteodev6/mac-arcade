//
//  ArcadeCabinetBezel.swift
//  MacArcade
//
//  Created for MacArcade.
//

import SwiftUI
import AppKit

public struct ArcadeCabinetBezel<Content: View>: View {
    public let game: Game
    @ObservedObject var settings: ArcadeSettings
    @ViewBuilder public let content: () -> Content
    
    @State private var coinInserted: Bool = false
    @State private var creditCount: Int = 1
    
    public var body: some View {
        switch settings.bezelMode {
        case .cabinet:
            cabinetView
        case .crt:
            crtMonitorView
        case .modern:
            modernFrameView
        case .borderless:
            borderlessView
        }
    }
    
    // MARK: - Full Arcade Cabinet
    private var cabinetView: some View {
        VStack(spacing: 0) {
            // Cabinet Top Marquee
            HStack {
                // Left speaker grille
                speakerGrille
                    .frame(width: 80, height: 32)
                
                Spacer()
                
                // Illuminated Arcade Marquee
                MarqueeBanner(
                    title: settings.cabinetMarqueeText.isEmpty ? game.title : settings.cabinetMarqueeText,
                    accentColor: game.accentColor
                )
                
                Spacer()
                
                // Right speaker grille
                speakerGrille
                    .frame(width: 80, height: 32)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color(red: 0.03, green: 0.04, blue: 0.08))
            
            // Screen Area with Bezel
            HStack(spacing: 0) {
                // Left cabinet side edge
                cabinetSideEdge(isLeft: true)
                
                // Center CRT Monitor Bezel
                ZStack {
                    // Monitor bezel frame
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(red: 0.08, green: 0.09, blue: 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.15), Color.black.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                        )
                    
                    // Game Screen
                    content()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(14)
                }
                .shadow(color: game.accentColor.opacity(0.15), radius: 20)
                
                // Right cabinet side edge
                cabinetSideEdge(isLeft: false)
            }
            
            // Bottom Arcade Control Panel & Coin Door
            HStack(spacing: 24) {
                // 1P Start Button
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 11))
                    Text("1 PLAYER")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.1)))
                
                Spacer()
                
                // 25¢ Insert Coin Button
                Button(action: insertCoin) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(coinInserted ? Color(red: 1.0, green: 0.85, blue: 0.0) : Color.orange)
                            .frame(width: 10, height: 10)
                            .shadow(color: .orange, radius: coinInserted ? 8 : 2)
                        
                        Text("25¢ INSERT COIN")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(coinInserted ? Color(red: 1.0, green: 0.85, blue: 0.0) : .white)
                        
                        Text("CREDITS: \(creditCount)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.5)))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.12, green: 0.06, blue: 0.02))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.orange.opacity(0.6), lineWidth: 1.5))
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // 2P Start Button
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11))
                    Text("2 PLAYERS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.1)))
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 10)
            .background(Color(red: 0.03, green: 0.04, blue: 0.08))
        }
        .background(Color(red: 0.02, green: 0.03, blue: 0.06))
    }
    
    // MARK: - CRT Monitor Frame
    private var crtMonitorView: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.08)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                content()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 6)
                    )
                    .shadow(color: game.accentColor.opacity(0.2), radius: 24)
                    .padding(20)
            }
        }
    }
    
    // MARK: - Modern Frame
    private var modernFrameView: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.1)
                .edgesIgnoringSafeArea(.all)
            
            content()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(12)
        }
    }
    
    // MARK: - Borderless Full
    private var borderlessView: some View {
        content()
            .edgesIgnoringSafeArea(.all)
    }
    
    // MARK: - Subcomponents
    private var speakerGrille: some View {
        HStack(spacing: 6) {
            ForEach(0..<6) { _ in
                Capsule()
                    .fill(Color.black)
                    .frame(width: 4, height: 20)
            }
        }
    }
    
    private func cabinetSideEdge(isLeft: Bool) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: isLeft ?
                        [Color.black.opacity(0.8), Color.white.opacity(0.05)] :
                        [Color.white.opacity(0.05), Color.black.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 14)
            .overlay(
                Rectangle()
                    .fill(game.accentColor.opacity(0.3))
                    .frame(width: 2),
                alignment: isLeft ? .leading : .trailing
            )
    }
    
    private func insertCoin() {
        withAnimation(.easeInOut(duration: 0.1)) {
            coinInserted = true
            creditCount += 1
        }
        if settings.coinSoundEnabled {
            NSSound.beep()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                coinInserted = false
            }
        }
    }
}
