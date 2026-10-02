# Pi-AAMPS & OpenAAMPS — System Architecture & Context

Comprehensive developer documentation for the **pi-aamps** hardware streamer and the **OpenAAMPS** cross-platform audiophile mobile client.

---

## 1. Project Overview & Ecosystem

The ecosystem delivers a unified, audiophile-grade music streaming experience bridging custom Raspberry Pi hardware and mobile devices:

```
                      +---------------------------------------+
                      |       Raspberry Pi (pi-aamps)         |
                      |  - FastAPI Backend (Port 8000)        |
                      |  - PipeWire / ALSA DAC Hi-Fi Streamer |
                      |  - Hardware Telemetry & Web Player    |
                      +-------------------+-------------------+
                                          |
                        Wi-Fi LAN / WebSocket / mDNS
                                          |
         +--------------------------------+--------------------------------+
         |                                                                 |
+--------v-----------------------+                       +-----------------v---------------+
|     OpenAAMPS Mobile Client    |                       |      Web Application & PWA      |
|  - Android (APK: v1.2.6)       |                       |  - Hi-Fi Web Player (HTML5/ES6) |
|  - iOS (IPA / AltStore: v1.2.6)|                       |  - App Showcase & Download Hub  |
|  - 10-Band Studio DSP          |                       |  - Direct APK/IPA Distribution  |
|  - 8D/16D Binaural Engine      |                       +---------------------------------+
|  - 1-Tap Spotify/YouTube Sync  |
|  - Online Concert Arena        |
+--------------------------------+
```

### Core Components
1. **pi-aamps (Backend & Web Hub)**: Python 3.11+ / FastAPI daemon providing low-latency audio playback, PipeWire/ALSA soundcard management, YouTube streaming, system telemetry, Discord RPC, and WebSockets.
2. **OpenAAMPS (Mobile Application)**: Flutter client (`com.aamps.openaamps`) targeting Android (8.0+) and iOS (14.0+). Operates standalone with local playback or as a lossless Wi-Fi casting remote.
3. **Web Player & Distribution Portal**: Responsive web interface (`frontend/index.html`) and dedicated installation showcase (`frontend/download.html`).

---

## 2. Directory Structure & Key Files

```
raspberry-pi-music-player/
|-- CONTEXT.md                    # Core architecture & system documentation (this file)
|-- README.md                     # GitHub repository overview & quickstart
|-- CHANGELOG.md                  # Comprehensive release history
|-- backend/                      # Python FastAPI server
|   |-- main.py                   # REST endpoints, WebSockets, downloads, telemetry
|   |-- player.py                 # MPV / ALSA playback engine
|   |-- youtube.py                # YouTube streaming & search resolver
|   |-- bluetooth_service.py      # BlueZ A2DP sink & rfkill manager
|   |-- hifi_services.py          # DAC detection, CPU/RAM/SoC temperature metrics
|   |-- discord_rpc.py            # Discord IPC rich presence daemon
|   `-- party_service.py          # Multi-room synchronized jamming backend
|-- frontend/                     # Web player & installation pages
|   |-- index.html                # Pi-AAMPS browser web player
|   |-- download.html             # Mobile app showcase & APK/IPA installer
|   |-- altstore.json             # Official AltStore iOS source repository
|   `-- assets/                   # Vector branding, app icons, badges
|-- mobile/                       # Flutter mobile client (OpenAAMPS)
|   |-- pubspec.yaml              # Version specification (1.2.6+22)
|   |-- lib/
|   |   |-- models/               # Domain entities (Track, Playlist, UserProfile, Account)
|   |   |-- repositories/         # UserDataRepository, AuthRepository (clean architecture)
|   |   |-- services/
|   |   |   |-- spotify_service.dart          # Real Spotify Web API & Embed Next.js scraper
|   |   |   |-- youtube_service.dart          # YouTube Data API v3 & Explode stream extractor
|   |   |   |-- artist_metadata_service.dart  # Deezer 1000x1000 CDN portraits & taste affinity
|   |   |   |-- audio_player_service.dart     # JustAudio wrapper, 8D/16D DSP, 15-band EQ
|   |   |   |-- concert_service.dart          # Online Concert Arena & crowd sync
|   |   |   |-- party_service.dart            # P2P Wi-Fi jam session host/client
|   |   |   `-- update_service.dart           # In-app canonical package update checker
|   |   |-- views/                # HomeView, SearchView, LibraryView, PlayerView, ArtistView
|   |   `-- widgets/              # ArtistPortrait, AccountSyncModal, EqualizerModal, AppAlert
|   `-- test/                     # Unit, widget, and clean-architecture boundary tests
|-- releases/                     # Binary build artifacts & package manifests
|   |-- OpenAamps-v1.2.6.apk      # Production Android APK
|   |-- OpenAamps-latest.apk      # Canonical Android APK symlink/copy
|   |-- OpenAamps-v1.2.6.ipa      # Standalone iOS Application Bundle
|   |-- OpenAamps-latest.ipa      # Canonical iOS IPA copy
|   `-- altstore.json             # Production AltStore repository feed
`-- scripts/                      # Build automation & tooling
    `-- build_ios_ipa.py          # Standalone Mach-O arm64 IPA generator & packager
```

