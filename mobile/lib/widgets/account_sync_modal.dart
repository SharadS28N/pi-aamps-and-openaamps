import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../services/integration_service.dart';
import '../services/settings_service.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final i = IntegrationService.instance;
    _spotifyUserCtrl.text = i.spotifyUsername.isNotEmpty ? i.spotifyUsername : 'sharad_music';
    _spotifyClientCtrl.text = i.spotifyClientId;
    _spotifySecretCtrl.text = i.spotifyClientSecret;
    _spotifyTokenCtrl.text = i.spotifyAccessToken;
    _ytHandleCtrl.text = i.youtubeChannelHandle.isNotEmpty ? i.youtubeChannelHandle : '@music_listener';
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

  Future<void> _handleSpotifyConnect() async {
    setState(() => _isLoading = true);
    await IntegrationService.instance.saveSpotifyCredentials(
      username: _spotifyUserCtrl.text.trim(),
      clientId: _spotifyClientCtrl.text.trim(),
      clientSecret: _spotifySecretCtrl.text.trim(),
      accessToken: _spotifyTokenCtrl.text.trim(),
      connected: true,
    );
    setState(() => _isLoading = false);
    if (mounted) {
      AppAlert.show(
        context,
        'Spotify Account Connected!',
        icon: Icons.check_circle_rounded,
        isSuccess: true,
      );
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

  Future<void> _handleYouTubeConnect() async {
    setState(() => _isLoading = true);
    await IntegrationService.instance.saveYouTubeCredentials(
      handle: _ytHandleCtrl.text.trim(),
      apiKey: _ytKeyCtrl.text.trim(),
      connected: true,
    );
    setState(() => _isLoading = false);
    if (mounted) {
      AppAlert.show(
        context,
        'YouTube Account Connected!',
        icon: Icons.check_circle_rounded,
        isSuccess: true,
      );
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
                        'Account & Cloud Sync Hub',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Sync original Spotify & YouTube accounts and playlists',
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

        // Username
        const Text('Spotify Username / Display Name', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2C2C38)),
          ),
          child: TextField(
            controller: _spotifyUserCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'e.g. your_spotify_id',
              hintStyle: TextStyle(color: Colors.white38),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Accordion for Developer Portal Credentials
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
                'Spotify Developer Portal Credentials (Optional)',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        if (_showSpotifyDevFields) ...[
          const SizedBox(height: 10),
          const Text(
            'From developer.spotify.com/dashboard:',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 8),
          _buildTextField('Client ID', _spotifyClientCtrl, 'Spotify Client ID'),
          const SizedBox(height: 8),
          _buildTextField('Client Secret', _spotifySecretCtrl, 'Spotify Client Secret', obscure: true),
          const SizedBox(height: 8),
          _buildTextField('OAuth Access Token', _spotifyTokenCtrl, 'Bearer Token'),
        ],

        const SizedBox(height: 14),

        ElevatedButton(
          onPressed: _isLoading ? null : _handleSpotifyConnect,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1DB954),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Save & Connect Spotify Account', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),

        const SizedBox(height: 24),
        const Divider(color: Color(0xFF22222E)),
        const SizedBox(height: 16),

        // Import Spotify Playlist
        const Text(
          'Import Public Spotify Playlist / Album URL',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        const Text(
          'Paste any Spotify playlist, album, or track link to import instantly into your Open Aamps library.',
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
      ],
    );
  }

  Widget _buildYouTubeTab(Color accent) {
    final i = IntegrationService.instance;
    final isConnected = i.youtubeConnected;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
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

        // Channel Handle
        const Text('YouTube Channel Handle or ID', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2C2C38)),
          ),
          child: TextField(
            controller: _ytHandleCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'e.g. @username or UCxxxxxx',
              hintStyle: TextStyle(color: Colors.white38),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // YouTube Data API Key
        const Text('Google / YouTube Data API Key (Optional)', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2C2C38)),
          ),
          child: TextField(
            controller: _ytKeyCtrl,
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'AIzaSy...',
              hintStyle: TextStyle(color: Colors.white38),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),

        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: _isLoading ? null : _handleYouTubeConnect,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save & Connect YouTube Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),

        const SizedBox(height: 24),
        const Divider(color: Color(0xFF22222E)),
        const SizedBox(height: 16),

        // Import YouTube Playlist
        const Text(
          'Import YouTube / YouTube Music Playlist URL',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        const Text(
          'Paste any public YouTube or YouTube Music playlist link (e.g. https://music.youtube.com/playlist?list=...) to sync all tracks.',
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
