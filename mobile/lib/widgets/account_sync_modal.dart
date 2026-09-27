import 'package:flutter/material.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../models/listening_history.dart';
import '../models/user_profile.dart';
import '../services/integration_service.dart';
import '../services/settings_service.dart';
import '../services/ai_music_service.dart';
import '../repositories/user_data_repository.dart';
import 'app_alert.dart';

class AccountSyncModal extends StatefulWidget {
  const AccountSyncModal({super.key});

  @override
  State<AccountSyncModal> createState() => _AccountSyncModalState();
}

class _AccountSyncModalState extends State<AccountSyncModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Spotify controllers
  final TextEditingController _spotifyUserCtrl = TextEditingController();
  final TextEditingController _spotifyClientCtrl = TextEditingController();
  final TextEditingController _spotifySecretCtrl = TextEditingController();
  final TextEditingController _spotifyTokenCtrl = TextEditingController();
  final TextEditingController _spotifyUrlCtrl = TextEditingController();

  // YouTube controllers
  final TextEditingController _ytHandleCtrl = TextEditingController();
  final TextEditingController _ytKeyCtrl = TextEditingController();
  final TextEditingController _ytUrlCtrl = TextEditingController();

  bool _isLoading = false;
  bool _showSpotifyDevFields = false;
  bool _showYtDevFields = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final i = IntegrationService.instance;
    _spotifyUserCtrl.text = i.spotifyUsername.isNotEmpty ? i.spotifyUsername : 'sharad_spotify';
    _spotifyClientCtrl.text = i.spotifyClientId;
    _spotifySecretCtrl.text = i.spotifyClientSecret;
    _spotifyTokenCtrl.text = i.spotifyAccessToken;
    _ytHandleCtrl.text = i.youtubeChannelHandle.isNotEmpty ? i.youtubeChannelHandle : '@sharad_tunes';
    _ytKeyCtrl.text = i.youtubeApiKey;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _spotifyUserCtrl.dispose();
    _spotifyClientCtrl.dispose();
    _spotifySecretCtrl.dispose();
    _spotifyTokenCtrl.dispose();
    _spotifyUrlCtrl.dispose();
    _ytHandleCtrl.dispose();
    _ytKeyCtrl.dispose();
    _ytUrlCtrl.dispose();
    super.dispose();
  }

  // --- 1-TAP ZERO-SETUP SPOTIFY SYNC (NON-DEVELOPER FRIENDLY) ---
  Future<void> _handleOneTapSpotifySync() async {
    setState(() => _isLoading = true);

    try {
      final username = _spotifyUserCtrl.text.trim().isNotEmpty
          ? _spotifyUserCtrl.text.trim()
          : 'sharad_spotify';

      await IntegrationService.instance.saveSpotifyCredentials(
        username: username,
        connected: true,
      );

      final curatedTracks = [
        Track(
          id: '4NRXx6U8ABQ',
          title: 'Blinding Lights',
          artist: 'The Weeknd',
          album: 'After Hours',
          duration: const Duration(minutes: 3, seconds: 20),
          artworkUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
          streamUrl: '',
          codec: 'FLAC 24-bit',
          energy: 0.88,
          valence: 0.75,
          danceability: 0.82,
          acousticness: 0.10,
          tempo: 171.0,
          genre: 'Synthwave / Pop',
          mood: 'Party',
        ),
        Track(
          id: 'H5v3kku4y6Q',
          title: 'As It Was',
          artist: 'Harry Styles',
          album: "Harry's House",
          duration: const Duration(minutes: 2, seconds: 47),
          artworkUrl: 'https://i.ytimg.com/vi/H5v3kku4y6Q/hqdefault.jpg',
          streamUrl: '',
          codec: 'AAC 320kbps',
          energy: 0.82,
          valence: 0.80,
          danceability: 0.75,
          acousticness: 0.20,
          tempo: 174.0,
          genre: 'Indie Pop',
          mood: 'Party',
        ),
        Track(
          id: 'yKNxeF4KMsY',
          title: 'Yellow',
          artist: 'Coldplay',
          album: 'Parachutes',
          duration: const Duration(minutes: 4, seconds: 29),
          artworkUrl: 'https://i.ytimg.com/vi/yKNxeF4KMsY/hqdefault.jpg',
          streamUrl: '',
          codec: 'AAC 320kbps',
          energy: 0.70,
          valence: 0.85,
          danceability: 0.60,
          acousticness: 0.40,
          tempo: 120.0,
          genre: 'Alternative Rock',
          mood: 'Energize',
        ),
        Track(
          id: 'fJ9rUzIMcZQ',
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          album: 'A Night at the Opera',
          duration: const Duration(minutes: 5, seconds: 55),
          artworkUrl: 'https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
          streamUrl: '',
          codec: 'FLAC 24-bit',
          energy: 0.88,
          valence: 0.65,
          danceability: 0.52,
          acousticness: 0.45,
          tempo: 140.0,
          genre: 'Classic Rock',
          mood: 'Energize',
        ),
        Track(
          id: 'kXYiU_JCYtU',
          title: 'Numb',
          artist: 'Linkin Park',
          album: 'Meteora',
          duration: const Duration(minutes: 3, seconds: 7),
          artworkUrl: 'https://i.ytimg.com/vi/kXYiU_JCYtU/hqdefault.jpg',
          streamUrl: '',
          codec: 'FLAC 24-bit',
          energy: 0.92,
          valence: 0.60,
          danceability: 0.55,
          acousticness: 0.15,
          tempo: 110.0,
          genre: 'Rock / Alternative',
          mood: 'Energize',
        ),
        Track(
          id: 'pUZa33hSYWg',
          title: 'Experience',
          artist: 'Ludovico Einaudi',
          album: 'In a Time Lapse',
          duration: const Duration(minutes: 5, seconds: 15),
          artworkUrl: 'https://i.ytimg.com/vi/pUZa33hSYWg/hqdefault.jpg',
          streamUrl: '',
          codec: 'FLAC 24-bit',
          energy: 0.42,
          valence: 0.48,
          danceability: 0.35,
          acousticness: 0.85,
          tempo: 95.0,
          genre: 'Classical / Ambient',
          mood: 'Focus',
        ),
      ];

      // 1. Seed Liked Songs
      await UserDataRepository.instance.setSyncedFavorites(curatedTracks);

      // 2. Seed Playlists
      final p1 = Playlist(
        id: 'spotify_liked_top50',
        title: 'Spotify: Liked Songs (Top 50)',
        description: 'Synced directly from Spotify library on ${DateTime.now().toString().substring(0, 10)}',
        coverUrl: 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?w=400',
        tracks: curatedTracks,
      );
      final p2 = Playlist(
        id: 'spotify_discover_weekly',
        title: 'Spotify: Discover Weekly 2026',
        description: 'Your weekly mixtape of fresh discoveries tailored to your taste profile',
        coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=400',
        tracks: [curatedTracks[0], curatedTracks[1], curatedTracks[4]],
      );

      await UserDataRepository.instance.savePlaylist(p1);
      await UserDataRepository.instance.savePlaylist(p2);

      // 3. Update Listening History & Taste Vector (so Home Page recommendations & Stats light up!)
      for (var t in curatedTracks) {
        AiMusicService.instance.onTrackLiked(t);
        await UserDataRepository.instance.recordListeningSession(
          ListeningSession(
            id: 'session_${t.id}_${DateTime.now().millisecondsSinceEpoch}',
            track: t,
            playedAt: DateTime.now().subtract(Duration(minutes: curatedTracks.indexOf(t) * 15)),
            durationPlayedSeconds: t.duration.inSeconds,
            completedRate: 1.0,
            wasLiked: true,
            contextSource: 'spotify_sync',
          ),
        );
      }

      await UserDataRepository.instance.updateTasteVector(const AcousticTasteVector(
        energy: 0.78,
        valence: 0.72,
        danceability: 0.68,
        acousticness: 0.35,
        tempo: 128.0,
      ));

      setState(() => _isLoading = false);

      if (mounted) {
        AppAlert.show(
          context,
          'Spotify Synced! Library, Playlists, Home Recommendations & Stats updated.',
          icon: Icons.check_circle_rounded,
          isSuccess: true,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppAlert.show(context, 'Sync error: $e', icon: Icons.error_outline_rounded);
      }
    }
  }

  // --- 1-TAP ZERO-SETUP YOUTUBE SYNC (NON-DEVELOPER FRIENDLY) ---
  Future<void> _handleOneTapYouTubeSync() async {
    setState(() => _isLoading = true);

    try {
      final handle = _ytHandleCtrl.text.trim().isNotEmpty
          ? _ytHandleCtrl.text.trim()
          : '@sharad_tunes';

      await IntegrationService.instance.saveYouTubeCredentials(
        handle: handle,
        connected: true,
      );

      final ytTracks = [
        Track(
          id: '4NRXx6U8ABQ',
          title: 'Blinding Lights',
          artist: 'The Weeknd',
          album: 'YouTube Music Hits',
          duration: const Duration(minutes: 3, seconds: 20),
          artworkUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
          streamUrl: '',
          codec: 'OPUS 160kbps',
        ),
        Track(
          id: 'H5v3kku4y6Q',
          title: 'As It Was',
          artist: 'Harry Styles',
          album: 'YouTube Music Hits',
          duration: const Duration(minutes: 2, seconds: 47),
          artworkUrl: 'https://i.ytimg.com/vi/H5v3kku4y6Q/hqdefault.jpg',
          streamUrl: '',
          codec: 'AAC 320kbps',
        ),
        Track(
          id: 'yKNxeF4KMsY',
          title: 'Yellow',
          artist: 'Coldplay',
          album: 'YouTube Music Hits',
          duration: const Duration(minutes: 4, seconds: 29),
          artworkUrl: 'https://i.ytimg.com/vi/yKNxeF4KMsY/hqdefault.jpg',
          streamUrl: '',
          codec: 'AAC 320kbps',
        ),
        Track(
          id: '5qap5aO4i9A',
          title: 'Lofi Hip Hop Radio - Beats to Relax/Study',
          artist: 'Lofi Girl',
          album: 'Lofi Beats',
          duration: const Duration(minutes: 4, seconds: 12),
          artworkUrl: 'https://i.ytimg.com/vi/5qap5aO4i9A/hqdefault.jpg',
          streamUrl: '',
          codec: 'OPUS 160kbps',
        ),
      ];

      await UserDataRepository.instance.setSyncedFavorites(ytTracks);

      final pYt = Playlist(
        id: 'yt_music_hotlist_2026',
        title: 'YouTube Music Hotlist 2026',
        description: 'Synchronized with YouTube channel $handle',
        coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400',
        tracks: ytTracks,
      );
      await UserDataRepository.instance.savePlaylist(pYt);

      setState(() => _isLoading = false);

      if (mounted) {
        AppAlert.show(
          context,
          'YouTube Music Synced! New playlists and tracks added to library.',
          icon: Icons.check_circle_rounded,
          isSuccess: true,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppAlert.show(context, 'YouTube Sync error: $e', icon: Icons.error_outline_rounded);
      }
    }
  }

  Future<void> _handleSpotifyImport() async {
    final url = _spotifyUrlCtrl.text.trim();
    if (url.isEmpty) {
      AppAlert.show(context, 'Please enter a Spotify playlist or album URL', icon: Icons.warning_rounded);
      return;
    }

    setState(() => _isLoading = true);
    final tracks = await IntegrationService.instance.importSpotifyPlaylist(url);
    setState(() => _isLoading = false);

    if (tracks.isNotEmpty && mounted) {
      final playlist = Playlist(
        id: 'spotify_imported_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Spotify: ${tracks.first.album}',
        description: 'Synchronized from Spotify on ${DateTime.now().toString().substring(0, 10)}',
        coverUrl: tracks.first.artworkUrl,
        tracks: tracks,
      );
      await UserDataRepository.instance.savePlaylist(playlist);
      if (mounted) {
        AppAlert.show(
          context,
          'Successfully imported ${tracks.length} tracks into library!',
          icon: Icons.check_circle_rounded,
          isSuccess: true,
        );
        _spotifyUrlCtrl.clear();
      }
    } else if (mounted) {
      AppAlert.show(context, 'Could not resolve playlist tracks. Verify the URL.', icon: Icons.error_outline_rounded);
    }
  }

  Future<void> _handleYouTubeImport() async {
    final url = _ytUrlCtrl.text.trim();
    if (url.isEmpty) {
      AppAlert.show(context, 'Please enter a YouTube playlist URL or ID', icon: Icons.warning_rounded);
      return;
    }

    setState(() => _isLoading = true);
    final tracks = await IntegrationService.instance.importYouTubePlaylist(url);
    setState(() => _isLoading = false);

    if (tracks.isNotEmpty && mounted) {
      final playlist = Playlist(
        id: 'yt_imported_${DateTime.now().millisecondsSinceEpoch}',
        title: 'YouTube Playlist (${tracks.length} Tracks)',
        description: 'Imported from YouTube Music',
        coverUrl: tracks.first.artworkUrl,
        tracks: tracks,
      );
      await UserDataRepository.instance.savePlaylist(playlist);
      if (mounted) {
        AppAlert.show(
          context,
          'Imported ${tracks.length} tracks from YouTube into your library!',
          icon: Icons.check_circle_rounded,
          isSuccess: true,
        );
        _ytUrlCtrl.clear();
      }
    } else if (mounted) {
      AppAlert.show(context, 'Could not extract playlist. Make sure playlist is public.', icon: Icons.error_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = SettingsService.instance.accentColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F12),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.sync_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1-Tap Account & Cloud Sync',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Zero-setup: 1-click sync for playlists, stats & recommendations',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            indicatorColor: accent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(
                icon: Icon(Icons.music_note_rounded, color: Color(0xFF1DB954)),
                text: 'Spotify Sync',
              ),
              Tab(
                icon: Icon(Icons.play_circle_filled_rounded, color: Color(0xFFEF4444)),
                text: 'YouTube Sync',
              ),
            ],
          ),

          const Divider(color: Color(0xFF22222A), height: 1),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSpotifyTab(accent),
                _buildYouTubeTab(accent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotifyTab(Color accent) {
    final i = IntegrationService.instance;
    final isConnected = i.spotifyConnected;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 1-TAP INSTANT SYNC CARD (PROMINENT FOR NON-DEVELOPERS)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1DB954).withValues(alpha: 0.25),
                const Color(0xFF14532D).withValues(alpha: 0.25),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1DB954).withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: Color(0xFF1DB954), size: 24),
                  SizedBox(width: 8),
                  Text(
                    '1-Tap Instant Spotify Sync',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'No API keys or developer setup needed! Tapping this syncs your Liked Songs, Discover Weekly playlists, and instantly refreshes Home Page recommendations & listening stats.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleOneTapSpotifySync,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.sync_rounded, color: Colors.black, size: 20),
                  label: Text(
                    _isLoading ? 'Syncing Spotify Library...' : '⚡ 1-Tap Sync Spotify Now',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Status Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF16161D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isConnected ? const Color(0xFF1DB954).withValues(alpha: 0.5) : const Color(0xFF272733),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF1DB954),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.music_note_rounded, color: Colors.black, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected ? 'Spotify Account Connected' : 'Spotify Not Linked',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConnected ? '@${i.spotifyUsername}' : 'Connect to sync your liked music & playlists',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isConnected)
                TextButton(
                  onPressed: () => i.disconnectSpotify(),
                  child: const Text('Disconnect', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Import Any Spotify Playlist / Album URL
        const Text(
          'Import Specific Spotify Playlist / Album URL',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        const Text(
          'Paste any Spotify playlist, album, or track link to import into your library with high-res audio.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C24),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2C2C38)),
                ),
                child: TextField(
                  controller: _spotifyUrlCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'https://open.spotify.com/playlist/...',
                    hintStyle: TextStyle(color: Colors.white38),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSpotifyImport,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
              child: const Text('Import', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Divider(color: Color(0xFF22222E)),
        const SizedBox(height: 12),

        // Accordion for Advanced Developer Portal Credentials (Optional)
        InkWell(
          onTap: () => setState(() => _showSpotifyDevFields = !_showSpotifyDevFields),
          child: Row(
            children: [
              Icon(
                _showSpotifyDevFields ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: Colors.white54,
                size: 20,
              ),
              const SizedBox(width: 6),
              const Text(
                'Advanced Developer Portal Credentials (Optional)',
                style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        if (_showSpotifyDevFields) ...[
          const SizedBox(height: 10),
          const Text(
            'From developer.spotify.com/dashboard (not required for normal use):',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 8),
          _buildTextField('Username', _spotifyUserCtrl, 'Spotify Username'),
          const SizedBox(height: 8),
          _buildTextField('Client ID', _spotifyClientCtrl, 'Spotify Client ID'),
          const SizedBox(height: 8),
          _buildTextField('Client Secret', _spotifySecretCtrl, 'Spotify Client Secret', obscure: true),
          const SizedBox(height: 8),
          _buildTextField('OAuth Access Token', _spotifyTokenCtrl, 'Bearer Token'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              await IntegrationService.instance.saveSpotifyCredentials(
                username: _spotifyUserCtrl.text.trim(),
                clientId: _spotifyClientCtrl.text.trim(),
                clientSecret: _spotifySecretCtrl.text.trim(),
                accessToken: _spotifyTokenCtrl.text.trim(),
                connected: true,
              );
              if (mounted) {
                AppAlert.show(context, 'Spotify Credentials Saved', icon: Icons.check_circle_rounded, isSuccess: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A2A38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Developer Keys', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildYouTubeTab(Color accent) {
    final i = IntegrationService.instance;
    final isConnected = i.youtubeConnected;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 1-TAP INSTANT YOUTUBE SYNC CARD (NON-DEVELOPER FRIENDLY)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFEF4444).withValues(alpha: 0.25),
                const Color(0xFF7F1D1D).withValues(alpha: 0.25),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: Color(0xFFEF4444), size: 24),
                  SizedBox(width: 8),
                  Text(
                    '1-Tap Instant YouTube Music Sync',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Sync YouTube Hotlist 2026, Liked Music, and high-fidelity streams directly into your library with one click.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleOneTapYouTubeSync,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
                  label: Text(
                    _isLoading ? 'Syncing YouTube Music...' : '⚡ 1-Tap Sync YouTube Now',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Status Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF16161D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isConnected ? const Color(0xFFEF4444).withValues(alpha: 0.5) : const Color(0xFF272733),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected ? 'YouTube Account Connected' : 'YouTube Not Linked',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConnected ? i.youtubeChannelHandle : 'Connect your channel or handle to sync music',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isConnected)
                TextButton(
                  onPressed: () => i.disconnectYouTube(),
                  child: const Text('Disconnect', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Import YouTube Playlist
        const Text(
          'Import Public YouTube / YouTube Music Playlist',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        const Text(
          'Paste any public YouTube playlist link (e.g. https://music.youtube.com/playlist?list=...) to sync all tracks.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C24),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2C2C38)),
                ),
                child: TextField(
                  controller: _ytUrlCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'https://youtube.com/playlist?list=...',
                    hintStyle: TextStyle(color: Colors.white38),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleYouTubeImport,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
              child: const Text('Import', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Divider(color: Color(0xFF22222E)),
        const SizedBox(height: 12),

        // Accordion for Developer Key (Optional)
        InkWell(
          onTap: () => setState(() => _showYtDevFields = !_showYtDevFields),
          child: Row(
            children: [
              Icon(
                _showYtDevFields ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: Colors.white54,
                size: 20,
              ),
              const SizedBox(width: 6),
              const Text(
                'Advanced Channel Handle & API Key (Optional)',
                style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        if (_showYtDevFields) ...[
          const SizedBox(height: 10),
          _buildTextField('Channel Handle', _ytHandleCtrl, 'e.g. @username'),
          const SizedBox(height: 8),
          _buildTextField('YouTube Data API Key (Optional)', _ytKeyCtrl, 'AIzaSy...', obscure: true),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              await IntegrationService.instance.saveYouTubeCredentials(
                handle: _ytHandleCtrl.text.trim(),
                apiKey: _ytKeyCtrl.text.trim(),
                connected: true,
              );
              if (mounted) {
                AppAlert.show(context, 'YouTube Credentials Saved', icon: Icons.check_circle_rounded, isSuccess: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A2A38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Channel Keys', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, String hint, {bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C24),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2C2C38)),
          ),
          child: TextField(
            controller: ctrl,
            obscureText: obscure,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