---

## 3. Subsystem Architecture

### 3.1 Real Streaming & Account Synchronization
OpenAAMPS adheres to a strict **Zero Mock / Zero Stock Data** policy:

- **Spotify Integration (`SpotifyService`)**:
  - Live Bearer Token OAuth: Queries official Spotify Web API endpoints:
    - `/v1/me`: Profile picture, display name, subscriber tier.
    - `/v1/me/top/artists`: Top listened artists with official Spotify CDN covers (`i.scdn.co`).
    - `/v1/me/top/tracks` & `/v1/me/player/recently-played`: Listening history and playback telemetry.
    - `/v1/me/playlists`: User playlist hierarchy with track counts.
  - Public Next.js Embed Scraper: Automatically scrapes tracklists, durations, artists, and covers from any `open.spotify.com/playlist/...` or `open.spotify.com/album/...` link without API credentials.
- **YouTube Music Integration (`YoutubeService`)**:
  - Authenticated Google/YouTube sync via Data API v3: `/v3/playlists?mine=true` and `/v3/videos?myRating=like`.
  - Channel / Public Playlist Resolver: Resolves `@handle` uploads or playlist IDs into high-resolution playable tracks via `YoutubeExplode`.
  - Rate-Bypass Engine: Prioritizes itag 18 (360p MP4 muxed AAC stereo) and itag 140 (AAC 320kbps) with `ratebypass=yes`, eliminating HTTP 403 Forbidden throttling.
- **Universal Artist Metadata Engine (`ArtistMetadataService`)**:
  - Queries Deezer Search API for verified, uncompressed 1000x1000 artist portraits (`picture_xl`).
  - Fallback to iTunes Search API for complete discography verification.
  - Persistent caching in `SharedPreferences` (`artist_img_{name}`) for instant offline rendering.
  - `getDynamicArtists()` analyzes listening sessions, favorites, and playlists to dynamically compute individual taste affinity.
- **`ArtistPortrait` Widget**:
  - Unified circular/rounded avatar renderer with shimmer loading placeholders and monogram initial fallbacks. Rejects generic stock photo URLs.

### 3.2 Audiophile Audio DSP Engine
Built on `just_audio` with low-level spatial processing:
- **10/15-Band Parametric Equalizer**: 32Hz to 16kHz graphic EQ with audiophile presets (Bass Boost, Vocal Clarity, Treble Air, Hi-Fi Flat).
- **AutoEq Calibration**: Database of frequency response corrections for over 2,500 headphone models.
- **8D & 16D Binaural Orbital Engine**:
  - **Orbital Azimuth Trajectory**: Evaluates sound source position along the horizontal plane $\theta(t) = \omega \cdot t$ where angular frequency $\omega_{8D} = 0.08\text{ rad/s}$ (~12s per orbit) and $\omega_{16D} = 0.16\text{ rad/s}$ with a dual harmonic vertical figure-8 elevation cycle.
  - **Doppler Micro-Pitch Shifts**: Physically alters perceived playback frequency as the sound source approaches and recedes from each ear:
    $$\Delta f = 1.0 + 0.008 \cdot \sin(\theta)$$
  - **Pinna HRTF (Head-Related Transfer Function) Treble Attenuation**: When the orbital azimuth passes behind the listener's head ($\cos(\theta) < 0$), high-frequency acoustic shadowing is simulated by dynamically attenuating equalizer bands between 2.5kHz and 16kHz by up to -6.0dB, reproducing natural ear flap (pinna) filtering.
  - **Dynamic Proximity & Loudness Swell**: Synchronously modulates track volume and Android `LoudnessEnhancer` target gain (up to +3.5dB) as the source passes through close proximity points.
- **Dynamic Codec Management**: Adaptive streaming between AAC 320kbps, Opus 160kbps, and lossless FLAC (24-bit 96kHz).

### 3.3 Online Concert Arena
Virtual live performance platform (`ConcertService`):
- **Stage Broadcasts**: Curated and user-hosted virtual concerts (e.g. Coldplay at Wembley Stadium Arena, Daft Punk Alive 2007).
- **Live Stage Setlist Integration**: Interactive concert setlist rendered directly on the live stage view with real-time active track indicators, track durations, and 1-tap playback that automatically re-applies venue-specific acoustic impulse filters.
- **4 Venue Acoustic Impulse Models**:
  - *Stadium Mega-Bass*: High-power sub-bass resonance, long reverberation tail (2.4s).
  - *Arena Reverb*: Expansive mid-range hall reflections with distinct spatial decay.
  - *Amphitheater Surround*: Semi-open outdoor diffusion with wide lateral stereo spread.
  - *Underground Club*: Tight low-end punch, punchy early reflections, low decay time.
