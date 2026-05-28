# Lucid Radio — PRD

## 1. Overview

A globe-based internet radio feature inside Lucid. Users spin a 3D globe, tap countries, and tune into live radio stations from around the world. Radio becomes the third primary tab, replacing the current Search tab. Powered by Radio Browser API (~30k stations, 237 countries).

**Value prop:** The world is your radio station. One tap to land on a random station in Ahmedabad, Toronto, or Oslo.

---

## 2. User Stories

**S1** — As a user, I open the Radio tab and see a spinning globe so I can explore stations by geography.

**S2** — As a user, I tap a country and immediately see all available stations from that country in a sheet.

**S3** — As a user, I tap a station row and it starts playing immediately with a simplified mini player.

**S4** — As a user, I tap "Random" and land on a random live station from somewhere in the world.

**S5** — As a user, I can search for a city or country and the globe flies to that location.

**S6** — As a user, I can favorite stations and they persist across sessions.

**S7** — As a user, I can see my recently played stations and replay any of them instantly.

**S8** — As a user, when I stop a station, I return to my last library song (or empty state).

---

## 3. Functional Requirements

### 3.1 Globe Screen
- Full-screen SwiftUI Map with `.standard` map style (satellite/terrain)
- Initial camera: centered on world, pitched at 30°
- **Pan gesture**: rotates globe
- **Pinch gesture**: zoom in/out (min zoom shows whole world, max zoom shows city-level)
- **Tap on country**: resolves to country → opens CountryStationSheet
- **"Random Station" button**: bottom center, pill-shaped. Tap → API picks random station → globe flies to station's country → highlight marker → show play prompt
- **Toolbar** (bottom): Search (🔍) | Favorites (❤️) | Recent (🕐)

### 3.2 Country Station Sheet
- Slides up as a half-sheet (`.presentationDetents([.medium, .large])`)
- Header: country flag emoji + country name + station count
- List of stations, sorted by: Popular (default), Recent, A-Z
- Each row: station name, genre tags, bitrate badge, favorite button
- Rows with `lastCheckOk = 0`: shown in muted style with "可能已下线" (possibly offline) label
- Tap row → immediately start stream, dismiss sheet, show mini player

### 3.3 Search
- Search bar above globe (always visible)
- Text input → debounce 300ms → search both:
  - **Countries**: by name → show country tap to open station list
  - **Stations**: by name/tag → show matching stations inline, tap to play
- Globe flies to matched country on selection

### 3.4 Favorites
- Heart icon in toolbar → FavoritesSheet (half-sheet)
- List of favorited stations, sorted by last played
- Swipe left to remove from favorites
- Tap to play

### 3.5 Recently Played
- Clock icon in toolbar → RecentSheet (half-sheet)
- Last 20 played stations
- Each row: station name, country, when played ("2 hours ago")
- Tap to play

### 3.6 Radio Mini Player
- Appears when radio is playing, positioned above tab bar
- Collapsed: station name (truncated), animated "🔴 LIVE" indicator, stop button (✕)
- Expand on tap:
  - Station name + country + genre tags
  - Large stop button
  - Volume slider (MPVolumeView)
  - Favorite toggle
  - "Open station website" link (if homepage available)
- No skip/next/queue — radio is linear stream

### 3.7 Audio Engine
- Use Lucid's existing `PlayerViewModel` as source of truth for "what is playing"
- Add `radioStation: RadioStation?` property to `PlayerViewModel`
- When `radioStation != nil`: disable queue controls, show radio UI
- When `radioStation == nil`: restore library playback mode
- AVPlayer for MP3 streams
- AVPlayer also handles HLS streams (native support)
- On radio play: save current library playback position to `lastLibraryTrack` so stop can restore it

### 3.8 Data & Caching
- **Countries list**: fetched from `/json/countries`, stored in SwiftData (`RadioCountry` model)
- **Stations by country**: fetched from `/json/stations/bycountrycodeexact/{code}`, cached in SwiftData (`RadioStation` model)
- **Stations with geo**: `geoLat IS NOT NULL` → shown as pins on globe
- **Stations without geo**: shown only in country lists, not on globe
- Cache expiry: countries 7 days, stations 3 days, background refresh on app launch
- Offline mode: show cached countries + cached stations for favorite countries + favorites

---

## 4. Non-Functional Requirements

- **Performance**: Globe pans at 60fps on iPhone 12+. Fallback to flat map on older devices.
- **Stream start time**: < 5s from tap to audio playing
- **Offline**: Favorites and recently played accessible offline. Country lists cached for 7 days.
- **API rate limiting**: Cache aggressively. No burst requests. Max 1 API call per 2 seconds during normal use.

