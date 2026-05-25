# Lucid — Product Specification

## 1. Concept & Vision

**Lucid** is a personal music sanctuary — a native iOS MP3 player that puts the listener back in control. No accounts, no cloud, no algorithm. Just you and your music, stored locally and organized the way you want. It's the anti-Spotify: private, offline-first, and built around the feeling of owning your collection.

**Tagline:** *Your music. Your terms.*

---

## 2. What We're Building (Core Feature)

A native iOS app for importing, organizing, and playing MP3 files from the device's local storage. Users import music via the iOS Files app, browse by Playlists or All Songs, search across titles and artists, and enjoy full playback controls with lock screen / background audio support.

---

## 3. User Story

> *As an iPhone user who keeps their personal MP3 collection offline, I want a beautiful, fast, native music player so I can listen to my music anywhere — even without internet — without being locked into Spotify or Apple Music.*

---

## 4. Success Metrics

- Import 500+ MP3 files without lag
- Search results appear in <200ms
- Background playback continues for 3+ hours
- Lock screen controls are responsive
- Album art displays correctly for tagged files

---

## 5. Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | SwiftUI (iOS 17+) |
| Data Layer | SwiftData |
| Audio Playback | AVFoundation + MediaPlayer |
| File Import | UIDocumentPickerViewController (Files app) |
| Background Audio | AVAudioSession + MPNowPlayingInfoCenter |
| Architecture | MVVM |
| Build Tool | XcodeGen |
| Min iOS Version | iOS 17.0 |

---

## 6. Screen Structure

### Tab Bar (3 tabs)
1. **Songs** — Flat list of all imported tracks, sorted A→Z
2. **Playlists** — User-created playlists with cover art
3. **Search** — Live search across songs + artists

### Sub-screens
- **Now Playing** — Full-screen player with album art, controls, queue
- **Mini Player** — Persistent bottom bar when music is playing
- **Playlist Detail** — Songs within a playlist, reorderable
- **Add to Playlist** — Sheet to select/create playlist when adding a song

---

## 7. Core Features

### Import
- Tap "+" button → iOS Files picker opens → user selects MP3s → imported into app
- Extract embedded ID3 metadata: title, artist, album, duration, album art
- Store in SwiftData (Song model)
- Show progress indicator during import

### Library Views
- **Songs tab**: Scrollable list, 60fps, lazy loaded. Shows: track number, title, artist, duration
- **Playlists tab**: Grid of playlist cards (2 columns), each with name + song count
- **Playlist Detail**: Vertical list of songs in that playlist

### Playback
- Tap any song to play immediately
- Play / Pause / Next / Previous controls
- Shuffle mode (toggle)
- Repeat mode: Off → All → One (cycle)
- Seek bar with current time / total time
- Volume control
- Lock screen controls (MediaPlayer framework)
- Background audio continues when app is backgrounded

### Search
- Search bar at top of Search tab
- Real-time filtering as user types
- Matches song titles and artist names
- Shows "No results" state when nothing matches

### Playlists
- Create new playlist (name + optional cover)
- Add songs to playlist from song row context menu
- Remove songs from playlist
- Reorder songs within playlist (drag handle)
- Delete playlist (swipe or context menu)

### Now Playing Screen
- Full-screen: large album art, song title, artist, progress bar, controls
- Swipe down to dismiss (reveals mini player)
- Heart button to toggle favourite
- Queue button to see upcoming songs

### Mini Player
- Fixed at bottom of screen above tab bar
- Shows: album art thumbnail, song title, artist, play/pause button
- Tap to expand to Now Playing full screen
- Swipe left/right to skip tracks

### Empty States
- No songs: "Import your first MP3s from the Files app"
- No playlists: "Create your first playlist"
- No search results: "No songs match '[query]'"

---

## 8. Out of Scope (V1)

- Album art generation / AI features
- Cloud sync / account system
- Podcasts / audiobooks
- Streaming from internet / URL import
- Android or cross-platform
- Editing MP3 metadata within the app
- Playlist cover image selection (auto-generate from first song's art)
- Equalizer / audio effects
- Sleep timer

---

## 9. Data Models

```
Song
  - id: UUID
  - title: String
  - artist: String
  - albumTitle: String?
  - duration: Double (seconds)
  - fileURL: String (local path)
  - albumArt: Data? (embedded JPEG/PNG)
  - dateAdded: Date
  - isFavorite: Bool

Playlist
  - id: UUID
  - name: String
  - createdAt: Date
  - songs: [Song] (ordered)
```

---

## 10. Open Questions / Dependencies

- **Storage**: All MP3s stored in app's Documents directory. Do we need a cleanup mechanism when songs are deleted from library?
- **Art extraction**: Use `AVAsset` to extract `artwork` metadata. Confirm this works for all tag formats (ID3v2, iTunes).
- **Audio session**: Need to configure `AVAudioSession` category to `.playback` with options `.allowBluetooth`.
- **XcodeGen**: Confirm it's installed on user's Mac before we generate the project.