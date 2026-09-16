//
//  ArcadeSettings.swift
//  MacArcade
//
//  Created for MacArcade.
//

import Foundation
import SwiftUI

public enum BezelMode: String, Codable, CaseIterable, Identifiable {
    case cabinet = "cabinet"
    case crt = "crt"
    case modern = "modern"
    case borderless = "borderless"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .cabinet: return "Arcade Cabinet"
        case .crt: return "CRT Monitor"
        case .modern: return "Modern Frame"
        case .borderless: return "Borderless Full"
        }
    }
    
    public var iconName: String {
        switch self {
        case .cabinet: return "gamecontroller"
        case .crt: return "tv"
        case .modern: return "rectangle.inset.filled"
        case .borderless: return "arrow.up.left.and.arrow.down.right"
        }
    }
}

public class ArcadeSettings: ObservableObject {
    public static let shared = ArcadeSettings()
    
    private let defaults = UserDefaults.standard
    
    @Published public var bezelMode: BezelMode {
        didSet { defaults.set(bezelMode.rawValue, forKey: "arcade_bezel_mode") }
    }
    
    @Published public var crtScanlinesEnabled: Bool {
        didSet { defaults.set(crtScanlinesEnabled, forKey: "arcade_crt_scanlines") }
    }
    
    @Published public var crtScanlineOpacity: Double {
        didSet { defaults.set(crtScanlineOpacity, forKey: "arcade_scanline_opacity") }
    }
    
    @Published public var crtGlowEnabled: Bool {
        didSet { defaults.set(crtGlowEnabled, forKey: "arcade_crt_glow") }
    }
    
    @Published public var defaultAspectRatio: GameAspectRatio {
        didSet { defaults.set(defaultAspectRatio.rawValue, forKey: "arcade_default_aspect_ratio") }
    }
    
    @Published public var soundMuted: Bool {
        didSet { defaults.set(soundMuted, forKey: "arcade_sound_muted") }
    }
    
    @Published public var soundVolume: Double {
        didSet { defaults.set(soundVolume, forKey: "arcade_sound_volume") }
    }
    
    @Published public var showFPS: Bool {
        didSet { defaults.set(showFPS, forKey: "arcade_show_fps") }
    }
    
    @Published public var cabinetMarqueeText: String {
        didSet { defaults.set(cabinetMarqueeText, forKey: "arcade_marquee_text") }
    }
    
    @Published public var coinSoundEnabled: Bool {
        didSet { defaults.set(coinSoundEnabled, forKey: "arcade_coin_sound") }
    }
    
    public init() {
        let savedBezel = defaults.string(forKey: "arcade_bezel_mode") ?? BezelMode.cabinet.rawValue
        self.bezelMode = BezelMode(rawValue: savedBezel) ?? .cabinet
        
        self.crtScanlinesEnabled = defaults.object(forKey: "arcade_crt_scanlines") as? Bool ?? true
        self.crtScanlineOpacity = defaults.object(forKey: "arcade_scanline_opacity") as? Double ?? 0.65
        self.crtGlowEnabled = defaults.object(forKey: "arcade_crt_glow") as? Bool ?? true
        
        let savedRatio = defaults.string(forKey: "arcade_default_aspect_ratio") ?? GameAspectRatio.auto.rawValue
        self.defaultAspectRatio = GameAspectRatio(rawValue: savedRatio) ?? .auto
        
        self.soundMuted = defaults.bool(forKey: "arcade_sound_muted")
        self.soundVolume = defaults.object(forKey: "arcade_sound_volume") as? Double ?? 0.9
        self.showFPS = defaults.bool(forKey: "arcade_show_fps")
        self.cabinetMarqueeText = defaults.string(forKey: "arcade_marquee_text") ?? "MAC ARCADE"
        self.coinSoundEnabled = defaults.object(forKey: "arcade_coin_sound") as? Bool ?? true
    }
}