---

## 5. Architecture

```
Lucid/
├── Features/
│   └── Radio/
│       ├── RadioGlobeView.swift          # Main globe screen
│       ├── GlobeViewModel.swift           # Globe state, camera, gestures
│       ├── CountryStationSheet.swift      # Half-sheet station list
│       ├── FavoritesSheet.swift           # Favorited stations
│       ├── RecentSheet.swift              # Recently played
│       ├── RadioSearchView.swift          # Search results overlay
│       ├── RadioMiniPlayer.swift          # Compact radio player
│       └── Components/
│           ├── GlobeMarker.swift          # Map annotation for stations
│           ├── StationRow.swift           # Reusable station list row
│           └── RandomButton.swift         # Floating random station button
├── Models/
│   ├── RadioStation.swift                # SwiftData model
│   └── RadioCountry.swift                 # SwiftData model
├── Services/
│   ├── RadioBrowserService.swift          # API client (Radio Browser)
│   └── RadioAudioService.swift           # AVPlayer wrapper for streams
└── ViewModels/
    └── PlayerViewModel.swift             # Extended with radioStation property
```

---

## 6. Data Models

### RadioStation (SwiftData)
| Field | Type | Notes |
|-------|------|-------|
| `stationuuid` | String | Primary key |
| `name` | String | |
| `url` | String | Stream URL |
| `urlResolved` | String? | Resolved stream URL |
| `favicon` | String? | Station logo URL |
| `tags` | String | Comma-separated: "pop,rock,news" |
| `country` | String | Full name: "India" |
| `countryCode` | String | ISO 3166-1 alpha-2: "IN" |
| `state` | String? | |
| `language` | String? | |
| `codec` | String | "MP3", "AAC", "HLS" |
| `bitrate` | Int | kbps |
| `geoLat` | Double? | |
| `geoLong` | Double? | |
| `clickcount` | Int | Popularity |
| `votes` | Int | User votes |
| `lastCheckOk` | Bool | Working stream |
| `isFavorite` | Bool | |
| `lastPlayedAt` | Date? | |
| `cachedAt` | Date | For cache expiry |

### RadioCountry (SwiftData)
| Field | Type | Notes |
|-------|------|-------|
| `countryCode` | String | Primary key, ISO 3166-1 alpha-2 |
| `countryName` | String | Full name |
| `stationCount` | Int | |
| `flagEmoji` | String | Derived from countryCode |
| `cachedAt` | Date | For cache expiry |

---

## 7. API Reference

Base URL: `https://de1.api.radio-browser.info/json/`

| Endpoint | Use |
|----------|-----|
| `GET /countries` | List all countries with station counts |
| `GET /stations/bycountrycodeexact/{code}` | Stations for a country |
| `GET /stations/bycoordinates/{lat}/{long}/{radius}` | Nearby stations |
| `GET /stations/byname/{name}` | Search stations by name |
| `GET /stations/bytag/{tag}` | Stations by genre tag |
| `POST /url/{stationuuid}` | Click tracking (marks station as played) |

**Filter defaults:** `?hidebroken=true&order=clickcount&reverse=true`

---

## 8. Out of Scope

- Mixing radio with library queue (radio is exclusive mode)
- Recording or saving broadcasts
- Station recommendations engine
- Offline radio playback
- Podcasts / talk radio
- User accounts / sync across devices

---

## 9. Phases

**Phase 1: Data Layer** — RadioStation + RadioCountry SwiftData models, RadioBrowserService API client, cache logic

**Phase 2: Globe UI** — GlobeView with pan/zoom, country tap → sheet, markers for geo-tagged stations, random button

**Phase 3: Station List + Search** — CountryStationSheet, station search, favorites, recently played

**Phase 4: Audio Integration** — RadioAudioService, extend PlayerViewModel, mini player, stop → restore library

**Phase 5: Polish** — Offline mode, loading states, error handling, empty states, cache refresh

---

## 10. Open Questions (resolved)

- **Globe vs flat map**: Globe with country-level view first. Tap country → station list.
- **Mini player**: Simplified — stop, volume, favorite only. No skip/next.
- **Favorites/history**: Both persist in SwiftData across sessions.
- **Globe marker styling**: Colored dots by top tag (pop=blue, rock=red, news=gray, etc.)
- **Offline**: Show cached countries + favorites + recently played when offline
- **Favicon**: Load lazily, show placeholder initials on failure
- **Flag emoji**: Derived from countryCode using Unicode regional indicator symbols