# Mac Arcade

A native macOS SwiftUI game shelf for importing local HTML games and Flash `.swf` files, then playing them in a dark, built-in player.

## Open and run in Xcode

There is no package manager, command-line setup, or separate runtime download required.

1. Download or clone this repository.
2. Open **`MacArcade.xcodeproj`** in Xcode.
3. Select the **MacArcade** scheme and **My Mac** as the run destination.
4. Press **Run** (`⌘R`). The project targets **macOS 13 or later**.
5. In the app, choose **Import Games** (or press `⌘O`) and select one or more `.html`, `.htm`, or `.swf` files.

The Ruffle Flash runtime is included in the project, so SWF playback does not need a browser plugin or internet access.

## Import notes

- **HTML games:** choose the game's entry HTML file (for example, `index.html`). Mac Arcade copies the selected file's entire containing folder so sibling scripts, stylesheets, images, and other local assets remain available.
- **SWF games:** choose the game's `.swf` file. Its containing folder is copied too, so nearby media loaded by the movie can be found by the bundled [Ruffle](https://ruffle.rs/) Flash emulator.
- For either format, keep each game in its own folder before importing; the app copies sibling files, so avoid selecting a game from a folder containing unrelated large files.
- The imported copies and library index live in `~/Library/Application Support/MacArcade/`. Your source files are not modified. Removing a game from the library deletes only Mac Arcade's copied version.
- HTML games execute their JavaScript in WebKit. Only import games and files you trust. A game may also need its own internet connection for online features or remote assets.

## Playback details

HTML games run in a native `WKWebView`. A small HTTP server bound only to `127.0.0.1` serves local game assets and Ruffle's WebAssembly files; this provides a reliable local web origin and keeps playback offline-capable. The server uses an automatically selected port and stops when the app exits. The app's App Sandbox is disabled in the Xcode target so it can bind this loopback-only server and immediately copy files chosen in the macOS open panel; the server is not exposed to other devices on your network. Mac Arcade remembers its local port when it is available, which also helps HTML games retain browser storage between launches; it selects a free fallback port if needed.

Flash support is provided by Ruffle 0.6.0. Ruffle is an emulator, not Adobe Flash Player, so some older games or Flash APIs may not be fully supported. See the included runtime licenses in `MacArcade/Resources/Ruffle/`.

## Project layout

```text
MacArcade/
  App/                 SwiftUI app entry point
  Models/              Game and library models
  Services/            Import/persistence and loopback web server
  Views/               Dark SwiftUI interface and WKWebView player
  Resources/Ruffle/    Bundled, offline Ruffle runtime and licenses
MacArcade.xcodeproj/   Ready-to-open Xcode project and shared scheme
```

## License

Mac Arcade's original source is provided under the MIT License (see `LICENSE`). Ruffle is third-party software distributed under the terms in `MacArcade/Resources/Ruffle/LICENSE_MIT` and `LICENSE_APACHE`.
