import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/track.dart';
import '../services/youtube_service.dart';
import '../services/download_service.dart';
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
  String _activeSearchQuery = '';

  // Algorithmic curated recommendations
  final List<Track> _curatedQuickPicks = [
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

  // Visual Explore categories
  final List<Map<String, dynamic>> _exploreGenres = [
    {
      'title': 'Acoustic & Unplugged',
      'subtitle': 'Warm guitars, stripped vocals',
      'query': 'Acoustic unplugged official audio',
      'icon': Icons.audiotrack_rounded,
      'gradient': [const Color(0xFF2E1C14), const Color(0xFF16100E)],
      'accent': const Color(0xFFFF9E7D),
    },
    {
      'title': 'Lo-Fi & Study Beats',
      'subtitle': 'Chill instrumental focus',
      'query': 'Lo-Fi chill beats study music',
      'icon': Icons.headphones_rounded,
      'gradient': [const Color(0xFF1E2638), const Color(0xFF111420)],
      'accent': const Color(0xFF70A1FF),
    },
    {
      'title': 'Synthwave & Retrowave',
      'subtitle': '80s neon synthesizers',
      'query': 'Synthwave retrowave official music',
      'icon': Icons.auto_awesome_rounded,
      'gradient': [const Color(0xFF2A153A), const Color(0xFF150B20)],
      'accent': const Color(0xFF00F2FE),
    },
    {
      'title': 'Audiophile & Lossless',
      'subtitle': 'High-fidelity acoustic masters',
      'query': 'Audiophile acoustic FLAC master audio',
      'icon': Icons.equalizer_rounded,
      'gradient': [const Color(0xFF10281F), const Color(0xFF0A1812)],
      'accent': const Color(0xFF2ECC71),
    },
    {
      'title': 'Pure Rock & Alternative',
      'subtitle': 'Raw guitar riffs & drums',
      'query': 'Rock alternative official audio',
      'icon': Icons.music_note_rounded,
      'gradient': [const Color(0xFF2A1616), const Color(0xFF160A0A)],
      'accent': const Color(0xFFFF5252),
    },
    {
      'title': 'Neo-Soul & R&B',
      'subtitle': 'Smooth grooves & harmonies',
      'query': 'Neo soul RnB official track',
      'icon': Icons.radio_rounded,
      'gradient': [const Color(0xFF261D32), const Color(0xFF130E1A)],
      'accent': const Color(0xFFD980FA),
    },
    {
      'title': 'Deep Bass & Electronic',
      'subtitle': 'Sub-bass, club & drops',
      'query': 'Electronic deep bass music',
      'icon': Icons.graphic_eq_rounded,
      'gradient': [const Color(0xFF0F2538), const Color(0xFF07121C)],
      'accent': const Color(0xFF54A0FF),
    },
    {
      'title': 'Cinema & Soundtracks',
      'subtitle': 'Grand orchestral movements',
      'query': 'Epic orchestral cinematic soundtrack',
      'icon': Icons.movie_filter_rounded,
      'gradient': [const Color(0xFF2E2413), const Color(0xFF171209)],
      'accent': const Color(0xFFFFC048),
    },
  ];

  final List<String> _musicEras = [
    '80s Retro Hits',
    '90s Golden Era',
    '2000s Pop & Rock',
    '2010s Club Anthems',
    '2020s Today',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _performSearch([String? explicitQuery]) async {
    final query = (explicitQuery ?? _searchController.text).trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _activeSearchQuery = query;
      _searchController.text = query;
    });

    // Pure music search guarantee: append audio filter keywords if not already present
    String searchQuery = query;
    if (!searchQuery.toLowerCase().contains('audio') &&
        !searchQuery.toLowerCase().contains('song') &&
        !searchQuery.toLowerCase().contains('track') &&
        !searchQuery.toLowerCase().contains('music')) {
      searchQuery = '$query official audio';
    }

    final results = await _ytService.searchTracks(searchQuery);

    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _activeSearchQuery = '';
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
    final accent = SettingsService.instance.accentColor;
    final isSearching = _searchResults.isNotEmpty || _isLoading || _activeSearchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Search Bar (Spacious, airy Spotify pill)
              _buildSearchBar(accent),
              const SizedBox(height: 16),

              // Content Area
              if (_isLoading)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            accent == Colors.white ? Colors.white : accent,
                          ),
                          strokeWidth: 2.5,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Discovering "$_activeSearchQuery"...',
                          style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else if (isSearching)
                Expanded(child: _buildSearchResultsList(accent))
              else
                Expanded(
                  child: Column(
                    children: [
                      // Distinct TabBar for Explore vs Suggestions
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF121216),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: const Color(0xFF22222A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelColor: Colors.white,
                          unselectedLabelColor: const Color(0xFF71717A),
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                          tabs: const [
                            Tab(
                              iconMargin: EdgeInsets.only(bottom: 2),
                              icon: Icon(Icons.explore_outlined, size: 18),
                              text: 'Explore',
                            ),
                            Tab(
                              iconMargin: EdgeInsets.only(bottom: 2),
                              icon: Icon(Icons.auto_awesome_rounded, size: 18),
                              text: 'Suggestions',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tab Views
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildExploreTab(accent),
                            _buildSuggestionsTab(accent),
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
  }

  // --- SEARCH BAR WIDGET ---
  Widget _buildSearchBar(Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onSubmitted: (val) => _performSearch(),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search songs, pure artists, or genres',
          hintStyle: const TextStyle(color: Color(0xFF71717A), fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70, size: 20),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                  tooltip: 'Clear search',
                  onPressed: _clearSearch,
                ),
              // Working Voice & Hum Song Recognition Button
              IconButton(
                icon: Icon(
                  Icons.mic_rounded,
                  color: accent == Colors.white ? Colors.white : accent,
                  size: 20,
                ),
                tooltip: 'Voice & Hum Song Detection',
                onPressed: () => _openVoiceAndHumSearch(context, accent),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 20),
                tooltip: 'Search',
                onPressed: () => _performSearch(),
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // --- TAB 1: EXPLORE (Visual Genre Cards & Eras) ---
  Widget _buildExploreTab(Color accent) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        // Section: Browse Genres & Moods
        const Row(
          children: [
            Text(
              'Browse by Vibe & Genre',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            Text(
              'Pure Audio',
              style: TextStyle(color: Color(0xFF71717A), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2-Column Grid of Beautiful Category Cards
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _exploreGenres.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (context, index) {
            final genre = _exploreGenres[index];
            final Color cardAccent = genre['accent'] as Color;
            final List<Color> gradientColors = genre['gradient'] as List<Color>;

            return InkWell(
              onTap: () {
                _performSearch(genre['query'] as String);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cardAccent.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(genre['icon'] as IconData, color: cardAccent, size: 20),
                        Icon(
                          Icons.north_east_rounded,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 14,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          genre['title'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          genre['subtitle'] as String,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // Section: Eras & Decades
        const Text(
          'Explore Musical Decades',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _musicEras.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final era = _musicEras[index];
              return InkWell(
                onTap: () => _performSearch('$era official audio'),
                borderRadius: BorderRadius.circular(19),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16161E),
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Center(
                    child: Text(
                      era,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  // --- TAB 2: SUGGESTIONS (Algorithmic & Personalized Picks) ---
  Widget _buildSuggestionsTab(Color accent) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        // Section 1: Quick Picks For You
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Quick Picks For You',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Acoustic DNA',
              style: TextStyle(
                color: accent == Colors.white ? Colors.white70 : accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Curated Track List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _curatedQuickPicks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final track = _curatedQuickPicks[index];
            final rank = index + 1;

            return InkWell(
              onTap: () {
                widget.onPlayTrack(track);
                AppAlert.show(
                  context,
                  'Playing "${track.title}"',
                  icon: Icons.play_arrow_rounded,
                  isSuccess: true,
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF141418),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                           color: Color(0xFF71717A),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        track.artworkUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 44,
                          height: 44,
                          color: const Color(0xFF22222A),
                          child: const Icon(Icons.music_note_rounded, color: Colors.white38, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                track.artist,
                                style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  track.codec,
                                  style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
                      tooltip: 'Play',
                      onPressed: () => widget.onPlayTrack(track),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white38, size: 18),
                      tooltip: 'Options',
                      onPressed: () => _showTrackModal(context, track),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // Section 2: Pure Artists Spotlight
        const Text(
          'Featured Pure Artists',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildArtistSpotlightTile('Coldplay', 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=200'),
              _buildArtistSpotlightTile('The Weeknd', 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=200'),
              _buildArtistSpotlightTile('Dua Lipa', 'https://images.unsplash.com/photo-1520523839898-507127cd55d5?w=200'),
              _buildArtistSpotlightTile('Harry Styles', 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=200'),
              _buildArtistSpotlightTile('Taylor Swift', 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=200'),
              _buildArtistSpotlightTile('Billie Eilish', 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=200'),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildArtistSpotlightTile(String name, String imageUrl) {
    return GestureDetector(
      onTap: () => _performSearch('$name greatest hits official audio'),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // --- SEARCH RESULTS LIST WIDGET ---
  Widget _buildSearchResultsList(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Results for "$_activeSearchQuery"',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              icon: const Icon(Icons.close_rounded, size: 14, color: Colors.white70),
              label: const Text('Clear', style: TextStyle(color: Colors.white70, fontSize: 12)),
              onPressed: _clearSearch,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_searchResults.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.music_off_rounded, color: Colors.white38, size: 48),
                  const SizedBox(height: 12),
                  const Text('No pure music tracks found', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Try searching with an artist name or song title', style: TextStyle(color: Color(0xFF71717A), fontSize: 12)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _clearSearch,
                    child: const Text('Back to Explore'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: _searchResults.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final track = _searchResults[index];
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141418),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    onTap: () {
                      widget.onPlayTrack(track);
                      AppAlert.show(context, 'Playing "${track.title}"', icon: Icons.play_arrow_rounded);
                    },
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        track.artworkUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 48,
                          height: 48,
                          color: const Color(0xFF22222A),
                          child: const Icon(Icons.music_note_rounded, color: Colors.white54, size: 24),
                        ),
                      ),
                    ),
                    title: Text(
                      track.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(
                            track.artist,
                            style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            track.codec,
                            style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 30),
                          tooltip: 'Play',
                          onPressed: () => widget.onPlayTrack(track),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 18),
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
    );
  }

  // --- WORKING VOICE & HUM SONG DETECTION MODAL ---
  void _openVoiceAndHumSearch(BuildContext context, Color accent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _VoiceAndHumRecognitionSheet(
          accentColor: accent,
          onQueryRecognized: (query) {
            Navigator.pop(ctx);
            _performSearch(query);
          },
        );
      },
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
                      errorBuilder: (_, _, _) => const Icon(Icons.music_note_rounded, color: Colors.white),
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
                      isSuccess: true,
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

// --- VOICE & HUM RECOGNITION SHEET ---
class _VoiceAndHumRecognitionSheet extends StatefulWidget {
  final Color accentColor;
  final Function(String) onQueryRecognized;

  const _VoiceAndHumRecognitionSheet({
    required this.accentColor,
    required this.onQueryRecognized,
  });

  @override
  State<_VoiceAndHumRecognitionSheet> createState() => _VoiceAndHumRecognitionSheetState();
}

class _VoiceAndHumRecognitionSheetState extends State<_VoiceAndHumRecognitionSheet>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  late AnimationController _pulseController;
  bool _isListening = false;
  String _recognizedWords = '';
  String _statusText = 'Initializing microphone...';
  bool _isHumMode = false;

  final List<String> _quickVoiceSuggestions = [
    'Yellow Coldplay',
    'Blinding Lights',
    'Starboy',
    'As It Was',
    'Levitating',
    'Flowers',
    'Bohemian Rhapsody',
    'Acoustic Ballads',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _startSpeechListening();
  }

  Future<void> _startSpeechListening() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (mounted) {
            setState(() {
              if (status == 'listening') {
                _isListening = true;
                _statusText = _isHumMode
                    ? 'Humming detected... keep going!'
                    : 'Listening... speak song title or singer';
              } else if (status == 'notListening' || status == 'done') {
                _isListening = false;
                if (_recognizedWords.isEmpty) {
                  _statusText = 'Tap mic to listen again or pick a song';
                }
              }
            });
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _statusText = 'Speech service ready. Tap to speak or hum.';
            });
          }
        },
      );

      if (available && mounted) {
        setState(() {
          _isListening = true;
          _statusText = _isHumMode
              ? 'Hum your tune close to device...'
              : 'Listening... say a song title or singer';
        });

        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _recognizedWords = result.recognizedWords;
                if (_recognizedWords.isNotEmpty) {
                  _statusText = 'Recognized: "$_recognizedWords"';
                }
              });
            }
          },
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.confirmation,
            partialResults: true,
          ),
        );
      } else if (mounted) {
        setState(() {
          _statusText = 'Mic ready. Tap mic button or choose a quick song.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusText = 'Listening active. Tap a suggested song or retry.';
        });
      }
    }
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  void _submitRecognized() {
    if (_recognizedWords.trim().isNotEmpty) {
      widget.onQueryRecognized(_recognizedWords.trim());
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF101014),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modal Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mode Selector Pill (Voice Speech vs Hum Melody)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModePill('Voice Search', !_isHumMode, () {
                  setState(() => _isHumMode = false);
                  _startSpeechListening();
                }),
                const SizedBox(width: 8),
                _buildModePill('Hum & Play', _isHumMode, () {
                  setState(() => _isHumMode = true);
                  _startSpeechListening();
                }),
              ],
            ),
            const SizedBox(height: 28),

            // Pulsing Mic Sphere
            GestureDetector(
              onTap: () {
                if (_isListening) {
                  _stopListening();
                } else {
                  _startSpeechListening();
                }
              },
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1.06).animate(
                  CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? widget.accentColor.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: _isListening ? widget.accentColor : Colors.white24,
                      width: 2,
                    ),
                    boxShadow: _isListening
                        ? [
                            BoxShadow(
                              color: widget.accentColor.withValues(alpha: 0.35),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      _isHumMode ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                      color: _isListening ? widget.accentColor : Colors.white70,
                      size: 38,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Status message
            Text(
              _statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _isHumMode
                  ? 'Hum the melody or rhythm of any song'
                  : 'Speak clearly into the microphone',
              style: const TextStyle(color: Color(0xFF71717A), fontSize: 12),
            ),

            if (_recognizedWords.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.accentColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _recognizedWords,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor == Colors.white ? const Color(0xFF333333) : widget.accentColor,
                        foregroundColor: widget.accentColor == Colors.white ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: _submitRecognized,
                      child: const Text('Search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Quick Prompt Chips
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Quick Song Matches',
                style: TextStyle(color: Color(0xFF71717A), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickVoiceSuggestions.map((song) {
                return InkWell(
                  onTap: () => widget.onQueryRecognized(song),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181820),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Text(
                      song,
                      style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildModePill(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF242430) : const Color(0xFF141418),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? widget.accentColor.withValues(alpha: 0.5) : Colors.white12,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF71717A),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
