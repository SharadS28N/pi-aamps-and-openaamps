import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/pi_aamps_service.dart';
import '../services/account_service.dart';
import '../services/youtube_service.dart';
import '../services/settings_service.dart';
import '../services/download_service.dart';
import '../widgets/account_switcher_modal.dart';
import '../widgets/output_target_modal.dart';
import '../widgets/app_alert.dart';
import 'settings_view.dart';
import 'concert_view.dart';
import 'stats_view.dart';
import '../services/concert_service.dart';

class HomeView extends StatefulWidget {
  final Function(Track) onPlayTrack;
  final AudioTarget? currentTarget;
  final PiAampsService? piService;
  final AudioPlayerService? audioService;

  const HomeView({
    super.key,
    required this.onPlayTrack,
    this.currentTarget,
    this.piService,
    this.audioService,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  String _selectedCategory = 'Feel good';
  bool _isLoadingCategory = false;
  bool _showAllQuickPicks = false;

  final List<String> _categories = [
    'Feel good',
    'Sad',
    'Energize',
    'Relax',
    'Romance',
    'Focus',
    'Pop',
    'Rock',
    'Hip Hop',
  ];

  final List<Map<String, String>> _artists = [
    {
      'name': 'Coldplay',
      'url': 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=200',
    },
    {
      'name': 'The Weeknd',
      'url': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=200',
    },
    {
      'name': 'Dua Lipa',
      'url': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200',
    },
    {
      'name': 'Harry Styles',
      'url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
    },
    {
      'name': 'Taylor Swift',
      'url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
    },
    {
      'name': 'Queen',
      'url': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=200',
    },
  ];

  final Map<String, List<Track>> _categoryCache = {};

  final Map<String, List<Track>> _seedCategories = {
    'Feel good': [
      Track(
        id: 'yKNxeF4KMsY',
        title: 'Yellow',
        artist: 'Coldplay',
        album: 'Parachutes',
        duration: const Duration(minutes: 4, seconds: 29),
        artworkUrl: 'https://i.ytimg.com/vi/yKNxeF4KMsY/hqdefault.jpg',
        streamUrl: '',
        codec: 'AAC 320kbps',
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
      ),
      Track(
        id: 'TUVcZfQe-Kw',
        title: 'Levitating',
        artist: 'Dua Lipa',
        album: 'Future Nostalgia',
        duration: const Duration(minutes: 3, seconds: 23),
        artworkUrl: 'https://i.ytimg.com/vi/TUVcZfQe-Kw/hqdefault.jpg',
        streamUrl: '',
        codec: 'OPUS 160kbps',
      ),
      Track(
        id: '4NRXx6U8ABQ',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        duration: const Duration(minutes: 3, seconds: 20),
        artworkUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
        streamUrl: '',
        codec: 'OPUS 160kbps',
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
      ),
    ],
    'Sad': [
      Track(
        id: 'rYEDA3JcQqw',
        title: 'Rolling in the Deep',
        artist: 'Adele',
        album: '21',
        duration: const Duration(minutes: 3, seconds: 48),
        artworkUrl: 'https://i.ytimg.com/vi/rYEDA3JcQqw/hqdefault.jpg',
        streamUrl: '',
        codec: 'FLAC 24-bit',
      ),
      Track(
        id: 'bCuhuePlP8o',
        title: 'Someone You Loved',
        artist: 'Lewis Capaldi',
        album: 'Divinely Uninspired',
        duration: const Duration(minutes: 3, seconds: 2),
        artworkUrl: 'https://i.ytimg.com/vi/bCuhuePlP8o/hqdefault.jpg',
        streamUrl: '',
        codec: 'AAC 320kbps',
      ),
      Track(
        id: 'HUHC9tYz8ik',
        title: 'When the Party\'s Over',
        artist: 'Billie Eilish',
        album: 'WHEN WE ALL FALL ASLEEP',
        duration: const Duration(minutes: 3, seconds: 16),
        artworkUrl: 'https://i.ytimg.com/vi/HUHC9tYz8ik/hqdefault.jpg',
        streamUrl: '',
        codec: 'OPUS 160kbps',
      ),
      Track(
        id: 'RBumgq5yVrA',
        title: 'Let Her Go',
        artist: 'Passenger',
        album: 'All the Little Lights',
        duration: const Duration(minutes: 4, seconds: 12),
        artworkUrl: 'https://i.ytimg.com/vi/RBumgq5yVrA/hqdefault.jpg',
        streamUrl: '',
        codec: 'AAC 320kbps',
      ),
    ],
    'Energize': [
      Track(
        id: '34Na4j8AVgA',
        title: 'Starboy',
        artist: 'The Weeknd ft. Daft Punk',
        album: 'Starboy (Deluxe)',
        duration: const Duration(minutes: 3, seconds: 50),
        artworkUrl: 'https://i.ytimg.com/vi/34Na4j8AVgA/hqdefault.jpg',
        streamUrl: '',
        codec: 'FLAC 24-bit',
      ),
      Track(
        id: '_ovdm2yX4MA',
        title: 'Wake Me Up',
        artist: 'Avicii',
        album: 'True',
        duration: const Duration(minutes: 4, seconds: 9),
        artworkUrl: 'https://i.ytimg.com/vi/_ovdm2yX4MA/hqdefault.jpg',
        streamUrl: '',
        codec: 'AAC 320kbps',
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
      ),
    ],
    'Relax': [
      Track(
        id: 'jfKfPfyJRdk',
        title: 'Lofi Hip Hop Beats - Chill Session',
        artist: 'Lofi Girl',
        album: 'Chilled Beats 2026',
        duration: const Duration(minutes: 3, seconds: 45),
        artworkUrl: 'https://i.ytimg.com/vi/jfKfPfyJRdk/hqdefault.jpg',
        streamUrl: '',
        codec: 'AAC 320kbps',
      ),
      Track(
        id: '5yx6BWlEVcY',
        title: 'Stay With Me',
        artist: 'Miki Matsubara',
        album: 'Pocket Park',
        duration: const Duration(minutes: 4, seconds: 59),
        artworkUrl: 'https://i.ytimg.com/vi/5yx6BWlEVcY/hqdefault.jpg',
        streamUrl: '',
        codec: 'AAC 320kbps',
      ),
    ],
    'Romance': [
      Track(
        id: 'lp-EO5I60KA',
        title: 'Thinking Out Loud',
        artist: 'Ed Sheeran',
        album: 'x (Deluxe)',
        duration: const Duration(minutes: 4, seconds: 41),
        artworkUrl: 'https://i.ytimg.com/vi/lp-EO5I60KA/hqdefault.jpg',
        streamUrl: '',
        codec: 'AAC 320kbps',
      ),
      Track(
        id: 'JGwWNGJdvx8',
        title: 'Shape of You',
        artist: 'Ed Sheeran',
        album: '÷ (Divide)',
        duration: const Duration(minutes: 3, seconds: 53),
        artworkUrl: 'https://i.ytimg.com/vi/JGwWNGJdvx8/hqdefault.jpg',
        streamUrl: '',
        codec: 'AAC 320kbps',
      ),
    ],
    'Focus': [
      Track(
        id: 'pUZa33hSYWg',
        title: 'Experience',
        artist: 'Ludovico Einaudi',
        album: 'In a Time Lapse',
        duration: const Duration(minutes: 5, seconds: 15),
        artworkUrl: 'https://i.ytimg.com/vi/pUZa33hSYWg/hqdefault.jpg',
        streamUrl: '',
        codec: 'FLAC 24-bit',
      ),
      Track(
        id: '1d4C1ZQKfq4',
        title: 'Interstellar Main Theme',
        artist: 'Hans Zimmer',
        album: 'Interstellar OST',
        duration: const Duration(minutes: 4, seconds: 5),
        artworkUrl: 'https://i.ytimg.com/vi/1d4C1ZQKfq4/hqdefault.jpg',
        streamUrl: '',
        codec: 'FLAC 24-bit',
      ),
    ],
    'Pop': [
      Track(
        id: 'b1kbLwvqugk',
        title: 'Anti-Hero',
        artist: 'Taylor Swift',
        album: 'Midnights',
        duration: const Duration(minutes: 3, seconds: 20),
        artworkUrl: 'https://i.ytimg.com/vi/b1kbLwvqugk/hqdefault.jpg',
        streamUrl: '',
        codec: 'AAC 320kbps',
      ),
    ],
    'Rock': [
      Track(
        id: 'hTWKbfoikeg',
        title: 'Smells Like Teen Spirit',
        artist: 'Nirvana',
        album: 'Nevermind',
        duration: const Duration(minutes: 5, seconds: 1),
        artworkUrl: 'https://i.ytimg.com/vi/hTWKbfoikeg/hqdefault.jpg',
        streamUrl: '',
        codec: 'FLAC 24-bit',
      ),
    ],
    'Hip Hop': [
      Track(
        id: 'tvTRZJ-4EyI',
        title: 'HUMBLE.',
        artist: 'Kendrick Lamar',
        album: 'DAMN.',
        duration: const Duration(minutes: 2, seconds: 57),
        artworkUrl: 'https://i.ytimg.com/vi/tvTRZJ-4EyI/hqdefault.jpg',
        streamUrl: '',
        codec: 'OPUS 160kbps',
      ),
    ],
  };

  List<Track> _quickPicks = [];

  @override
  void initState() {
    super.initState();
    AccountService.instance.addListener(_refresh);
    SettingsService.instance.addListener(_refresh);
    _quickPicks = List.from(_seedCategories['Feel good']!);
    _fetchCategoryFromYoutube('Feel good');
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AccountService.instance.removeListener(_refresh);
    SettingsService.instance.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _selectCategory(String cat) async {
    setState(() {
      _selectedCategory = cat;
      _quickPicks = List.from(_categoryCache[cat] ?? _seedCategories[cat] ?? _seedCategories['Feel good']!);
    });

    if (!_categoryCache.containsKey(cat)) {
      await _fetchCategoryFromYoutube(cat);
    }
  }

  Future<void> _fetchCategoryFromYoutube(String category) async {
    if (_isLoadingCategory) return;
    setState(() => _isLoadingCategory = true);

    try {
      final query = '$category top music hits playlist';
      final tracks = await YoutubeService().searchTracks(query);
      if (tracks.isNotEmpty && mounted) {
        setState(() {
          _categoryCache[category] = tracks;
          if (_selectedCategory == category) {
            _quickPicks = tracks;
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingCategory = false);
    }
  }

  Future<void> _playArtist(String artistName) async {
    AppAlert.show(context, 'Loading $artistName tracks...', icon: Icons.music_note_rounded);
    try {
      final tracks = await YoutubeService().searchTracks('$artistName greatest hits');
      if (tracks.isNotEmpty && mounted) {
        widget.onPlayTrack(tracks.first);
        return;
      }
    } catch (_) {}

    final match = _quickPicks.where((t) => t.artist.toLowerCase().contains(artistName.toLowerCase())).firstOrNull;
    if (match != null) {
      widget.onPlayTrack(match);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    final showAmbientWallpaper = settings.showWallpaperOnHome && settings.customWallpaperUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // Ambient Wallpaper Header Backdrop (Spotify Style)
          if (showAmbientWallpaper)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 260,
              child: ShaderMask(
                shaderCallback: (rect) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black87,
                      Colors.transparent,
                    ],
                    stops: [0.0, 1.0],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: Opacity(
                  opacity: 0.28,
                  child: Image.network(
                    settings.customWallpaperUrl,
                    fit: BoxFit.cover,
                    headers: const {
                      'User-Agent':
                          'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Mobile Safari/537.36',
                    },
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header with Monochrome Branding & Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF141414),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                              ),
                              child: Center(
                                child: Icon(Icons.graphic_eq_rounded, color: settings.accentColor, size: 20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Flexible(
                              child: Text(
                                'OpenAamps',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white70),
                            tooltip: 'Stats & AI Music DNA',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const StatsView()),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.speaker_group_outlined, color: Colors.white70),
                            tooltip: 'Audio Output & Streamer',
                            onPressed: () {
                              final audio = widget.audioService;
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                builder: (modalCtx) => OutputTargetModal(
                                  currentTarget: audio?.target ?? AudioTarget.phoneLocal,
                                  onSelectTarget: (target) => audio?.setAudioTarget(target),
                                  piService: PiAampsService.instance,
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                            tooltip: 'Settings & Profile',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => SettingsView(audioService: widget.audioService)),
                              );
                            },
                          ),
                          GestureDetector(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => AccountSwitcherModal(
                                  accountService: AccountService.instance,
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: const Color(0xFF222222),
                                backgroundImage: AccountService.instance.activeAccount.avatarUrl.isNotEmpty
                                    ? NetworkImage(AccountService.instance.activeAccount.avatarUrl)
                                    : null,
                                child: AccountService.instance.activeAccount.avatarUrl.isEmpty
                                    ? const Icon(Icons.person_rounded, size: 18, color: Colors.white)
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                ],
              ),
              const SizedBox(height: 14),



              // Category / Mood Filter Chips (Monochrome)
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = cat == _selectedCategory;
                    final accent = SettingsService.instance.accentColor;
                    return ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? (accent.computeLuminance() > 0.5 ? Colors.black : Colors.white) : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: accent,
                      backgroundColor: const Color(0xFF141414),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? accent : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      onSelected: (selected) => _selectCategory(cat),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // OpenAAMPS Live Concert Arena Hero Banner
              _buildConcertLiveArenaBanner(SettingsService.instance.accentColor),

              const SizedBox(height: 10),

              // Quick Picks Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Quick picks',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_quickPicks.length} tracks',
                          style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_isLoadingCategory) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _showAllQuickPicks = !_showAllQuickPicks);
                    },
                    child: Text(
                      _showAllQuickPicks ? 'Show less' : 'See all (${_quickPicks.length})',
                      style: const TextStyle(color: Color(0xFFA1A1AA)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _showAllQuickPicks ? _quickPicks.length : (_quickPicks.length > 5 ? 5 : _quickPicks.length),
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final track = _quickPicks[index];
                  return Material(
                    color: const Color(0xFF141414),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      onTap: () => widget.onPlayTrack(track),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          track.artworkUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 48,
                            height: 48,
                            color: const Color(0xFF222222),
                            child: const Icon(Icons.music_note_rounded, color: Colors.white70),
                          ),
                        ),
                      ),
                      title: Text(
                        track.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        track.artist,
                        style: const TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                            tooltip: 'Play',
                            onPressed: () => widget.onPlayTrack(track),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
                            tooltip: 'Options',
                            onPressed: () => _showTrackOptions(context, track),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),

              // Keep Listening (Circular Artist Avatars)
              const Text(
                'Keep listening',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _artists.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final artist = _artists[index];
                    return GestureDetector(
                      onTap: () => _playArtist(artist['name']!),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: NetworkImage(artist['url']!),
                                fit: BoxFit.cover,
                              ),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            artist['name']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ],
  ),
);
  }

  void _showTrackOptions(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      track.artworkUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.music_note_rounded, color: Colors.white),
                    ),
                  ),
                  title: Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('${track.artist} • ${track.album}', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                ),
                const Divider(color: Colors.white12),
                ListTile(
                  leading: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                  title: const Text('Play Track', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onPlayTrack(track);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: Color(0xFFA1A1AA)),
                  title: const Text('Download Offline', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    DownloadService.instance.downloadTrack(track, YoutubeService());
                    AppAlert.show(
                      context,
                      'Downloading "${track.title}" offline...',
                      icon: Icons.download_rounded,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConcertLiveArenaBanner(Color accent) {
    return ListenableBuilder(
      listenable: ConcertService.instance,
      builder: (context, _) {
        final concert = ConcertService.instance.currentConcert;
        final audience = ConcertService.instance.liveAudienceCount;
        final venue = ConcertService.instance.currentVenue;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ConcertView(
                  audioService: widget.audioService ?? AudioPlayerService.instance,
                ),
              ),
            );
          },
          child: Container(
            height: 145,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: venue.primaryColor.withValues(alpha: 0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: venue.primaryColor.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    concert.bannerUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF1B1429)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.94),
                          Colors.black.withValues(alpha: 0.70),
                          venue.primaryColor.withValues(alpha: 0.35),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF4757),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0xFFFF4757),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.fiber_manual_record_rounded, size: 7, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          'LIVE ARENA',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '$audience FANS LIVE',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                concert.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${concert.artist} • ${venue.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: venue.secondaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: venue.primaryColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: venue.primaryColor.withValues(alpha: 0.5),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ENTER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

}
