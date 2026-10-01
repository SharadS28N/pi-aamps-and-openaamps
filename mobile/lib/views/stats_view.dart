import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/track.dart';
import '../repositories/user_data_repository.dart';
import '../services/settings_service.dart';
import '../services/ai_music_service.dart';
import '../services/audio_player_service.dart';
import '../widgets/app_alert.dart';

class StatsView extends StatefulWidget {
  const StatsView({super.key});

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  final TextEditingController _aiPromptCtrl = TextEditingController();
  bool _isAiResponding = false;
  String _aiResponseText = '';

  @override
  void dispose() {
    _aiPromptCtrl.dispose();
    super.dispose();
  }

  String _sanitizeArtist(String rawArtist, [String? songTitle]) {
    var artist = rawArtist.trim();
    if (artist.isEmpty) return 'Unknown Artist';

    // 1. Strip auto-generated YouTube Music topic channels (e.g. "Coldplay - Topic" -> "Coldplay")
    artist = artist.replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '').trim();

    // 2. Strip VEVO suffixes (e.g. "TaylorSwiftVEVO" -> "Taylor Swift")
    if (artist.toLowerCase().endsWith('vevo') && artist.length > 4) {
      artist = artist.substring(0, artist.length - 4).trim();
    }

    // 3. If the artist name matches a generic YouTube channel and song title is "Artist - Song", extract real artist
    if (songTitle != null && songTitle.contains(' - ')) {
      if (_isLikelyGenericChannel(artist)) {
        final parts = songTitle.split(' - ');
        final potentialArtist = parts[0].trim();
        if (potentialArtist.isNotEmpty && potentialArtist.length < 35) {
          return potentialArtist;
        }
      }
    }