- **Seat Booking Passes**: Generates unique verifiable passes (`ConcertBookingPass`) across General Admission, VIP Front Row Pit, and Backstage.
- **Crowd Synchronization**: Interactive synchronized crowd cheering, live applause audio effects, and digital glowstick telemetry.

### 3.4 P2P Wi-Fi Music Jam (Offline-First)
Decentralized collaborative listening (`PartyService`):
- **Zero Cloud Dependency**: Host device spins up an embedded HTTP/WebSocket server (`PartyHostServer`) on local Wi-Fi port `8765`.
- **Direct IP Joining**: Peers can connect directly via host local IP (e.g., `192.168.1.150:8765`) or standard 6-character room codes (`JAM-XXXX`).
- **Automatic UDP Peer Discovery**: UDP broadcast beacon on `255.255.255.255:8766` periodically broadcasts room identity for zero-configuration discovery on the local subnet.
- **Clock Synchronization**: Periodic heartbeat messages adjust playback timestamp offsets to achieve sub-15ms inter-device sync across peers.
- **Fault-Tolerant Cloud Fallback**: All Firestore WAN connections are wrapped in graceful offline fallbacks; if Firestore is uninitialized or unauthenticated, local Wi-Fi jamming operates with zero errors and zero crashes.

### 3.5 Figma Design System Specification
The visual design language is codified in `frontend/design_showcase.html`:
- **Canvas Base**: AMOLED True Black (`#000000`) for battery efficiency and high visual contrast.
- **Surface Elevation**: Zinc containers (`#121214` and `#1E1E22`) with subtle 1px border borders (`rgba(255,255,255,0.08)` to `0.12`).
- **Color Accents**:
  - Electric Purple (`#A855F7`): Now playing and equalizer primary tone.
  - Neon Sunset Orange (`#F97316`): Home view floating play buttons and highlights.
  - Emerald Green (`#10B981` / `#22C55E`): pi-aamps hardware connection indicators and verified status.
- **Typography Tokens**:
  - Display Header: Space Grotesk 800 (28pt) with -0.6 tracking.
  - Now Playing Title: Inter Bold (22pt) with -0.4 tracking.
  - Artist Subhead: Inter Medium (14pt to 15pt) in Zinc-400 (`#A1A1AA`).
  - Codec & Telemetry: JetBrains Mono (10pt to 11pt).
- **Geometric Radii**:
  - Album Squircles: 14px (3-column grid) to 28px (Now Playing hero).
  - Floating Action Buttons: Circular 9999px with soft 20px blur drop shadows.
  - Zero Overflow Guarantee: Built with responsive `LayoutBuilder` and `SingleChildScrollView`.

---

## 4. Release & Packaging Pipeline

### Version Standard: `1.2.6+22`
- **Application ID**: `com.aamps.openaamps`
- **Android Target**: SDK 36 (compileSdk), minSdk 21, targetSdk 35
- **iOS Target**: iOS 14.0+, 64-bit ARM (`arm64`)

### Release Artifacts
All production packages reside in `releases/`:
- `OpenAamps-v1.2.6.apk` & `OpenAamps-latest.apk`: Signed Android application package.
- `OpenAamps-v1.2.6.ipa` & `OpenAamps-latest.ipa`: iOS application archive containing Mach-O ARM64 binaries and Flutter assets.
- `altstore.json`: AltStore / SideStore compatible repository manifest.

### Web Distribution Endpoints (`backend/main.py`)
- `GET /api/app/download`: Delivers the latest production APK with `Content-Disposition: attachment; filename="OpenAamps-v1.2.6.apk"`.
- `GET /api/app/download-ipa`: Delivers the latest iOS IPA with `Content-Disposition: attachment; filename="OpenAamps-v1.2.6.ipa"`.
- `GET /api/app/info`: JSON metadata with version, download URLs, and package name.
- `GET /altstore.json`: Serves the AltStore repository manifest.
- `GET /download` or `GET /download.html`: Serves the download showcase website.

---

## 5. Development & Verification Guide

### Prerequisites
- Flutter 3.29+ / Dart 3.7+
- Android SDK Platform 36 & Platform-Tools (ADB)
- Python 3.10+ with `fastapi`, `uvicorn`, `pydantic`
- Node.js / NPM (optional for web tooling)

### Core Commands

