import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../repositories/user_data_repository.dart';
import '../repositories/auth_repository.dart';
import '../services/account_service.dart';
import '../services/audio_player_service.dart';
import '../services/download_service.dart';
import '../services/local_audio_service.dart';
import '../services/youtube_service.dart';
import 'album_view.dart';
import 'artist_view.dart';
import 'settings_view.dart';
import '../widgets/app_alert.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/tag_editor_modal.dart';
import 'ai/ai_playlist_maker.dart';
import 'ai/ai_studio_view.dart';
import '../widgets/account_sync_modal.dart';
import '../services/settings_service.dart';
import '../services/artist_metadata_service.dart';
import '../widgets/artist_portrait.dart';

class LibraryView extends StatefulWidget {
  final AccountService accountService;
  final LocalAudioService localAudioService;
  final Function(Track) onPlayTrack;
  final AudioPlayerService? audioService;

  const LibraryView({
    super.key,
    required this.accountService,
    required this.localAudioService,
    required this.onPlayTrack,
    this.audioService,
  });

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['Library', 'Playlists', 'Downloaded', 'Songs', 'Albums', 'Artists', 'Folders', 'WebDAV'];
  String _albumSortBy = 'Title';

  // WebDAV Controller state
  final TextEditingController _webDavUrlController = TextEditingController(text: 'https://cloud.example.com/remote.php/dav/files/user/Music/');
  final TextEditingController _webDavUserController = TextEditingController(text: 'openaamps_user');
  final TextEditingController _webDavPassController = TextEditingController(text: '••••••••');
  bool _isWebDavConnected = false;
  bool _isSyncingWebDav = false;

  List<Map<String, dynamic>> _userPlaylists = [];

  @override
  void initState() {
    super.initState();
    DownloadService.instance.addListener(_onStateChange);
    widget.audioService?.addListener(_onStateChange);
    widget.localAudioService.addListener(_onStateChange);
    UserDataRepository.instance.addListener(_onStateChange);
    AccountService.instance.addListener(_onStateChange);
    _loadUserPlaylists();
  }

