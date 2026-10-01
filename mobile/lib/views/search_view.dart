import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/youtube_service.dart';
import '../services/integration_service.dart';
import '../services/download_service.dart';
import 'music_recognition_view.dart';
import '../services/settings_service.dart';
import '../widgets/app_alert.dart';

class SearchView extends StatefulWidget {
  final Function(Track) onPlayTrack;

  const SearchView({super.key, required this.onPlayTrack});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final YoutubeService _ytService = YoutubeService();
  late TabController _tabController;
  List<Track> _searchResults = [];
  bool _isLoading = false;

  final List<Track> _uniqueSongs = [
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
      id: 'G7KNmW9a75Y',
      title: 'Flowers',
      artist: 'Miley Cyrus',
      album: 'Endless Summer Vacation',
      duration: const Duration(minutes: 3, seconds: 20),
      artworkUrl: 'https://i.ytimg.com/vi/G7KNmW9a75Y/hqdefault.jpg',
      streamUrl: '',
      codec: 'FLAC 24-bit',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final results = await _ytService.searchTracks(query);

    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _ytService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _searchResults.isNotEmpty ? _searchResults : _uniqueSongs;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input Bar (Monochrome Pill)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _performSearch(),
                  onChanged: (val) {
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: 'Search YouTube Music or local tracks',
                    hintStyle: const TextStyle(color: Color(0xFF71717A)),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 20),
                            tooltip: 'Clear',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = [];
                              });
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.graphic_eq_rounded, color: Colors.white),
                          tooltip: 'Identify Song (Shazam)',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MusicRecognitionView(
                                  integrationService: IntegrationService.instance,
                                  onPlayTrack: widget.onPlayTrack,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.search_rounded, color: Colors.white),
                          tooltip: 'Search',
                          onPressed: _performSearch,
                        ),
                      ],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Explore / Suggestions Tab Bar (Dynamic Accent)
              Builder(
                builder: (context) {
                  final accent = SettingsService.instance.accentColor;
                  return TabBar(
                    controller: _tabController,
                    indicatorColor: accent,
                    labelColor: accent == Colors.white ? Colors.white : accent,
                    unselectedLabelColor: const Color(0xFF71717A),
                    indicatorWeight: 2.5,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.explore_outlined, size: 20),
                        text: 'Explore',
                      ),
                      Tab(
                        icon: Icon(Icons.recommend_outlined, size: 20),
                        text: 'Suggestions',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Section Title: Unique Songs
              const Text(
                'Unique Songs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: displayList.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final track = displayList[index];
                      final trackNumber = index + 1;

                      return Material(
                        color: const Color(0xFF141414),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          onTap: () {
                            widget.onPlayTrack(track);
                            AppAlert.show(
                              context,
                              'Playing "${track.title}"',
                              icon: Icons.play_arrow_rounded,
                            );
                          },
                          leading: SizedBox(
                            width: 24,
                            child: Text(
                              '$trackNumber',
                              style: const TextStyle(
                                color: Color(0xFF71717A),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          title: Text(
                            track.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            track.artist,
                            style: const TextStyle(
                              color: Color(0xFFA1A1AA),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 32),
                                tooltip: 'Play',
                                onPressed: () => widget.onPlayTrack(track),
                              ),
                              IconButton(
                                icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
                                tooltip: 'Options',
                                onPressed: () => _showTrackModal(context, track),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrackModal(BuildContext context, Track track) {
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
                  subtitle: Text(track.artist, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                ),
                const Divider(color: Colors.white12),
                ListTile(
                  leading: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                  title: const Text('Play Now', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onPlayTrack(track);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: Color(0xFFA1A1AA)),
                  title: const Text('Download for Offline', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    DownloadService.instance.downloadTrack(track, _ytService);
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
}
