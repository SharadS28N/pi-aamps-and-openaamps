# Changelog — OpenAAMPS & Pi-AAMPS

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.7] - 2026-10-03

### Added
- **Deep Neural Melody Hum-to-Song Retrieval Pipeline**:
  - Windowed STFT log-mel spectrogram extraction (80 frequency bins over time slices).
  - Deep convolutional-residual melody encoder generating 128-dimensional unit melody embeddings.
  - Sub-millisecond approximate nearest neighbor (ANN) cosine similarity search against indexed vector database.
  - Triplet-loss distance ranking and calibrated confidence metrics for instant song identification.
- **Dual-Mode Live Concert Arena Platform**:
  - Online Virtual Live Stage with 4K 60FPS video stream preview and 3D binaural spatial audio.
  - Multi-camera angle switcher (Main Stage, Front Row 360, Drummer Cam, Drone Cam) with virtual audience cheering.
  - Physical Stadium Tour Ticket Pass Management featuring authentic tour schedules (Coldplay, The Weeknd, Billie Eilish).
  - Digital contactless NFC / dynamic QR pass cards with VIP tier selection, row and seat allocation.
- **High-Fidelity Figma System Design**:
  - Live Figma wireframe canvas at `https://www.figma.com/design/c0V5G8aNxKpbeAGRnSNVFz/OpenAamps-%25E2%2580%2594-Hi-Fi-Wireframe---System-Design?node-id=0-1&p=f&t=SfRy9cb1TRNYtT6J-0`.
  - 801 vector nodes across 6 production screen frames: Home & Concert Arena, Now Playing (with exclusive codec badge), AMOLED Studio Equalizer, Deep Learning Hum-to-Song Recognition, Library & WebDAV, and Physical Stadium Booking.

### Changed & Fixed
- **Equalizer & 8D Studio DSP Overhaul**:
  - Subtle AMOLED black theme (`#0F0F13` / `#0A0A0E`) matching dynamic system accent color.
  - Completely eliminated 8D audio dropouts and buffer stutter by removing high-frequency pitch re-sampling and JNI spam.
  - Replaced rotary dial calculation with a 270-degree studio knob arc (135° to 45° with 90° bottom deadzone).
  - Implemented strict 0% min and 100% max midpoint boundary clamping, eliminating the 98% to 0% wrap-around loop.
  - Mapped Bass Boost directly to hardware low-shelf (<250 Hz) and Virtualizer to high-shelf spatial presence (2.5 kHz to 16 kHz).
- **Exclusive Audio Codec Badge Placement**:
  - Removed all inline audio codec badges from Quick Picks, search results, recognition modals, library track subtitles, and concert setlists.
  - Codec badges are now shown exclusively in the Audio Player (`PlayerView` / `NowPlayingView`).
- **Persistent User Login Sessions**:
  - Cached authentication sessions persist across app cold starts until explicit user sign-out.
- **WebDAV Personal Cloud Storage Card**:
  - Fixed card layout using flex container constraints with `TextOverflow.ellipsis`, ensuring the `DISCONNECTED` status badge stays neatly inside the card container.
- **Verified Artist Headshots**:
  - Replaced song artwork and movie poster fallbacks with official uncompressed artist portraits in "Keep listening".

---

## [1.2.6] - 2026-10-02

### Added
- **Interactive Figma Design System Showcase**:
  - Live Figma canvas mockup at `/design` (`frontend/design_showcase.html`) with pan/zoom tools, color tokens, typography scales, radii, and inspectable code.
  - Interactive artboards for Now Playing, 3-Column Album Library, Studio Equalizer with dual dials, and Home Stream.
- **8D & 16D Binaural Doppler & Pinna HRTF Spatial Engine**:
  - Real-time angular azimuth orbital panning $\theta(t) = \omega \cdot t$ (8D at 0.08 rad/s, 16D at 0.16 rad/s).
  - Doppler frequency micro-pitch shifts ($\pm 0.8\%$) matching orbital direction towards and away from each ear.
  - Pinna HRTF head-shadow emulation: up to -6.0dB attenuation on treble bands (2.5kHz–16kHz) when audio orbits behind the listener.
  - Proximity-based volume swell and target gain boost via Android `LoudnessEnhancer`.
- **Offline-First P2P Jamming & Direct IP Connect**:
  - Direct host IP connection (`http://<ip>:8765`) alongside standard room codes (`JAM-XXXX`).
  - Graceful fallback when Firestore is uninitialized or unauthenticated, allowing 100% offline Wi-Fi P2P jamming.
- **Live Concert Stage Setlist**:
  - Interactive setlist embedded directly inside the live concert stage view with active track indicators, durations, and 1-tap playback that reapplies venue-specific impulse acoustic responses.
- **Live 1-Tap Spotify & YouTube Music Sync**:
  - Live Bearer Token OAuth querying official Spotify Web API endpoints (`/v1/me`, `/v1/me/top/artists`, `/v1/me/top/tracks`, `/v1/me/player/recently-played`, `/v1/me/playlists`).
  - Next.js Embed Scraper extracting tracklists, covers, artists, and durations from any public Spotify link.
  - Direct YouTube Data API v3 integration for user playlists and liked songs.
  - Channel sync by handle (`@username`) via `YoutubeExplode`.
- **Universal Deezer & iTunes Artist Portrait Engine**:
  - Uncompressed 1000x1000 official verified artist portraits from Deezer CDN (`picture_xl`) with iTunes Search API fallback.
  - Persistent disk caching in `SharedPreferences` for zero-latency offline loading.

### Fixed
- **Mobile UI Overflow Elimination**:
  - Replaced rigid column constraints in `player_view.dart` with responsive `LayoutBuilder` and `SingleChildScrollView`, dynamically scaling album art and eliminating all `RenderFlex overflowed` errors on any screen size.
  - Redesigned playback controls to clean 5-button layout matching user reference specifications.
- **iPhone / iOS Download Visibility**:
  - Added dedicated iOS download cards, 1-tap AltStore repository buttons, Sideloadly IPA instructions, and Safari PWA setup to both `frontend/download.html` and `frontend/index.html`.
- **Concert Arena Playback**: Fixed track loading and setlist execution within the virtual concert arena.
- **Jamming Mode Stability**: Eliminated Firebase uninitialized crashes during party hosting and peer discovery.

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
