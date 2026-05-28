# Lucid Radio — SPEC.md

## What we're building

A globe-based internet radio feature inside Lucid. Users spin a 3D globe, land on countries/cities, and tune into live radio stations from around the world via the Radio Browser API (~30k stations). Radio becomes the fourth tab alongside Library, Search, and Settings.

---

## Core Experience

**Globe screen** is the home. Full-screen 3D globe (SwiftUI Map, top-down satellite view), gesture-controlled:
- **Pan** → spin globe
- **Pinch** → zoom in/out
- **Tap on country** → open country's station list
- **"Random" button** → land on a random station, highlight it, show play prompt

**Country sheet** slides up on tap. Shows:
- Country name + flag emoji + station count
- Scrollable list of all stations in that country (fetched on demand, cached locally)
- Each row: station name, genre tags, bitrate, favorite button
- Tap row → immediately starts playing that station

**Search bar** above globe:
- Type a city, state, or country → globe flies to that location
- Results show station matches too (station name, tag, country)

**Favorites** accessible from globe screen:
- Heart icon → shows saved stations in a sheet
- Favorites persist in SwiftData

**Recently Played** accessible from globe screen:
- Clock icon → last 20 stations played
- Tap to replay instantly

---

## Audio Behavior

- Radio mode replaces the library queue entirely (no queue, no up-next)
- Mini player shows: station name, country flag, animated "now live" indicator, volume, stop button
- Stop exits radio mode and returns to last played library song (or empty)
- AVPlayer handles both MP3 and HLS streams
- Buffering state shown in mini player

**Simplified mini player controls:**
- Tap to expand → station name, country, genre tags, stop button, volume slider, favorite toggle
- No skip/next/queue — radio doesn't work that way

---

## Data Model

**RadioStation** (SwiftData):
- `stationuuid` — primary key (from Radio Browser)
- `name`, `url`, `urlResolved`, `favicon`, `tags`, `country`, `countrycode`
- `state`, `language`, `codec`, `bitrate`
- `geoLat`, `geoLong` — nullable
- `clickcount`, `votes` — for popularity sorting
- `lastCheckOk` — 1 = verified working, 0 = may be dead
- `isFavorite` — bool
- `lastPlayedAt` — datetime

**Cached on first fetch:**
- Fetch all countries from API → store in SwiftData
- Each country row: `countryName`, `countryCode`, `stationCount`, `flagEmoji`
- When user taps a country, fetch that country's stations and cache

**Refresh strategy:**
- Countries list: cached for 7 days, background refresh on app launch if stale
- Station list per country: cached for 3 days, refresh when user opens that country again
- "lastCheckOk = 1" filter applied by default — hide stations known to be dead

---

## Tab Structure

Replace **Search** tab with **Radio** tab.

```
[Library] [Radio ✈️] [Settings]
```

**Radio tab has two modes:**
1. **Globe mode** — globe home screen (default)
2. **Stations list mode** — triggered by tapping a country or searching a station

Transition: globe has a bottom toolbar with Search (🔍), Favorites (❤️), Recent (🕐). Tap any toolbar item and the globe shrinks to a small thumbnail in the corner while the panel slides up. Tap globe to go back.

---

## Out of Scope

- Curated playlists or mixing radio with library songs
- Recording / save broadcast
- Podcast radio shows
- Station recommendations based on listening history (simple favorites/history only)
- Offline radio playback (streams require internet)

---

## Open Questions

- [ ] Globe marker styling — colored dots by genre? Or all same color?
- [ ] When user has no internet — show last cached country lists + favorites only
- [ ] Station favicon images — load lazily, placeholder on failure
- [ ] Country flag emoji — derive from countrycode (US→🇺🇸) or store in API?

---

## Success Metrics

- Globe spins smoothly (60fps) on iPhone 12 and newer
- Station stream starts within 5s of tap
- App works with cached data when offline
- Favorites and recently played persist across sessions