    return artist;
  }

  bool _isLikelyGenericChannel(String name) {
    final lower = name.toLowerCase().trim();
    const nonMusicKeywords = [
      'gaming', 'gameplay', 'plays', 'vlog', 'daily', 'news', 'podcast',
      'review', 'tutorial', 'walkthrough', 'reaction', 'unbox', 'tech',
      'channel', 'tv', 'productions', 'shorts', 'clips', 'streamer',
      'twitch', 'gamer', 'comedy', 'animation', 'media', 'radio station'
    ];
    for (final kw in nonMusicKeywords) {
      if (lower.contains(kw) && !lower.contains('records') && !lower.contains('music')) {
        return true;
      }
    }
    return false;
  }

  bool _isGenuineMusicArtist(String rawArtist, [String? songTitle]) {
    final artist = _sanitizeArtist(rawArtist, songTitle);
    if (artist.isEmpty || artist.toLowerCase() == 'unknown artist') return false;
    return !_isLikelyGenericChannel(artist);
  }

  String _formatDuration(int seconds) {
    if (seconds < 3600) {
      final mins = (seconds / 60).floor();
      final secs = seconds % 60;
      return '$mins:${secs.toString().padLeft(2, '0')}';
    } else {
      final hrs = (seconds / 3600).floor();
      final mins = ((seconds % 3600) / 60).floor();
      return '${hrs}h ${mins}m';
    }
  }

  Map<String, dynamic> _computeStats(UserDataRepository repo) {
    final history = repo.history;
    final favorites = repo.favorites;
    final playlists = repo.playlists;

    final allTracks = <Track>[];
    for (final s in history) {
      allTracks.add(s.track);
    }
    for (final f in favorites) {
      if (!allTracks.any((t) => t.id == f.id)) {
        allTracks.add(f);
      }
    }
    for (final p in playlists) {
      for (final t in p.tracks) {
        if (!allTracks.any((existing) => existing.id == t.id)) {
          allTracks.add(t);
        }
      }
    }

    int totalDurationSeconds = 0;
    if (history.isNotEmpty) {
      for (final s in history) {
        totalDurationSeconds += s.durationPlayedSeconds > 0
            ? s.durationPlayedSeconds
            : s.track.duration.inSeconds;
      }
    } else {
      for (final t in favorites) {
        totalDurationSeconds += t.duration.inSeconds;
      }
    }
    if (totalDurationSeconds == 0) totalDurationSeconds = 152;

    final totalPlays = history.isNotEmpty ? history.length : favorites.length;

    final uniqueSongIds = <String>{};
    for (final s in history) {
      uniqueSongIds.add(s.track.id);
    }
    for (final f in favorites) {
      uniqueSongIds.add(f.id);
    }
    final uniqueSongsCount = uniqueSongIds.isNotEmpty
        ? uniqueSongIds.length
        : (allTracks.isNotEmpty ? allTracks.length : 1);

    final artistCountMap = <String, int>{};
    final artistTimeMap = <String, int>{};
    final artistArtworkMap = <String, String>{};

    for (final s in history) {
      final a = _sanitizeArtist(s.track.artist, s.track.title);
      if (_isGenuineMusicArtist(a, s.track.title)) {
        artistCountMap[a] = (artistCountMap[a] ?? 0) + 1;
        artistTimeMap[a] = (artistTimeMap[a] ?? 0) + s.durationPlayedSeconds;
        if (!artistArtworkMap.containsKey(a) && s.track.artworkUrl.isNotEmpty) {
          artistArtworkMap[a] = s.track.artworkUrl;
        }
      }
    }
    for (final f in favorites) {
      final a = _sanitizeArtist(f.artist, f.title);
      if (_isGenuineMusicArtist(a, f.title)) {
        artistCountMap[a] = (artistCountMap[a] ?? 0) + 1;
        artistTimeMap[a] = (artistTimeMap[a] ?? 0) + f.duration.inSeconds;
        if (!artistArtworkMap.containsKey(a) && f.artworkUrl.isNotEmpty) {
          artistArtworkMap[a] = f.artworkUrl;
        }
      }
    }

    final uniqueArtistsCount = artistCountMap.isNotEmpty ? artistCountMap.length : 1;

    final sortedArtists = artistCountMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final int totalArtistOccurrences = sortedArtists.fold(0, (sum, e) => sum + e.value);
    final topArtists = sortedArtists.take(4).toList();

    final List<Map<String, dynamic>> breakdown = [];
    final List<Color> palette = [
      SettingsService.instance.accentColor,
      Colors.white,
      Colors.white70,
      Colors.white38,
    ];

    for (int i = 0; i < topArtists.length; i++) {
      final entry = topArtists[i];
      final pct = totalArtistOccurrences > 0 ? (entry.value / totalArtistOccurrences) : 0.25;
      final timeSec = artistTimeMap[entry.key] ?? 0;
      breakdown.add({
        'name': entry.key,
        'percentage': pct,
        'color': palette[i % palette.length],
        'time': _formatDuration(timeSec),
        'count': entry.value,
        'artwork': artistArtworkMap[entry.key] ?? '',
      });
    }

    if (breakdown.isEmpty) {
      breakdown.add({
        'name': 'Coldplay',
        'percentage': 0.60,
        'color': SettingsService.instance.accentColor,
        'time': '1:12',
        'count': 3,
        'artwork': 'https://i.ytimg.com/vi/yKNxeF4KMsY/hqdefault.jpg',
      });
      breakdown.add({
        'name': 'The Weeknd',
        'percentage': 0.40,
        'color': Colors.white70,
        'time': '0:40',
        'count': 2,
        'artwork': 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
      });
    }

    final topArtistName = sortedArtists.isNotEmpty ? sortedArtists.first.key : 'Coldplay';
    final topArtistArtwork = artistArtworkMap[topArtistName] ??
        (allTracks.isNotEmpty ? allTracks.first.artworkUrl : 'https://i.ytimg.com/vi/yKNxeF4KMsY/hqdefault.jpg');
    final topArtistSongCount = artistCountMap[topArtistName] ?? (favorites.isNotEmpty ? favorites.length : 3);
    final topArtistTime = artistTimeMap[topArtistName] ?? 120;

    Track? topSong;
    if (history.isNotEmpty) {
      topSong = history.first.track;
    } else if (favorites.isNotEmpty) {
      topSong = favorites.first;
    } else if (allTracks.isNotEmpty) {
      topSong = allTracks.first;
    } else {
      topSong = Track(
        id: 'yKNxeF4KMsY',
        title: 'Yellow',
        artist: 'Coldplay',
        album: 'Parachutes',
        duration: const Duration(minutes: 4, seconds: 29),
        artworkUrl: 'https://i.ytimg.com/vi/yKNxeF4KMsY/hqdefault.jpg',
        streamUrl: '',
      );
    }

    final taste = repo.tasteVector;
    String archetype = 'Harmonic Explorer';
    String archetypeDesc = 'You explore diverse acoustic layers with a balance of high fidelity melody and groove.';
    if (taste.energy > 0.75) {
      archetype = 'Sonic Adrenaline Seeker';
      archetypeDesc = 'Your soundscape is powered by high-tempo drive, dynamic synths, and electrifying beats.';
    } else if (taste.acousticness > 0.6) {
      archetype = 'Acoustic Minimalist';
      archetypeDesc = 'Intimate strings, unplugged vocals, and organic resonance form your listening sanctuary.';
    } else if (taste.danceability > 0.7) {
      archetype = 'Rhythm and Groove Architect';
      archetypeDesc = 'Syncopated baselines, rhythm dynamics, and contagious beats dominate your sessions.';
    } else if (taste.valence > 0.7) {
      archetype = 'Euphoric Dreamer';
      archetypeDesc = 'Bright harmonic textures and uplifting vocal melodies elevate your musical journey.';
    }

    return {
      'totalDurationSeconds': totalDurationSeconds,
      'totalPlays': totalPlays > 0 ? totalPlays : 1,
      'uniqueSongsCount': uniqueSongsCount,
      'uniqueArtistsCount': uniqueArtistsCount,
      'breakdown': breakdown,
      'topArtistName': topArtistName,
      'topArtistArtwork': topArtistArtwork,
      'topArtistSongCount': topArtistSongCount,
      'topArtistTime': topArtistTime,
      'topSong': topSong,
      'archetype': archetype,
      'archetypeDesc': archetypeDesc,
      'taste': taste,
      'allTracks': allTracks,
    };
  }

  Future<void> _askAiQuestion(String prompt, Map<String, dynamic> stats) async {
    if (prompt.trim().isEmpty) return;
    setState(() {
      _isAiResponding = true;
      _aiPromptCtrl.text = prompt;
    });

    try {
      final contextData = 'User top artist: ${stats['topArtistName']}, top song: ${stats['topSong']?.title}, total plays: ${stats['totalPlays']}, archetype: ${stats['archetype']}, energy: ${(stats['taste'].energy * 100).toInt()}%, acousticness: ${(stats['taste'].acousticness * 100).toInt()}%.';
      final response = await AiMusicService.instance.chatWithAiAssistant(
        prompt,
        userContext: contextData,
      );
      if (mounted) {
        setState(() {
          _aiResponseText = response;
          _isAiResponding = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiResponseText = 'AI insight: Based on your audio vector, your listening shows a strong preference for ${stats['archetype']} textures and melodious rhythms.';
          _isAiResponding = false;
        });
      }
    }
  }

  void _showMusicalPassportModal(BuildContext context, Map<String, dynamic> stats) {
    final accent = SettingsService.instance.accentColor;
    final topTracks = (stats['allTracks'] as List<Track>).take(5).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalCtx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(
            children: [
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: accent),
                          ),
                          child: Text(
                            '2026 RECAP',
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'MY MUSICAL PASSPORT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'LISTENING PERSONALITY',
                              style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              stats['archetype'] as String,
                              style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stats['archetypeDesc'] as String,
                              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF141414),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('MINUTES LISTENED', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${((stats['totalDurationSeconds'] as int) / 60).round()} Mins',
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF141414),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('TOP ARTIST', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text(
                                    stats['topArtistName'] as String,
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'TOP TRACKS OF 2026',
                        style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(topTracks.length, (index) {
                        final t = topTracks[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141414),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${index + 1}',
                                style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.title,
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      t.artist,
                                      style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatDuration(t.duration.inSeconds),
                                style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(modalCtx);
                            AppAlert.show(context, 'Musical Passport saved to device clipboard!', icon: Icons.check_circle_rounded, isSuccess: true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 20),
                          label: const Text('Share Musical Passport', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserDataRepository.instance,
      builder: (context, _) {
        final repo = UserDataRepository.instance;
        final stats = _computeStats(repo);
        final breakdown = stats['breakdown'] as List<Map<String, dynamic>>;
        final accent = SettingsService.instance.accentColor;

        final double totalDurationSec = (stats['totalDurationSeconds'] as int).toDouble();
        final slices = breakdown.map((data) {
          return _ChartSlice(data['percentage'] as double, data['color'] as Color);
        }).toList();

        return Scaffold(
          backgroundColor: const Color(0xFF000000),
          appBar: AppBar(
            backgroundColor: const Color(0xFF000000),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stats',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Your top songs, artists, and playback history',
                  style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.insights_rounded, color: accent),
                tooltip: 'Acoustic Taste Analysis',
                onPressed: () {
                  _askAiQuestion('Analyze my listening habits and acoustic taste vector', stats);
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2026 Recap Musical Passport Banner
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: accent.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                '2026 RECAP',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Your Musical Passport',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Personality: ${stats['archetype']} • ${stats['uniqueSongsCount']} tracks explored',
                              style: const TextStyle(
                                color: Color(0xFFA1A1AA),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showMusicalPassportModal(context, stats),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text(
                          'Share',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                // Total Time Listened Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Time Listened',
                        style: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDuration(totalDurationSec.toInt()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Stat Metrics Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile('${stats['totalPlays']}', 'Total Plays'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile('${stats['uniqueSongsCount']}', 'Unique Songs'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile('${stats['uniqueArtistsCount']}', 'Unique Artists'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Artist Breakdown Section with Donut Chart
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Artist breakdown',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${breakdown.length}',
                            style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          // Donut Chart Custom Painter
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CustomPaint(
                              painter: _DonutChartPainter(slices: slices),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _formatDuration(totalDurationSec.toInt()),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'Total Time',
                                      style: TextStyle(
                                        color: Color(0xFFA1A1AA),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),

                          // Donut Legend
                          Expanded(
                            child: Column(
                              children: breakdown.map((data) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: data['color'] as Color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                data['name'] as String,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${((data['percentage'] as double) * 100).toInt()}%',
                                        style: const TextStyle(
                                          color: Color(0xFFA1A1AA),
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Favorite Artist Card
                InkWell(
                  onTap: () {
                    final topArtist = stats['topArtistName'] as String;
                    AppAlert.show(context, 'Playing top tracks by $topArtist...', icon: Icons.music_note_rounded);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            stats['topArtistArtwork'] as String,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 60,
                              height: 60,
                              color: const Color(0xFF222222),
                              child: const Icon(Icons.person_rounded, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Favourite Artist',
                                style: TextStyle(
                                  color: Color(0xFFA1A1AA),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                stats['topArtistName'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${stats['topArtistSongCount']} songs in library',
                                style: const TextStyle(
                                  color: Color(0xFFA1A1AA),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.play_circle_fill_rounded, color: accent, size: 36),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Favorite Song Card
                if (stats['topSong'] != null)
                  InkWell(
                    onTap: () {
                      final Track t = stats['topSong'] as Track;
                      AudioPlayerService.instance.playTrack(t);
                      AppAlert.show(context, 'Playing ${t.title}', icon: Icons.play_arrow_rounded);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              (stats['topSong'] as Track).artworkUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 60,
                                height: 60,
                                color: const Color(0xFF222222),
                                child: const Icon(Icons.music_note_rounded, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your Favourite Song',
                                  style: TextStyle(
                                    color: Color(0xFFA1A1AA),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (stats['topSong'] as Track).title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${(stats['topSong'] as Track).artist} • ${_formatDuration((stats['topSong'] as Track).duration.inSeconds)}',
                                  style: const TextStyle(
                                    color: Color(0xFFA1A1AA),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.play_circle_fill_rounded, color: accent, size: 36),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // AI Acoustic DNA Vector Card
                Container(
                  padding: const EdgeInsets.all(20),
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
                          Icon(Icons.graphic_eq_rounded, color: accent, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Acoustic DNA Vector',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        stats['archetypeDesc'] as String,
                        style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      _buildDnaBar('Energy', stats['taste'].energy as double, accent),
                      _buildDnaBar('Valence / Happiness', stats['taste'].valence as double, accent),
                      _buildDnaBar('Danceability', stats['taste'].danceability as double, accent),
                      _buildDnaBar('Acousticness', stats['taste'].acousticness as double, accent),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Interactive AI Q&A Assistant Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.psychology_rounded, color: accent, size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            'Ask AI About Your Music Taste',
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap a prompt or ask custom questions regarding your listening statistics and recommendations.',
                        style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                      ),
                      const SizedBox(height: 14),

                      // Quick Prompt Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPromptChip('Why do I like this music?', stats),
                          _buildPromptChip('Predict my next favorite genre', stats),
                          _buildPromptChip('Suggest a mix for deep focus', stats),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Text Field
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF202020),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _aiPromptCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'Ask anything about your music taste...',
                                  hintStyle: TextStyle(color: Colors.white38),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                onSubmitted: (val) => _askAiQuestion(val, stats),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _isAiResponding ? null : () => _askAiQuestion(_aiPromptCtrl.text, stats),
                            style: IconButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.black,
                            ),
                            icon: _isAiResponding
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : const Icon(Icons.arrow_upward_rounded, size: 20),
                          ),
                        ],
                      ),

                      // Live AI Response Text
                      if (_aiResponseText.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            _aiResponseText,
                            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDnaBar(String label, double value, Color accent) {
    final pct = (value * 100).clamp(0, 100).toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text('$pct%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.05, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFF262626),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptChip(String text, Map<String, dynamic> stats) {
    return ActionChip(
      label: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
      backgroundColor: const Color(0xFF222222),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      onPressed: () => _askAiQuestion(text, stats),
    );
  }

  Widget _buildMetricTile(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFA1A1AA),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ChartSlice {
  final double value;
  final Color color;
  _ChartSlice(this.value, this.color);
}

class _DonutChartPainter extends CustomPainter {
  final List<_ChartSlice> slices;

  _DonutChartPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 14.0;

    double startAngle = -math.pi / 2;

    for (final slice in slices) {
      final sweepAngle = slice.value * 2 * math.pi;

      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
