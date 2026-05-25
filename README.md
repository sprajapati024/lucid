# Lucid

Your personal music sanctuary — offline MP3 player for iOS.

**Built with:** SwiftUI + SwiftData, AVFoundation, MediaPlayer  
**Min iOS:** 17.0  
**Architecture:** MVVM

## Setup

### Prerequisites
- macOS with Xcode 15+
- XcodeGen installed: `brew install xcodegen`

### Generate Project
```bash
xcodegen generate
```

### Open & Run
```bash
open Lucid.xcodeproj
```
Then select an iPhone simulator and press **Cmd+R** to build and run.

## Features
- Import MP3s from Files app
- Browse by Songs or Playlists
- Full playback controls + lock screen
- Background audio
- Shuffle & repeat modes
- Search across library
- Create and manage playlists
- Extracts embedded album art

## Project Structure
```
Lucid/
├── App/LucidApp.swift
├── Models/       Song.swift, Playlist.swift
├── Views/        All SwiftUI views (TabView, NowPlaying, etc.)
├── ViewModels/   PlayerViewModel.swift
├── Services/     MetadataExtractor.swift
└── Utilities/    Extensions.swift
```

## Tech Stack
| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| Data | SwiftData |
| Audio | AVFoundation + MediaPlayer |
| Build | XcodeGen |