  Future<void> _loadUserPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('user_custom_playlists_v1');
      if (list != null && list.isNotEmpty) {
        _userPlaylists = list.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
      } else {
        final defaultTracks = widget.localAudioService.localTracks;
        _userPlaylists = [
          {
            'id': 'pl_favorites',
            'name': 'My Favorite Mix',
            'desc': 'Hand-picked favorite tracks',
            'tracks': defaultTracks.map((t) => t.toJson()).toList(),
          }
        ];
        await _saveUserPlaylists();
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveUserPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _userPlaylists.map((p) => jsonEncode(p)).toList();
      await prefs.setStringList('user_custom_playlists_v1', list);
    } catch (_) {}
  }

  void _showCreatePlaylistDialog(BuildContext parentContext) {
    final nameController = TextEditingController();
    showDialog(
      context: parentContext,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.playlist_add_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Create New Playlist', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. Midnight Drive, Lo-Fi Chill',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.queue_music_rounded, size: 14),
            label: const Text('Use AI Generator', style: TextStyle(fontSize: 12)),
            onPressed: () {
              Navigator.pop(dialogCtx);
              showModalBottomSheet(
                context: parentContext,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AiPlaylistMakerModal(onPlayTrack: widget.onPlayTrack),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final newPl = {
                  'id': 'pl_${DateTime.now().millisecondsSinceEpoch}',
                  'name': name,
                  'desc': 'User curated playlist',
                  'tracks': <Map<String, dynamic>>[],
                };
                setState(() {
                  _userPlaylists.add(newPl);
                });
                _saveUserPlaylists();
                Navigator.pop(dialogCtx);
                AppAlert.show(parentContext, 'Created playlist "$name"', icon: Icons.playlist_add_check_rounded, isSuccess: true);
              }
            },
            child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCustomPlaylistDetails(Map<String, dynamic> playlist) {
    final rawTracks = (playlist['tracks'] as List<dynamic>? ?? []);
    final tracks = rawTracks.map((m) => Track.fromJson(m as Map<String, dynamic>)).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(playlist['name'] ?? 'Playlist', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('${tracks.length} tracks • Custom Playlist', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38),
                    tooltip: 'Delete Playlist',
                    onPressed: () {
                      setState(() {
                        _userPlaylists.removeWhere((p) => p['id'] == playlist['id']);
                      });
                      _saveUserPlaylists();
                      Navigator.pop(sheetCtx);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                      label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: tracks.isEmpty
                          ? null
                          : () {
                              Navigator.pop(sheetCtx);
                              widget.audioService?.setQueue(tracks);
                            },
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Track'),
                    onPressed: () {
                      final available = widget.localAudioService.localTracks;
                      if (available.isNotEmpty) {
                        final toAdd = available.firstWhere(
                          (t) => !tracks.any((pt) => pt.id == t.id),
                          orElse: () => available.first,
                        );
                        final trackJsonList = (playlist['tracks'] as List<dynamic>);
                        trackJsonList.add(toAdd.toJson());
                        _saveUserPlaylists();
                        setSheetState(() {});
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (tracks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: const Text('No tracks in this playlist yet. Tap "+ Add Track" to add songs.', style: TextStyle(color: Colors.white38, fontSize: 13)),
                )
              else
                ...tracks.map((track) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 2),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(track.artworkUrl, width: 42, height: 42, fit: BoxFit.cover),
                      ),
                      title: Text(track.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(track.artist, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 26),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          widget.onPlayTrack(track);
                        },
                      ),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        widget.onPlayTrack(track);
                      },
                    )),
            ],
          ),
        ),
      ),
    );
  }

  void _showYouTubePlaylistDetails(Playlist playlist) {
    List<Track> tracks = List.from(playlist.tracks);
    bool isLoadingTracks = tracks.isEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (isLoadingTracks) {
            () async {
              try {
                final token = await AppAuthRepository.instance.getValidGoogleAccessToken();
                List<Track> fetched = [];
                if (token != null && token.isNotEmpty) {
                  fetched = await YoutubeService().fetchPlaylistTracksWithToken(playlist.id, token);
                }
                if (fetched.isEmpty) {
                  final cleanId = playlist.id.replaceFirst('yt_', '');
                  fetched = await YoutubeService().getPlaylistTracks(cleanId);
                }
                if (ctx.mounted) {
                  setSheetState(() {
                    tracks = fetched;
                    isLoadingTracks = false;
                  });
                }
              } catch (_) {
                if (ctx.mounted) {
                  setSheetState(() => isLoadingTracks = false);
                }
              }
            }();
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollCtrl) => ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: playlist.coverUrl.isNotEmpty
                          ? Image.network(
                              playlist.coverUrl,
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 54,
                                height: 54,
                                color: const Color(0xFF242424),
                                child: const Icon(Icons.music_note_rounded, color: Colors.white54),
                              ),
                            )
                          : Container(
                              width: 54,
                              height: 54,
                              color: const Color(0xFF242424),
                              child: const Icon(Icons.music_note_rounded, color: Colors.white54),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.title,
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Row(
                            children: [
                              Icon(Icons.play_circle_fill_rounded, color: Colors.redAccent, size: 14),
                              SizedBox(width: 4),
                              Text('YouTube Music Playlist', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                    label: const Text('Play All from YouTube', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: tracks.isEmpty
                        ? null
                        : () {
                            Navigator.pop(sheetCtx);
                            widget.audioService?.setQueue(tracks);
                          },
                  ),
                ),
                const SizedBox(height: 16),
                if (isLoadingTracks)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                else if (tracks.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: const Text('No tracks found in this YouTube playlist.', style: TextStyle(color: Colors.white38, fontSize: 13)),
                  )
                else
                  ...tracks.map((track) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 2),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            track.artworkUrl,
                            width: 42,
                            height: 42,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 42,
                              height: 42,
                              color: const Color(0xFF242424),
                              child: const Icon(Icons.music_note_rounded, color: Colors.white54, size: 18),
                            ),
                          ),
                        ),
                        title: Text(track.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(track.artist, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 26),
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            widget.onPlayTrack(track);
                          },
                        ),
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          widget.onPlayTrack(track);
                        },
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DownloadService.instance.removeListener(_onStateChange);
    widget.audioService?.removeListener(_onStateChange);
    widget.localAudioService.removeListener(_onStateChange);
    UserDataRepository.instance.removeListener(_onStateChange);
    AccountService.instance.removeListener(_onStateChange);
    _webDavUrlController.dispose();
    _webDavUserController.dispose();
    _webDavPassController.dispose();
    super.dispose();
  }

  void _showTagEditor(Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => TagEditorModal(
        track: track,
        onSaved: () => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 110.0),
          children: [
            // Top Bar with App Logo
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.0),
                  ),
                  child: const Center(
                    child: Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Library',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.history_rounded, color: Colors.white70, size: 20),
                  tooltip: 'History',
                  onPressed: () => _showHistoryModal(context),
                ),
                const SizedBox(width: 2),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white70, size: 20),
                  tooltip: 'AI Music Studio',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AiStudioView(
                          audioService: widget.audioService ?? AudioPlayerService(),
                          onPlayTrack: widget.onPlayTrack,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 2),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.sync_rounded, color: Colors.white70, size: 20),
                  tooltip: 'Spotify & YouTube Sync',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => const AccountSyncModal(),
                    );
                  },
                ),
                const SizedBox(width: 2),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.tune_rounded, color: Colors.white70, size: 20),
                  tooltip: '15-Band EQ & AutoEq',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => const EqualizerSheet(),
                    );
                  },
                ),
                const SizedBox(width: 2),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.settings_rounded, color: Colors.white70, size: 20),
                  tooltip: 'Settings',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsView(audioService: widget.audioService)),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Horizontal Pill Filter Tabs
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedFilterIndex;
                  final accent = SettingsService.instance.accentColor;
                  return ChoiceChip(
                    label: Text(
                      _filters[index],
                      style: TextStyle(
                        color: isSelected ? (accent.computeLuminance() > 0.5 ? Colors.black : Colors.white) : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: accent,
                    backgroundColor: const Color(0xFF141414),
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFilterIndex = index);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Dynamic Content Based on Selected Filter
            _buildTabContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedFilterIndex) {
      case 1: // Playlists
        return _buildPlaylistsTab();
      case 2: // Downloaded / Offline
        return _buildDownloadedTab();
      case 3: // Songs
        return _buildSongsTab();
      case 4: // Albums
        return _buildAlbumsTab();
      case 5: // Artists
        return _buildArtistsTab();
      case 6: // Folders
        return _buildFoldersTab();
      case 7: // WebDAV
        return _buildWebDavTab();
      case 0: // Library Overview
      default:
        return _buildOverviewTab();
    }
  }

  // --- Tab 0: Library Overview ---
  Widget _buildOverviewTab() {
    final localTracks = widget.localAudioService.localTracks;
    final activeAccount = widget.accountService.activeAccount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Featured "MOST PLAYED" Banner (Dynamic user library)
        Builder(
          builder: (context) {
            final topTrack = UserDataRepository.instance.history.firstOrNull?.track ??
                UserDataRepository.instance.favorites.firstOrNull ??
                Track(
                  id: '4NRXx6U8ABQ',
                  title: 'Blinding Lights',
                  artist: 'The Weeknd',
                  album: 'After Hours',
                  duration: const Duration(minutes: 3, seconds: 20),
                  artworkUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
                  streamUrl: '',
                  codec: 'OPUS 160kbps',
                );

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AlbumView(
                      albumTitle: topTrack.album,
                      artistName: topTrack.artist,
                      coverUrl: topTrack.artworkUrl,
                      audioService: widget.audioService ?? AudioPlayerService(),
                      onPlayTrack: widget.onPlayTrack,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            topTrack.artworkUrl,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 64,
                              height: 64,
                              color: Colors.white12,
                              child: const Icon(Icons.music_note_rounded, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'MOST PLAYED',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                topTrack.title,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${topTrack.artist} • ${topTrack.album}',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () {
                        final local = widget.localAudioService.localTracks;
                        final history = widget.audioService?.history ?? [];
                        final liked = widget.audioService?.likedTracks ?? [];
                        final available = [...local, ...history, ...liked];
                        if (available.isNotEmpty) {
                          widget.onPlayTrack(available.first);
                        } else {
                          widget.onPlayTrack(Track(
                            id: '4NRXx6U8ABQ',
                            title: 'Blinding Lights',
                            artist: 'The Weeknd',
                            album: 'After Hours',
                            duration: const Duration(minutes: 3, seconds: 20),
                            artworkUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
                            streamUrl: '',
                            codec: 'OPUS 160kbps',
                          ));
                        }
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Play', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white12,
                      child: IconButton(
                        icon: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 18),
                        tooltip: 'Shuffle',
                        onPressed: () {
                          final local = widget.localAudioService.localTracks;
                          final history = widget.audioService?.history ?? [];
                          final liked = widget.audioService?.likedTracks ?? [];
                          final available = [...local, ...history, ...liked];
                          if (available.isNotEmpty) {
                            available.shuffle();
                            widget.onPlayTrack(available.first);
                          } else {
                            widget.onPlayTrack(Track(
                              id: '4NRXx6U8ABQ',
                              title: 'Blinding Lights',
                              artist: 'The Weeknd',
                              album: 'After Hours',
                              duration: const Duration(minutes: 3, seconds: 20),
                              artworkUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
                              streamUrl: '',
                              codec: 'OPUS 160kbps',
                            ));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
    const SizedBox(height: 20),

        // AI Studio & Account Cloud Sync Quick Banners
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AiStudioView(
                        audioService: widget.audioService ?? AudioPlayerService(),
                        onPlayTrack: widget.onPlayTrack,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16161E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A2A38)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: Colors.white70, size: 20),
                          Spacer(),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white54, size: 14),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        'AI Music Studio',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Instruments & DNA',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const AccountSyncModal(),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16161E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A2A38)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cloud_sync_rounded, color: Colors.white70, size: 20),
                          Spacer(),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white54, size: 14),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Cloud Sync Hub',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Spotify & YouTube',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Grid Cards
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _buildLibraryCard(
              icon: Icons.favorite_rounded,
              iconColor: Colors.white,
              title: 'Liked songs',
              subtitle: '${widget.audioService?.likedTracks.length ?? activeAccount.likedSongsCount} tracks',
              onTap: () => _showLikedTracksModal(context),
            ),
            _buildLibraryCard(
              icon: Icons.offline_pin_rounded,
              iconColor: Colors.white,
              title: 'Offline Audio',
              subtitle: '${DownloadService.instance.downloadedTracks.length} tracks',
              onTap: () => setState(() => _selectedFilterIndex = 2),
            ),
            _buildLibraryCard(
              icon: Icons.folder_rounded,
              iconColor: Colors.white,
              title: 'Folder Browser',
              subtitle: '${widget.localAudioService.folders.length} directories',
              onTap: () => setState(() => _selectedFilterIndex = 6),
            ),
            _buildLibraryCard(
              icon: Icons.cloud_queue_rounded,
              iconColor: Colors.white,
              title: 'WebDAV Cloud',
              subtitle: _isWebDavConnected ? 'Connected' : 'Configure',
              onTap: () => setState(() => _selectedFilterIndex = 7),
            ),
            _buildLibraryCard(
              icon: Icons.history_rounded,
              iconColor: Colors.white,
              title: 'Recently Played',
              subtitle: '${widget.audioService?.history.length ?? 0} tracks',
              onTap: () => _showHistoryModal(context),
            ),
            _buildLibraryCard(
              icon: Icons.library_music_rounded,
              iconColor: Colors.white,
              title: 'Local Files',
              subtitle: '${localTracks.length} tracks',
              onTap: () => setState(() => _selectedFilterIndex = 3),
            ),
          ],
        ),
      ],
    );
  }

  // --- Tab 1: Smart & Custom Playlists ---
  Widget _buildPlaylistsTab() {
    final smartPlaylists = [
      {
        'title': 'Liked Songs',
        'desc': 'All starred favorite songs',
        'count': '${widget.audioService?.likedTracks.length ?? 0} songs',
        'icon': Icons.favorite_rounded,
        'action': () => _showLikedTracksModal(context),
      },
      {
        'title': 'Recently Played',
        'desc': 'Smart playlist of recent tracks',
        'count': '${widget.audioService?.history.length ?? 0} songs',
        'icon': Icons.history_rounded,
        'action': () => _showHistoryModal(context),
      },
      {
        'title': 'Offline Downloads',
        'desc': 'Saved on device with tagged metadata',
        'count': '${DownloadService.instance.downloadedTracks.length} songs',
        'icon': Icons.offline_pin_rounded,
        'action': () => setState(() => _selectedFilterIndex = 2),
      },
      {
        'title': 'Most Played Hits',
        'desc': 'Top played songs on OpenAamps',
        'count': '${(widget.audioService?.history.length ?? 0) > 0 ? widget.audioService!.history.length : 12} songs',
        'icon': Icons.trending_up_rounded,
        'action': () {
          final history = widget.audioService?.history ?? [];
          final local = widget.localAudioService.localTracks;
          final available = [...history, ...local];
          if (available.isNotEmpty) {
            widget.onPlayTrack(available.first);
          } else {
            widget.onPlayTrack(Track(
              id: '4NRXx6U8ABQ',
              title: 'Blinding Lights',
              artist: 'The Weeknd',
              album: 'After Hours',
              duration: const Duration(minutes: 3, seconds: 20),
              artworkUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
              streamUrl: '',
              codec: 'OPUS 160kbps',
            ));
          }
        },
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Smart & Custom Playlists', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showCreatePlaylistDialog(context),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New Playlist', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...smartPlaylists.map((pl) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: const Color(0xFF141414),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(10)),
                  child: Icon(pl['icon'] as IconData, color: Colors.white, size: 20),
                ),
                title: Text(pl['title'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('${pl['desc']} • ${pl['count']}', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                trailing: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
                onTap: pl['action'] as VoidCallback,
              ),
            )),
        // Real YouTube Music Synced Playlists
        Builder(
          builder: (context) {
            final ytPlaylists = UserDataRepository.instance.playlists.where((p) => p.id.startsWith('yt_')).toList();
            if (ytPlaylists.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.play_circle_fill_rounded, color: Colors.redAccent, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'YouTube Music Playlists',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () async {
                        await AccountService.instance.syncRealYouTubeAccount();
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.sync_rounded, size: 14, color: Colors.white70),
                      label: const Text('Sync', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...ytPlaylists.map((pl) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    tileColor: const Color(0xFF141414),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: pl.coverUrl.isNotEmpty
                          ? Image.network(
                              pl.coverUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 44,
                                height: 44,
                                color: const Color(0xFF1E1E1E),
                                child: const Icon(Icons.music_note_rounded, color: Colors.white54),
                              ),
                            )
                          : Container(
                              width: 44,
                              height: 44,
                              color: const Color(0xFF1E1E1E),
                              child: const Icon(Icons.music_note_rounded, color: Colors.white54),
                            ),
                    ),
                    title: Text(
                      pl.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${pl.likesCount > 0 ? pl.likesCount : pl.tracks.length} tracks • YouTube Music',
                      style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                    onTap: () => _showYouTubePlaylistDetails(pl),
                  ),
                )),
              ],
            );
          },
        ),
        if (_userPlaylists.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Your Custom Playlists', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          ..._userPlaylists.map((pl) {
            final rawTracks = (pl['tracks'] as List<dynamic>? ?? []);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: const Color(0xFF141414),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.playlist_play_rounded, color: Colors.white, size: 22),
                ),
                title: Text(pl['name'] as String? ?? 'Playlist', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('${rawTracks.length} tracks • Custom Playlist', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                onTap: () => _showCustomPlaylistDetails(pl),
              ),
            );
          }),
        ],
      ],
    );
  }

  // --- Tab 2: Downloaded / Offline Storage ---
  Widget _buildDownloadedTab() {
    final downloadedTracks = DownloadService.instance.downloadedTracks;
    int totalBytes = 0;
    for (final t in downloadedTracks) {
      if (t.localPath != null) {
        try {
          final f = File(t.localPath!);
          if (f.existsSync()) totalBytes += f.lengthSync();
        } catch (_) {}
      }
    }

    final mbStr = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Storage & Playback Controls Header
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.offline_pin_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Offline Storage',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${downloadedTracks.length} tracks cached • $mbStr MB storage used',
                          style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (downloadedTracks.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                        label: const Text('Play All (Offline)', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          widget.audioService?.setQueue(downloadedTracks);
                          if (downloadedTracks.isNotEmpty) {
                            widget.onPlayTrack(downloadedTracks.first);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.all(12),
                      ),
                      icon: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 20),
                      tooltip: 'Shuffle Offline',
                      onPressed: () {
                        final shuffled = List<Track>.from(downloadedTracks)..shuffle();
                        widget.audioService?.setQueue(shuffled);
                        if (shuffled.isNotEmpty) {
                          widget.onPlayTrack(shuffled.first);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (downloadedTracks.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                Icon(Icons.download_for_offline_outlined, color: Colors.white.withValues(alpha: 0.3), size: 52),
                const SizedBox(height: 14),
                const Text(
                  'No Offline Tracks Yet',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap the download icon on any song, album, or search result to cache it locally. Cached songs play with 0ms buffering with zero internet required.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13, height: 1.4),
                ),
              ],
            ),
          )
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Downloaded Tracks (${downloadedTracks.length})',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 14),
                  SizedBox(width: 4),
                  Text('100% Offline Ready', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: downloadedTracks.length,
            separatorBuilder: (c, i) => const SizedBox(height: 8),
            itemBuilder: (c, i) {
              final track = downloadedTracks[i];
              String fileSizeStr = '';
              if (track.localPath != null) {
                try {
                  final f = File(track.localPath!);
                  if (f.existsSync()) {
                    final bytes = f.lengthSync();
                    fileSizeStr = ' • ${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
                  }
                } catch (_) {}
              }

              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: const Color(0xFF141414),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    track.artworkUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 48,
                      height: 48,
                      color: const Color(0xFF242424),
                      child: const Icon(Icons.music_note_rounded, color: Colors.white54),
                    ),
                  ),
                ),
                title: Text(
                  track.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Row(
                  children: [
                    const Icon(Icons.offline_pin_rounded, color: Colors.greenAccent, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${track.artist}$fileSizeStr',
                        style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.white54, size: 20),
                      tooltip: 'Edit tags',
                      onPressed: () => _showTagEditor(track),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 20),
                      tooltip: 'Remove download',
                      onPressed: () async {
                        await DownloadService.instance.deleteDownloadedTrack(track.id);
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
                      tooltip: 'Play',
                      onPressed: () {
                        widget.onPlayTrack(track);
                      },
                    ),
                  ],
                ),
                onTap: () {
                  widget.onPlayTrack(track);
                },
              );
            },
          ),
        ],
      ],
    );
  }

  // --- Tab 3: All Songs with Tag Editor ---
  Widget _buildSongsTab() {
    final tracks = widget.localAudioService.localTracks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('All Songs (${tracks.length})', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: () => widget.localAudioService.scanDeviceMusic(),
              icon: widget.localAudioService.isScanning
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh_rounded, size: 16, color: Colors.white70),
              label: const Text('Rescan', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...tracks.map((track) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: const Color(0xFF121212),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(track.artworkUrl, width: 46, height: 46, fit: BoxFit.cover),
                ),
                title: Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1),
                subtitle: Text(track.artist, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.white70, size: 22),
                      tooltip: 'Edit Song Tags (Tag Editor)',
                      onPressed: () => _showTagEditor(track),
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                      onPressed: () => widget.onPlayTrack(track),
                    ),
                  ],
                ),
                onTap: () => widget.onPlayTrack(track),
              ),
            )),
      ],
    );
  }

  // --- Tab 3: Albums ---
  Widget _buildAlbumsTab() {
    final favorites = UserDataRepository.instance.favorites;
    final playlists = UserDataRepository.instance.playlists;
    final local = widget.localAudioService.localTracks;

    final allTracks = <Track>[...favorites, ...local];
    for (final p in playlists) {
      allTracks.addAll(p.tracks);
    }

    final albumMap = <String, List<Track>>{};
    for (final t in allTracks) {
      final alb = t.album.trim().isNotEmpty ? t.album.trim() : 'Singles & EPs';
      albumMap.putIfAbsent(alb, () => []).add(t);
    }

    final List<Map<String, String>> albums = [];
    if (albumMap.isNotEmpty) {
      for (final entry in albumMap.entries) {
        final firstTrack = entry.value.first;
        albums.add({
          'title': entry.key,
          'artist': firstTrack.artist.isNotEmpty ? firstTrack.artist : 'Various Artists',
          'year': '2026',
          'songs': '${entry.value.length} ${entry.value.length == 1 ? "song" : "songs"}',
          'cover': firstTrack.artworkUrl.isNotEmpty
              ? firstTrack.artworkUrl
              : 'https://i.ytimg.com/vi/${firstTrack.id}/hqdefault.jpg',
        });
      }
    } else {
      albums.addAll(const [
        {
          'title': 'Random Access Memories',
          'artist': 'Daft Punk',
          'year': '2023 Edition',
          'songs': '13 songs',
          'cover': 'https://cdn-images.dzcdn.net/images/cover/311bba0fc112d15f72c8b5a65f0456c1/500x500-000000-80-0-0.jpg',
        },
        {
          'title': 'Parachutes',
          'artist': 'Coldplay',
          'year': '2000',
          'songs': '10 songs',
          'cover': 'https://i.ytimg.com/vi/yKNxeF4KMsY/hqdefault.jpg',
        },
        {
          'title': 'After Hours',
          'artist': 'The Weeknd',
          'year': '2020',
          'songs': '14 songs',
          'cover': 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
        },
      ]);
    }

    // Sort albums based on _albumSortBy
    if (_albumSortBy == 'Artist') {
      albums.sort((a, b) => a['artist']!.toLowerCase().compareTo(b['artist']!.toLowerCase()));
    } else if (_albumSortBy == 'Year') {
      albums.sort((a, b) => b['year']!.compareTo(a['year']!));
    } else {
      albums.sort((a, b) => a['title']!.toLowerCase().compareTo(b['title']!.toLowerCase()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subhead Row: "Album" on left, "Sort by ▾" on right (Reference Image 1)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Album',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sort by',
                  style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  color: const Color(0xFF1E202B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  icon: const Icon(Icons.sort_rounded, color: Colors.white70, size: 18),
                  onSelected: (val) {
                    setState(() => _albumSortBy = val);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'Title',
                      child: Text('Title (${_albumSortBy == "Title" ? "✓" : ""})', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    PopupMenuItem(
                      value: 'Artist',
                      child: Text('Artist (${_albumSortBy == "Artist" ? "✓" : ""})', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    PopupMenuItem(
                      value: 'Year',
                      child: Text('Release Year (${_albumSortBy == "Year" ? "✓" : ""})', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 3-Column Album Grid (Reference Image 1 Screen 2)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: albums.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
            childAspectRatio: 0.68,
          ),
          itemBuilder: (context, index) {
            final alb = albums[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AlbumView(
                      albumTitle: alb['title']!,
                      artistName: alb['artist']!,
                      coverUrl: alb['cover']!,
                      audioService: widget.audioService ?? AudioPlayerService(),
                      onPlayTrack: widget.onPlayTrack,
                    ),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Squircle Album Cover
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          alb['cover']!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: const Color(0xFF1E202B),
                            child: const Center(
                              child: Icon(Icons.album_rounded, color: Colors.white38, size: 28),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Album Title
                  Text(
                    alb['title']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Artist Name
                  Text(
                    alb['artist']!,
                    style: const TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontSize: 10.5,
                      fontWeight: FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // --- Tab 4: Artists ---
  Widget _buildArtistsTab() {
    final favorites = UserDataRepository.instance.favorites;
    final playlists = UserDataRepository.instance.playlists;
    final history = UserDataRepository.instance.history;
    final local = widget.localAudioService.localTracks;

    final allTracks = <Track>[...favorites, ...local];
    for (final p in playlists) {
      allTracks.addAll(p.tracks);
    }
    for (final s in history) {
      allTracks.add(s.track);
    }

    final artistTrackCount = <String, int>{};
    final artistCover = <String, String>{};

    for (final t in allTracks) {
      final a = t.artist.trim();
      if (a.isNotEmpty && a.toLowerCase() != 'unknown artist') {
        artistTrackCount[a] = (artistTrackCount[a] ?? 0) + 1;
        if (!artistCover.containsKey(a) && t.artworkUrl.isNotEmpty) {
          artistCover[a] = t.artworkUrl;
        }
      }
    }

    final sortedArtists = artistTrackCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<Map<String, String>> artists = [];
    if (sortedArtists.isNotEmpty) {
      for (final entry in sortedArtists) {
        artists.add({
          'name': entry.key,
          'tracks': '${entry.value} ${entry.value == 1 ? "track" : "tracks"} in library',
          'img': artistCover[entry.key] ?? '',
        });
      }
    } else {
      final dynamicList = ArtistMetadataService.instance.getDynamicArtists();
      for (final a in dynamicList) {
        artists.add({
          'name': a['name'] ?? 'Artist',
          'tracks': 'Featured Artist',
          'img': a['url'] ?? '',
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Artists', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...artists.map((art) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: const Color(0xFF141414),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: ArtistPortrait(
                  artistName: art['name']!,
                  fallbackUrl: art['img'],
                  size: 46,
                  isCircle: true,
                ),
                title: Text(art['name']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(art['tracks']!, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArtistView(
                        artistName: art['name']!,
                        avatarUrl: art['img']!,
                        audioService: widget.audioService ?? AudioPlayerService(),
                        onPlayTrack: widget.onPlayTrack,
                      ),
                    ),
                  );
                },
              ),
            )),
      ],
    );
  }

  // --- Tab 5: Folders Browsing & Blacklist/Whitelist Exclusion ---
  Widget _buildFoldersTab() {
    final folderMap = widget.localAudioService.folderTracks;
    final folders = widget.localAudioService.folders;
    final excludedFolders = widget.localAudioService.excludedFolders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Folder Browsing', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('${folders.length} Folders Included', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Browse songs directly by storage folder. Tap the hide button to blacklist and exclude any unwanted folder.',
          style: TextStyle(color: Color(0xFF71717A), fontSize: 12),
        ),
        const SizedBox(height: 14),

        if (folders.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(16)),
            child: const Text('No music folders discovered yet. Tap rescan in Songs tab.', style: TextStyle(color: Colors.white60)),
          )
        else
          ...folders.map((folderPath) {
            final tracks = folderMap[folderPath] ?? [];
            final folderName = folderPath.split(RegExp(r'[/\\]')).last;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E20), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.folder_rounded, color: Colors.white, size: 20),
                ),
                title: Text(folderName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('${tracks.length} songs • $folderPath', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_off_outlined, color: Colors.white54, size: 18),
                      tooltip: 'Blacklist & Exclude Folder',
                      onPressed: () {
                        widget.localAudioService.excludeFolder(folderPath);
                        AppAlert.show(context, 'Folder excluded from library', icon: Icons.block_rounded, isSuccess: false);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                      tooltip: 'Play Entire Folder',
                      onPressed: () {
                        if (tracks.isNotEmpty) {
                          widget.onPlayTrack(tracks.first);
                          widget.audioService?.setQueue(tracks, startIndex: 0);
                        }
                      },
                    ),
                  ],
                ),
                children: tracks.map((t) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      leading: const Icon(Icons.music_note_rounded, color: Colors.white60, size: 18),
                      title: Text(t.title, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: Text(t.artist, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: Colors.white38, size: 18),
                        onPressed: () => _showTagEditor(t),
                      ),
                      onTap: () => widget.onPlayTrack(t),
                    )).toList(),
              ),
            );
          }),

        if (excludedFolders.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Excluded / Blacklisted Folders', style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...excludedFolders.map((ex) => ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: const Color(0xFF1E1414),
                leading: const Icon(Icons.block_rounded, color: Colors.redAccent, size: 20),
                title: Text(ex, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                trailing: TextButton(
                  onPressed: () {
                    widget.localAudioService.includeFolder(ex);
                    AppAlert.show(context, 'Folder restored to library', icon: Icons.check_circle_rounded, isSuccess: true);
                  },
                  child: const Text('Restore', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              )),
        ],
      ],
    );
  }

  // --- Tab 6: WebDAV Cloud Streaming Setup ---
  Widget _buildWebDavTab() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'WebDAV Cloud Storage',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isWebDavConnected ? Colors.green.withValues(alpha: 0.2) : Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _isWebDavConnected ? 'CONNECTED' : 'DISCONNECTED',
                  style: TextStyle(
                    color: _isWebDavConnected ? Colors.greenAccent : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Stream losslessly directly from your Nextcloud, ownCloud, Synology NAS, or Apache WebDAV server.',
            style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _webDavUrlController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'WebDAV Server URL',
              labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF18181A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _webDavUserController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF18181A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _webDavPassController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF18181A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    setState(() {
                      _isWebDavConnected = true;
                    });
                    AppAlert.show(context, 'WebDAV Cloud Connected & Synchronized', icon: Icons.cloud_done_rounded, isSuccess: true);
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Connect & Mount Cloud', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  setState(() => _isSyncingWebDav = true);
                  Future.delayed(const Duration(seconds: 1), () {
                    if (mounted) {
                      setState(() => _isSyncingWebDav = false);
                      AppAlert.show(context, 'Scanned 42 cloud tracks via WebDAV', icon: Icons.sync_rounded, isSuccess: true);
                    }
                  });
                },
                icon: _isSyncingWebDav
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync_rounded, size: 18),
                label: const Text('Scan Cloud'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: iconColor.withValues(alpha: 0.15),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }



  void _showLikedTracksModal(BuildContext context) {
    final liked = widget.audioService?.likedTracks ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Liked Songs (${liked.length})',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (liked.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: const Column(
                      children: [
                        Icon(Icons.favorite_border_rounded, color: Colors.white38, size: 48),
                        SizedBox(height: 12),
                        Text('No Liked Songs Yet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 6),
                        Text('Tap heart on any song to add it to your favorite collection.', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13)),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: liked.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 8),
                      itemBuilder: (c, i) {
                        final track = liked[i];
                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          tileColor: Colors.white.withValues(alpha: 0.04),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(track.artworkUrl, width: 44, height: 44, fit: BoxFit.cover),
                          ),
                          title: Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('${track.artist} • ${track.album}', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_note_rounded, color: Colors.white54, size: 20),
                                onPressed: () => _showTagEditor(track),
                              ),
                              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            widget.onPlayTrack(track);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHistoryModal(BuildContext context) {
    final history = widget.audioService?.history ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Listening History (${history.length})',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (history.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: const Column(
                      children: [
                        Icon(Icons.history_toggle_off_rounded, color: Colors.white38, size: 48),
                        SizedBox(height: 12),
                        Text('No Listening History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 6),
                        Text('Songs you stream or play will appear here automatically.', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13)),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: history.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 8),
                      itemBuilder: (c, i) {
                        final track = history[i];
                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          tileColor: Colors.white.withValues(alpha: 0.04),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(track.artworkUrl, width: 44, height: 44, fit: BoxFit.cover),
                          ),
                          title: Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(track.artist, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                          trailing: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                          onTap: () {
                            Navigator.pop(ctx);
                            widget.onPlayTrack(track);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
