import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/settings_service.dart';

class NowPlayingBar extends StatelessWidget {
  final Track track;
  final AudioPlayerService audioService;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final bool isPlaying;
  final AudioTarget? currentTarget;

  const NowPlayingBar({
    super.key,
    required this.track,
    required this.audioService,
    required this.onTap,
    required this.onPlayPause,
    required this.isPlaying,
    this.currentTarget,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        final accent = SettingsService.instance.accentColor;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        // Circular Avatar with Glowing Ring (Reference Image 1)
                        Container(
                          width: 44,
                          height: 44,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                accent,
                                const Color(0xFFEC4899),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.35),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.network(
                              track.artworkUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFF222222),
                                child: const Icon(Icons.music_note_rounded, color: Colors.white70, size: 20),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                track.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.artist,
                                style: const TextStyle(
                                  color: Color(0xFFA1A1AA),
                                  fontSize: 11.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Duration Timestamp (Reference Image 1 e.g. "2:47")
                        StreamBuilder<Duration>(
                          stream: audioService.positionStream,
                          builder: (context, snapshot) {
                            final pos = snapshot.data ?? audioService.currentPosition;
                            final m = pos.inMinutes;
                            final s = (pos.inSeconds % 60).toString().padLeft(2, '0');
                            return Text(
                              '$m:$s',
                              style: const TextStyle(
                                color: Color(0xFFA1A1AA),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        // Next Track Button
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 24),
                          onPressed: () => audioService.skipToNext(),
                        ),
                        IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                            color: accent,
                            size: 34,
                          ),
                          onPressed: onPlayPause,
                        ),
                      ],
                    ),
                  ),

                  // Active Real-time Moving Progress Bar (Dynamic Accent)
                  StreamBuilder<Duration>(
                    stream: audioService.positionStream,
                    builder: (context, snapshot) {
                      final pos = snapshot.data ?? audioService.currentPosition;
                      final dur = audioService.currentDuration;
                      final maxSec = dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 230.0;
                      final ratio = (pos.inSeconds / maxSec).clamp(0.0, 1.0);

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                            height: 2.5,
                            width: constraints.maxWidth,
                            color: Colors.white.withValues(alpha: 0.08),
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: constraints.maxWidth * ratio,
                              height: 2.5,
                              color: accent,
                            ),
                          );
                        },
                      );
                    },
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
