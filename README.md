# 🕹️ MacArcade

> **A native macOS Arcade app in Swift for playing Adobe Flash (`.swf`) and HTML5 (`.html` / `.zip`) games.**

[![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-blue.svg)](https://apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.0%2B-orange.svg)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-14%20%7C%2015%20%7C%2016-1575F9.svg)](https://developer.apple.com/xcode)
[![Flash](https://img.shields.io/badge/Flash%20SWF-Ruffle%20WASM-red.svg)](https://ruffle.rs)
[![HTML5](https://img.shields.io/badge/HTML5-WebKit%20Canvas-green.svg)](https://webkit.org)

**MacArcade** brings classic retro arcade gaming, Flash nostalgia, and modern web games to your Mac as a sleek, native desktop application. Upload standalone `.swf` files, `.html` files, or zipped HTML5 game packages and play them inside an authentic arcade cabinet interface with retro CRT scanline filters, arcade marquees, and interactive coin controls.

---

## ✨ Features

- **🎮 Universal Game Support**:
  - **Adobe Flash (`.swf`)**: Powered by the bundled **Ruffle** WebAssembly emulator. Play classic Flash games offline without Adobe Flash Player!
  - **HTML5 Games (`.html` / `.htm`)**: Fast, smooth 60fps canvas, WebGL, and WebAudio support via WebKit.
  - **Zipped Game Archives (`.zip`)**: Drag & drop zipped game packages (such as itch.io HTML5 exports). MacArcade automatically unzips and configures the game folder.
  - **Game Folders**: Import entire directories with assets, sound, and scripts.

- **🕹️ Authentic Arcade Cabinet Experience**:
  - **Arcade Cabinet Bezel**: Retro wooden cabinet casing, t-molding glow, illuminated neon marquee, speaker grilles, and interactive coin door (`25¢ INSERT COIN`).
  - **CRT Monitor Bezel**: Vintage curved CRT television styling.
  - **Modern Frame & Borderless Modes**: Frameless edge-to-edge gameplay.
  - **CRT Scanlines & Vignette Filter**: Authentic CRT phosphor scanlines with adjustable opacity and corner vignetting.
  - **Aspect Ratio Controls**: Switch between Original (Auto), 4:3 (Classic CRT), 16:9 (Widescreen), and Fill.

- **🎛️ In-Game Player HUD**:
  - **Quick Controls**: Restart (`Cmd+R`), Pause/Resume (`Cmd+P` / Space), Mute/Volume (`Cmd+M`), and Fullscreen (`Cmd+F`).
  - **Instant Screenshot**: Capture in-game moments with one click to update cover art or export to Pictures.
  - **Playtime & Session Tracker**: Automatically logs play counts, last played dates, and total playtime.

- **📦 Drag-and-Drop Library**:
  - Drag `.swf`, `.html`, or `.zip` files directly from Finder onto the MacArcade window to add them.
  - Search, sort (by Recently Added, Most Played, A-Z), and filter by category or favorites.
  - Custom game notes, keybinding guides, tags, and category organizers.
  - "Show in Finder" and "Export Game" for easy library backup.

- **👾 Pre-Installed Ready-to-Play Games**:
  - **Bloons Tower Defense** *(Classic Flash SWF by Ninja Kiwi)*
  - **World's Hardest Game** *(Classic Flash SWF by Stephen Critoph)*
  - **Space Defender** *(Vector space arcade shooter with WebAudio synth)*
  - **Neon Breakout** *(Synthwave neon brick breaker with particle sparks)*

---

## 🚀 Getting Started (Download & Import into Xcode)

### Requirements
- **macOS 13.0 (Ventura)**, **macOS 14.0 (Sonoma)**, or **macOS 15.0 (Sequoia)** or later.
- **Xcode 14.0+** (Intel or Apple Silicon Mac).
- Zero external package managers needed (no CocoaPods, no Carthage, no npm install)!

### Steps to Import & Run:

1. **Clone or Download the Repository**:
   ```bash
   git clone https://github.com/mteodev6/mac-arcade.git
   cd mac-arcade
   ```

2. **Open in Xcode**:
   - Double-click **`MacArcade.xcodeproj`** in Finder.
   - Or open it from Terminal:
     ```bash
     open MacArcade.xcodeproj
     ```

3. **Select Scheme & Run**:
   - In Xcode's top toolbar, ensure the scheme is set to **`MacArcade > My Mac`**.
   - Press **`Cmd + R`** (or click the **Play / Run ▶️** button).
   - Xcode will compile and launch **MacArcade** directly on your Mac!

---

## 🕹️ How to Add Games

### Method 1: Drag & Drop (Fastest)
1. Find any `.swf` file, `.html` file, or `.zip` file on your Mac.
2. Drag it directly over the **MacArcade** window.
3. The neon drop zone will illuminate. Drop the file to add it to your arcade!

### Method 2: "+ Add Game" Button
1. Click the **"+ ADD GAME"** button in the sidebar or toolbar (or press `Cmd + O`).
2. Click **"Choose File..."** and select your game file or folder.
3. Edit the title, select a category, and optionally add key control notes.
4. Click **"Add to Library"**.

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| **`Cmd + O`** | Add Game to Arcade |
| **`Cmd + ,`** | Open Arcade Preferences |
| **`Cmd + R`** | Restart / Reload Current Game |
| **`Cmd + P`** | Pause / Resume Game |
| **`Cmd + M`** | Mute / Unmute Audio |
| **`Cmd + F`** | Toggle Fullscreen |
| **`Esc`** | Exit to Arcade Library |

---

## 🏗️ Architecture Overview

MacArcade is built 100% in native Swift:

```
MacArcade/
├── App/
│   ├── MacArcadeApp.swift          # Main SwiftUI App entry point & menus
│   └── AppDelegate.swift           # AppKit lifecycle, server init & file opening
├── Models/
│   ├── Game.swift                  # Game data model (SWF / HTML5, stats, aspect)
│   ├── GameLibrary.swift           # Library state management & JSON persistence
│   └── ArcadeSettings.swift        # User preferences (CRT filters, bezel mode, audio)
├── Server/
│   ├── ArcadeServer.swift          # Embedded POSIX loopback HTTP server (127.0.0.1)
│   └── ArcadeSchemeHandler.swift   # WKURLSchemeHandler for arcade:// URLs
├── Services/
│   ├── FileImportService.swift     # File validation, game metadata & folder setup
│   ├── ThumbnailService.swift      # Screenshot capture & retro cover art generator
│   └── ZipExtractor.swift          # ZIP archive extraction utility
├── Views/
│   ├── MainView.swift              # NavigationSplitView coordinator
│   ├── SidebarView.swift           # Library categories & stats
│   ├── GameGridView.swift          # Glowing responsive arcade game grid
│   ├── GameListView.swift          # Table list alternative view
│   ├── GameCardView.swift          # Arcade cabinet themed game cards
│   ├── GameDetailView.swift        # Inspector panel with game specs & notes
│   ├── PlayerView.swift            # WKWebView host & arcade player container
│   ├── ArcadeCabinetBezel.swift    # Retro cabinet bezel, marquee & coin door
│   ├── PlayerControlsBar.swift     # Quick HUD bar (Restart, Pause, CRT, Aspect)
│   ├── AddGameSheet.swift          # Upload modal dialog
│   ├── EditGameSheet.swift         # Metadata editor
│   ├── SettingsView.swift          # Preferences dialog
│   └── Components/
│       ├── CRTShaderOverlay.swift  # Scanlines & CRT phosphor tube shader
│       ├── MarqueeBanner.swift     # Neon illuminated arcade marquee
│       ├── ArcadeButton.swift      # Glowing retro arcade button
│       └── DropZoneOverlay.swift   # Drag & drop visual indicator
└── Resources/
    ├── Ruffle/                     # Bundled Ruffle WebAssembly emulator & player.html
    ├── BuiltInGames/               # Pre-installed sample Flash & HTML5 games
    ├── Assets.xcassets/            # AppIcon & Accent Color
    ├── Info.plist                  # Document types for .swf and .html
    └── MacArcade.entitlements      # App networking & file permissions
```

### Flash SWF Emulation:
Flash games are emulated using [Ruffle](https://ruffle.rs), the open-source Flash Player emulator built in Rust and compiled to WebAssembly. The entire Ruffle runtime (`ruffle.js`, `core.ruffle.*.js`, and `.wasm` files) is bundled locally within the app resources. The embedded loopback server (`ArcadeServer`) serves files directly to `WKWebView`, enabling 100% offline Flash emulation without security sandbox or CORS issues.

---

## 📜 License

This project is open-source. Pre-installed demo games and Ruffle emulator components are subject to their respective licenses (Ruffle is licensed under Apache 2.0 / MIT).