```bash
# 1. Analyze Dart Code (Must report 0 issues)
cd mobile
dart analyze lib/

# 2. Run Comprehensive Test Suite
flutter test

# 3. Build Production Android APK
flutter build apk --debug

# 4. Generate iOS IPA Package & AltStore JSON
cd ..
python scripts/build_ios_ipa.py

# 5. Install on Connected Android Device
adb devices
adb install -r releases/OpenAamps-v1.2.6.apk

# 6. Launch Mobile App via ADB
adb shell am start -n com.aamps.openaamps/com.openaamps.open_aamps.MainActivity

# 7. Run Backend Development Server
cd backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

---

## 6. Sideloading Instructions for End Users

### Android
1. Download `OpenAamps-v1.2.6.apk` from the web portal (`/download`).
2. When prompted, enable "Install unknown apps" in system settings.
3. Tap Install. Future updates will overwrite in place under `com.aamps.openaamps`.

### iOS (iPhone & iPad)
1. **AltStore / SideStore**: Add `https://raw.githubusercontent.com/SharadS28N/pi-aamps-and-openaamps/main/releases/altstore.json` as a source, or tap **1-Tap Add to AltStore** on the download page.
2. **Sideloadly / Scarlet / TrollStore**: Download `OpenAamps-v1.2.6.ipa` and drag into the sideloading tool using any free Apple ID.
3. **Safari Web App (PWA)**: Navigate to the web player in Safari, tap **Share**, and select **Add to Home Screen**.

---

## 7. Distributed Streaming Architecture & Playback Lifecycle Specification

OpenAAMPS is architected around the design principles of modern global streaming platforms (Spotify, YouTube Music, Apple Music), coordinating a distributed ecosystem:

```
+---------------------------------------------------------------------------------------+
|                                    CLIENT APPLICATION                                 |
|                                                                                       |
|  [ Cold Boot & Capability Verification ]                                              |
|      |                                                                                |
|      v                                                                                |
|  [ Idle Playback Engine (No phantom track, activeTrack = null) ]                      |
|      |                                                                                |
|      v                                                                                |
|  [ Dynamic Catalog Fetch: Trending, Curated Moods, Taste Matrix ]                     |
+------------------------------------------+--------------------------------------------+
                                           | User Selects Track
                                           v
+---------------------------------------------------------------------------------------+
|                                AUDIO DELIVERY PIPELINE                                |
|                                                                                       |
|  1. Stream Resolution: YouTube / Invidious / Local Piped CDN Cache                    |
|  2. Adaptive Delivery: Chunked HTTP proxy with prefetch buffer                        |
|  3. Hardware Audio Pipeline: Native decoders (AAC-LC / OPUS / FLAC)                   |
|  4. DSP Processing: Android 10-Band EQ, Loudness Enhancer, Doppler 8D/16D Orbital     |
|  5. OS Sample Routing: PCM audio fed to Android AudioTrack / PipeWire / Bluetooth A2DP|
|  6. UI State Emergence: Mini-player slides in, Now Playing queue populated            |
+---------------------------------------------------------------------------------------+
```

### 1. Cold Boot & Idle State Lifecycle
- **Clean Initial State**: Upon cold boot, `_activeTrack` is `null` and `AudioPlayerService` is in an `idle` processing state.
- **No Hardcoded Playback**: The application does NOT auto-populate a default song or force a phantom mini-player on launch. The bottom navigation bar renders flush with the screen base until playback is initiated.
- **Device & Hardware Capabilities**: Permissions for notifications (Android 13+ lock screen media controls) and audio outputs are verified asynchronously without blocking initial catalog presentation.

### 2. Metadata Catalog Delivery & CDN Caching
- **Home View Delivery**: Structured metadata (track IDs, titles, artists, albums, artwork CDN URLs, durations, codecs) is requested and rendered.
- **Dynamic Recent vs. Trending**: When playback history exists, the user's authentic listening trail is showcased under *"Recently Played"*. On fresh boots with zero history, the interface gracefully transitions to *"Trending Hits"*, presenting diverse global chart-toppers.
- **Cached Asset Pipelines**: Remote artwork thumbnails are cached locally on device storage to prevent redundant network consumption.

### 3. Audio Delivery, Stream Resolution & PCM Decoding Pipeline
- **Stream URL Resolution**: When the user taps a track, `YoutubeService` resolves the direct media stream endpoint.
- **Local Proxy Streaming**: `LocalStreamProxy` streams media through a localhost HTTP server, handling chunked transfer encoding, unbounded byte-range requests, and pre-buffering.
- **Low-Latency PCM Delivery**: Audio samples are decoded via native device decoders and fed into the OS audio subsystem.
- **Mini-Player Emergence**: Upon track playback initialization, `NowPlayingBar` mounts smoothly at the bottom of the interface, providing rapid access to the full `PlayerView` sound studio.