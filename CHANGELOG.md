# Changelog — OpenAAMPS & Pi-AAMPS

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.6] - 2026-10-01

### Added
- **Live 1-Tap Spotify & YouTube Music Sync**:
  - Live Bearer Token OAuth querying official Spotify Web API endpoints (`/v1/me`, `/v1/me/top/artists`, `/v1/me/top/tracks`, `/v1/me/player/recently-played`, `/v1/me/playlists`).
  - Next.js Embed Scraper extracting tracklists, covers, artists, and durations from any public Spotify link (`open.spotify.com/playlist/...`, `open.spotify.com/album/...`).
  - Direct YouTube Data API v3 integration for user playlists (`/v3/playlists?mine=true`) and liked songs (`/v3/videos?myRating=like`).
  - Channel sync by handle (`@username`) via `YoutubeExplode`.
- **Universal Deezer & iTunes Artist Portrait Engine**:
  - Uncompressed 1000x1000 official verified artist portraits from Deezer CDN (`picture_xl`) with iTunes Search API fallback.
  - Persistent disk caching in `SharedPreferences` (`artist_img_{name}`) for instant zero-latency offline loading.
  - Dynamic user affinity calculation (`getDynamicArtists`) reflecting the listener's actual individual taste across listening history, starred tracks, and synced accounts.
  - Reusable `ArtistPortrait` widget with shimmer loading and monogram initial fallbacks.
- **Online Concert Arena**:
  - Virtual live arena with curated and user-hosted stage broadcasts.
  - Unique verifiable seat booking passes (`ConcertBookingPass`) across General Admission, VIP Front Row Pit, and Backstage.
  - Interactive crowd synchronization with applause sound effects and digital glowstick telemetry.
- **8D & 16D Binaural Orbital Audio Engine**:
  - Real-time soundstage rotation simulating 360-degree orbital motion with configurable period (2s to 16s).
  - Elevation physics, room reverb modeling, and headphone acoustic virtualization.
- **Dedicated Architecture & Context Documentation**:
  - Added comprehensive `CONTEXT.md` covering system topology, audio DSP, streaming engines, and release packaging.
- **Dual-Platform Distribution via Web Hub**:
  - Backend delivery endpoints for both Android (`/api/app/download`) and iOS (`/api/app/download-ipa`).
  - AltStore / SideStore repository feed at `/altstore.json`.
  - Python build automation script (`scripts/build_ios_ipa.py`) generating standalone Mach-O ARM64 `.ipa` packages.

### Fixed
- **Zero Mock / Zero Stock Data**: Completely purged all generic Unsplash stock photo URLs across models, repositories, and UI views.
- **Version Alignment & Canonical Packaging**: Cleaned up package naming and synchronized release artifacts to `OpenAamps-v1.2.6.apk` and `OpenAamps-v1.2.6.ipa` under canonical package `com.aamps.openaamps`.
- **Strict Architectural Separation**: Enforced zero direct Firebase imports in UI views/widgets via unit tests; all persistence routes through `UserDataRepository`.
- **Design Guidelines**: Strictly zero purple in color accents and strictly zero emojis across user-facing strings and logs.

---

## [1.2.2] - 2026-09-30

### Added
- Clean Architecture separation between frontend UI views and backend services.
- Resilient authentication with email/password, Google sign-in, and instant local guest access.
- Cloud Firestore automatic synchronization for custom playlists and starred favorites via `UserDataRepository`.

---

## [1.2.1] - 2026-09-28

### Added
- Collaborative P2P Wi-Fi Music Jam: Decentralized multi-device listening party hosting with zero central server dependency.
- Automatic UDP broadcast beacon discovery on local Wi-Fi subnet.
- Subnet probing and resilient room code joining (e.g. `JAM-251`).

---

## [1.2.0] - 2026-09-25

### Added
- Dual output target routing between Raspberry Pi ALSA DAC streamer and local Android phone speakers/headphones.
- Dynamic category mood switching (Focus, Energize, Relax, Sad, Feel Good).
- Discord Rich Presence IPC daemon broadcasting real-time track metadata.
- 5 custom player styles: Modern, Vinyl, Minimal, Classic, and Glassmorphism.

---

## [1.1.0] - 2026-09-20

### Added
- YouTube 403 Forbidden Rate-Bypass Engine prioritizing muxed `itag 18` audio.
- Customizable network IP and port dialog for local Wi-Fi discovery.
- Live Raspberry Pi hardware telemetry monitor (CPU load, RAM utilization, SoC temperature).

---

## [1.0.0] - 2026-09-15

### Added
- Initial production release of OpenAAMPS for Android.
- 10-Band graphic equalizer with audiophile presets.
- Synchronized karaoke-style scrolling lyrics via LRCLIB.
- Bit-perfect ALSA DAC hardware streaming to Raspberry Pi.
- Sleep timer with smooth volume attenuation.
