# Lucid — Product Requirements Document

**Version:** 1.0  
**Status:** Draft  
**Last Updated:** 2026-01-26

---

## Overview

Lucid is a native iOS MP3 player designed for listeners who keep their music collection offline and local. It replaces cloud-dependent streaming apps (Spotify, Apple Music) with a private, beautifully-designed, high-performance player that works entirely on-device. No account required. No internet required to play music.

**Core value proposition:** Your music, your terms — owned, stored, and controlled by you.

---

## Goals & Success Metrics

| Goal | Metric |
|------|--------|
| Fast library browsing | 500+ songs load in <1s |
| Reliable playback | Zero audio glitches during 3hr background playback |
| Search responsiveness | Results render in <200ms |
| Data integrity | All imported songs persist across app restarts |
| User trust | App never loses or corrupts the user's music library |

---

## User Stories

### Primary Story
**As a user, I want to import my personal MP3 collection so I can listen to it offline on my iPhone.**

*Acceptance criteria:*
- User can select multiple MP3 files from the iOS Files app
- Each file is imported with title, artist, album, and duration metadata extracted
- Imported songs appear in the Songs tab immediately
- Import progress is visible

### Playback Story
**As a user, I want full playback controls so I can listen to music hands-free.**

*Acceptance criteria:*
- Play, pause, next, previous work instantly
- Shuffle and repeat modes function correctly
- Seek bar allows jumping to any position in the track
- Lock screen shows correct track info and controls
- Background audio continues when app is backgrounded

### Organization Story
**As a user, I want to organize my songs into playlists so I can group music by mood or context.**

*Acceptance criteria:*
- User can create a playlist with a name
- User can add any song to any playlist
- User can remove songs from a playlist
- User can reorder songs within a playlist
- User can delete a playlist

### Search Story
**As a user, I want to find songs quickly so I don't have to scroll through my entire library.**

*Acceptance criteria:*
- Search bar is always visible in the Search tab
- Results update as user types (real-time)
- Matches on both song title and artist name
- Empty state shown when no results match

---

## Functional Requirements

### FR-1: Song Import
- Use `UIDocumentPickerViewController` to allow multi-select MP3 files
- Extract ID3 metadata (title, artist, album, duration, artwork) using `AVAsset`
- Copy MP3 files to app's `Documents/Music/` directory
- Create `Song` SwiftData record for each file
- Show progress indicator during import
- Handle duplicate files gracefully (skip or replace)

### FR-2: Songs Tab
- Display all songs in a flat list sorted alphabetically by title
- Each row shows: track title, artist name, duration (MM:SS)
- Lazy loading for performance with 500+ songs
- Tap row → play that song immediately, replacing queue
- Long-press row → context menu (Add to Playlist, Favorite, Share, Delete)

