import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/ai_music_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/song_ai_studio_sheet.dart';

class AiStudioView extends StatefulWidget {
  final AudioPlayerService audioService;
  final Function(Track)? onPlayTrack;

  const AiStudioView({
    super.key,
    required this.audioService,
    this.onPlayTrack,
  });

  @override
  State<AiStudioView> createState() => _AiStudioViewState();
}

class _AiStudioViewState extends State<AiStudioView> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Track> _catalog = [];
  List<Track> _filtered = [];

  @override
  void initState() {
    super.initState();
    _catalog = AiMusicService.instance.catalogTracks;
    _filtered = _catalog;
  }

  void _filterTracks(String query) {
    final clean = query.trim().toLowerCase();
    setState(() {
      if (clean.isEmpty) {
        _filtered = _catalog;
      } else {
        _filtered = _catalog.where((t) {
          return t.title.toLowerCase().contains(clean) ||
              t.artist.toLowerCase().contains(clean) ||
              t.genre.toLowerCase().contains(clean);
        }).toList();
      }
    });
  }

  void _openStudioForTrack(Track track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SongAiStudioSheet(track: track),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = SettingsService.instance.accentColor;
    final activeTrack = widget.audioService.currentTrack;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.psychology_rounded, color: accent, size: 24),
            const SizedBox(width: 8),
            const Text(
              'AI Music Studio',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.25),
                  const Color(0xFF18181B).withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: accent, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Acoustic Intelligence & Instrument Lab',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Deconstruct song stems, detect instruments (guitars, 808s, Rhodes, synthesizers), inspect harmonic keys, lyrical themes, and ask AI questions powered by Google Gemini and Acoustic AI.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Now Playing Quick Studio Card
          if (activeTrack != null) ...[
            const Text(
              'NOW PLAYING IN STUDIO',
              style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _openStudioForTrack(activeTrack),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF16161E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        activeTrack.artworkUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 52,
                          height: 52,
                          color: const Color(0xFF22222E),
                          child: const Icon(Icons.music_note, color: Colors.white38),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeTrack.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${activeTrack.artist} • ${activeTrack.tempo.toInt()} BPM',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Analyze',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Search Catalog Tracks
          const Text(
            'ANALYZE CATALOG TRACKS',
            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF181820),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF282834)),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _filterTracks,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search title, artist, or genre to analyze...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // List of tracks
          ..._filtered.map((t) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF121218),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E1E28)),
              ),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    t.artworkUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 44,
                      height: 44,
                      color: const Color(0xFF22222E),
                      child: const Icon(Icons.music_note, color: Colors.white38),
                    ),
                  ),
                ),
                title: Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  '${t.artist} • ${t.genre}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: Icon(Icons.psychology_outlined, color: accent, size: 22),
                onTap: () => _openStudioForTrack(t),
              ),
            );
          }),
        ],
      ),
    );
  }
}