### FR-3: Playlists Tab
- Display all playlists as a 2-column grid of cards
- Each card shows: playlist name, song count, cover art (first song's album art)
- Tap "+" button → create new playlist sheet
- Tap playlist card → navigate to Playlist Detail screen

### FR-4: Playlist Detail Screen
- Header: playlist name, song count, total duration
- Scrollable list of songs in playlist order
- Drag handles to reorder songs
- Swipe left on song → remove from playlist
- "+" button → add songs sheet

### FR-5: Audio Playback
- Use `AVAudioPlayer` (or `AVPlayer` with `AVAudioSession`) for playback
- Configure `AVAudioSession` category: `.playback`, options: `.allowBluetooth`, `.allowAirPlay`
- Support: play, pause, next, previous, seek, shuffle, repeat
- Repeat modes: Off (stop at end) → All (loop queue) → One (loop track)
- Maintain playback state across app lifecycle

### FR-6: Now Playing Screen
- Full-screen modal (swipe down to dismiss)
- Large album art (centered, aspect-fit)
- Song title (bold, 20pt), Artist (regular, 16pt)
- Progress bar (interactive seek)
- Play/Pause (center, large), Previous/Next (sides)
- Shuffle toggle, Repeat toggle, Heart toggle
- Volume slider (optional — iOS handles via side buttons)
- Queue button → sheet showing upcoming songs

### FR-7: Mini Player
- Fixed view above tab bar, 64pt height
- Shows: 44x44 album art thumbnail, title, artist, play/pause button
- Tap anywhere → expand to Now Playing full screen
- Swipe horizontally on artwork → next/previous track
- Hidden when no song is playing

### FR-8: Search
- `SearchBar` in Search tab
- Filter `Song` SwiftData model where `title CONTAINS[c] query OR artist CONTAINS[c] query`
- Live updates as text changes (debounce 150ms)
- "No results" empty state with query shown

### FR-9: Background & Lock Screen Playback
- Configure `MPNowPlayingInfoCenter` to set: title, artist, album art, elapsed time, duration
- Set `MPRemoteCommandCenter` handlers for: play, pause, nextTrack, previousTrack, changePlaybackPosition
- Audio session must be active and maintained in background

### FR-10: Favorites
- `isFavorite` boolean on `Song` model
- Heart button on Now Playing and song row toggles this
- Future: Favorites playlist (not in V1 scope)

### FR-11: Delete Song
- Available via long-press context menu on song row
- Confirmation alert before delete
- Removes SwiftData record AND deletes file from Documents/Music/
- If song is currently playing → stop and clear Now Playing

### FR-12: Empty States
- **No songs**: Illustration + "Tap + to import your first songs from the Files app"
- **No playlists**: Illustration + "Create your first playlist to organize your music"
- **No search results**: "No songs match '[query]'"

---

## Non-Functional Requirements

### NFR-1: Performance
- Songs list must scroll at 60fps with 500+ items
- Search results render in <200ms
- App launch to playable song in <2s on iPhone 12+

### NFR-2: Offline-First
- All data stored locally using SwiftData
- No network calls required for any core feature
- No analytics or tracking in V1

### NFR-3: Privacy
- No account creation
- No data leaves the device
- No cloud sync

### NFR-4: Compatibility
- iOS 17.0+ (SwiftData requirement)
- iPhone only (not iPad optimized in V1)
- Portrait orientation only

### NFR-5: Storage
- MP3 files stored in `Documents/Music/`
- App storage grows with music library
- No automatic cleanup mechanism in V1

---

## Out of Scope

- Album art generation (V2 — extract only)
- Cloud sync / account system
- Podcasts, audiobooks
- Streaming from URLs
- Android / cross-platform
- Editing ID3 metadata within the app
- Custom playlist cover images
- Equalizer / audio effects
- Sleep timer
- Social / sharing features

---

## Dependencies & Open Questions

| Item | Status |
|------|--------|
| XcodeGen installation on Mac | Open — user to confirm |
| Audio session configuration for AirPods/Bluetooth | Open — code to handle `.allowBluetooth` |
| Art extraction reliability across ID3 versions | Open — code to test |
| Storage cleanup when songs are deleted | Deferred to V2 |
| Playlist cover default (first song's art) | Confirmed — auto from first song |

---

## Screen Flow

```
Tab Bar
├── Songs Tab
│   └── [Long-press song] → Context Menu
├── Playlists Tab
│   └── [Tap playlist] → Playlist Detail
│       └── [Tap +] → Add Songs Sheet
└── Search Tab
    └── [Tap result] → Play song

Global
├── Mini Player (visible when playing)
│   └── [Tap] → Now Playing Full Screen
└── Now Playing
    └── [Swipe down] → Dismiss to Mini Player
    └── [Tap queue] → Queue Sheet
```

---

## File Structure (Target)

```
Lucid/
├── App/
│   └── LucidApp.swift
├── Models/
│   ├── Song.swift
│   └── Playlist.swift
├── Views/
│   ├── MainTabView.swift
│   ├── SongsTab/
│   │   ├── SongsListView.swift
│   │   └── SongRowView.swift
│   ├── PlaylistsTab/
│   │   ├── PlaylistsGridView.swift
│   │   ├── PlaylistCardView.swift
│   │   └── PlaylistDetailView.swift
│   ├── SearchTab/
│   │   └── SearchView.swift
│   ├── NowPlaying/
│   │   ├── NowPlayingView.swift
│   │   └── MiniPlayerView.swift
│   └── Components/
│       └── AlbumArtView.swift
├── ViewModels/
│   ├── LibraryViewModel.swift
│   └── PlayerViewModel.swift
├── Services/
│   ├── AudioPlayerService.swift
│   └── MetadataExtractor.swift
├── Utilities/
│   └── Extensions.swift
└── Resources/
    └── Assets.xcassets/
```