import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/pi_aamps_service.dart';
import '../services/download_service.dart';
import '../services/youtube_service.dart';
import '../services/settings_service.dart';
import 'lyrics_view.dart';
import 'settings_view.dart';
import '../widgets/app_alert.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/output_target_modal.dart';
import '../services/party_service.dart';
import '../services/ai_music_service.dart';
import 'party_view.dart';
import 'ai/why_recommended_modal.dart';
import '../widgets/song_ai_studio_sheet.dart';

class PlayerView extends StatefulWidget {
  final Track track;
  final AudioPlayerService audioService;
  final PlayerStyle playerStyle;
  final AudioTarget? currentTarget;
  final PiAampsService? piService;
  final VoidCallback? onToggleTarget;

  const PlayerView({
    super.key,
    required this.track,
    required this.audioService,
    this.playerStyle = PlayerStyle.modern,
    this.currentTarget,
    this.piService,
    this.onToggleTarget,
  });

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> with SingleTickerProviderStateMixin {
  bool _isPlaying = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 80.0;
  bool _isLiked = false;
  bool _isDragging = false;
  double _dragValue = 0.0;
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;

  late AnimationController _vinylController;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.audioService.player.playing;
    _isLiked = widget.audioService.isLiked(widget.track.id);

    _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    if (_isPlaying) {
      _vinylController.repeat();
    }

    _position = widget.audioService.player.position;
    _duration = widget.audioService.player.duration ?? widget.track.duration;

    _positionSub = widget.audioService.positionStream.listen((pos) {
      if (mounted && !_isDragging) {
        setState(() {
          _position = pos;
        });
      }
    });

    _durationSub = widget.audioService.durationStream.listen((dur) {
      if (mounted && dur != null && dur > Duration.zero) {
        setState(() {
          _duration = dur;
        });
      }
    });

    _stateSub = widget.audioService.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
        if (state.playing) {
          if (!_vinylController.isAnimating) _vinylController.repeat();
        } else {
          if (_vinylController.isAnimating) _vinylController.stop();
        }
      }
    });

    SettingsService.instance.addListener(_onSettingsChange);
    DownloadService.instance.addListener(_onSettingsChange);
    widget.audioService.addListener(_onSettingsChange);

    if (widget.audioService.player.audioSource == null || widget.audioService.currentTrack?.id != widget.track.id) {
      widget.audioService.playTrack(widget.track);
    }
  }

  void _onSettingsChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SettingsService.instance.removeListener(_onSettingsChange);
    DownloadService.instance.removeListener(_onSettingsChange);
    widget.audioService.removeListener(_onSettingsChange);
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _vinylController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.audioService.currentTrack ?? widget.track;
    final accent = SettingsService.instance.accentColor;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              'NOW PLAYING',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              track.album,
              style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) {
              final isDownloaded = DownloadService.instance.isDownloaded(track.id);
              final isDownloading = DownloadService.instance.isDownloading(track.id);
              if (isDownloading) {
                return const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                );
              }
              return IconButton(
                icon: Icon(
                  isDownloaded ? Icons.offline_pin_rounded : Icons.download_rounded,
                  color: isDownloaded ? Colors.white : Colors.white70,
                ),
                tooltip: isDownloaded ? 'Downloaded' : 'Download Offline',
                onPressed: () {
                  if (isDownloaded) {
                    AppAlert.show(
                      context,
                      'Song already downloaded for offline playback',
                      icon: Icons.offline_pin_rounded,
                      isFullScreen: true,
                    );
                  } else {
                    DownloadService.instance.downloadTrack(track, YoutubeService());
                    AppAlert.show(
                      context,
                      'Downloading "${track.title}" for offline playback...',
                      icon: Icons.download_rounded,
                      isFullScreen: true,
                    );
                  }
                },
              );
            },
          ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.speaker_group_rounded,
                  color: PartyService.instance.isInParty ? const Color(0xFF10B981) : Colors.white70,
                ),
                if (PartyService.instance.isInParty)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${PartyService.instance.members.length}',
                        style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: PartyService.instance.isInParty ? 'Music Party Active' : 'Start Music Party / Jam',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PartyView(audioService: widget.audioService)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            tooltip: 'Track Options',
            onPressed: () => _showTrackOptionsModal(context, track),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackgroundLayer(track)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                children: [
                  const Spacer(),

                  // Artwork View
                  _buildArtworkWidget(track),

                  const Spacer(),

                  // Track Info & Like Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track.artist,
                              style: const TextStyle(
                                color: Color(0xFFA1A1AA),
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.psychology_rounded,
                          color: Colors.purpleAccent,
                          size: 24,
                        ),
                        tooltip: 'AI Music Studio & Instruments',
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => SongAiStudioSheet(
                              track: track,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 22,
                        ),
                        tooltip: 'Why Recommended & Acoustic DNA',
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => WhyRecommendedModal(
                              track: track,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: _isLiked ? Colors.white : Colors.white60,
                          size: 26,
                        ),
                        onPressed: () {
                          widget.audioService.toggleLike(track);
                          setState(() {
                            _isLiked = widget.audioService.isLiked(track.id);
                          });
                          if (_isLiked) {
                            AiMusicService.instance.onTrackLiked(track);
                          }
                          AppAlert.show(
                            context,
                            _isLiked ? 'Added to Liked Songs' : 'Removed from Liked Songs',
                            icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            isFullScreen: true,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

              // Progress Bar Slider + Codec Pill (Pure White & Zinc)
              Builder(
                builder: (context) {
                  final fallbackSec = widget.track.duration.inSeconds > 0
                      ? widget.track.duration.inSeconds.toDouble()
                      : 230.0;
                  final maxSec = _duration.inSeconds > 0
                      ? _duration.inSeconds.toDouble()
                      : fallbackSec;
                  final currentSec = _isDragging
                      ? _dragValue.clamp(0.0, maxSec)
                      : _position.inSeconds.toDouble().clamp(0.0, maxSec);

                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3.5,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          activeTrackColor: accent,
                          inactiveTrackColor: const Color(0xFF27272A),
                          thumbColor: accent,
                        ),
                        child: Slider(
                          value: currentSec,
                          min: 0.0,
                          max: maxSec,
                          onChanged: (val) {
                            setState(() {
                              _isDragging = true;
                              _dragValue = val;
                            });
                          },
                          onChangeEnd: (val) {
                            setState(() {
                              _isDragging = false;
                              _position = Duration(seconds: val.toInt());
                            });
                            widget.audioService.seek(Duration(seconds: val.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_isDragging ? Duration(seconds: _dragValue.toInt()) : _position),
                              style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                            ),

                            // Audio Codec Format Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF141414),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    track.codec,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),

                            Text(
                              _formatDuration(_duration > Duration.zero ? _duration : Duration(seconds: maxSec.toInt())),
                              style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => _showOutputTargetModal(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.audioService.target == AudioTarget.piSpeaker
                                ? const Color(0xFF16A34A).withValues(alpha: 0.2)
                                : const Color(0xFF18181B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: widget.audioService.target == AudioTarget.piSpeaker
                                  ? const Color(0xFF22C55E)
                                  : Colors.white24,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.audioService.target == AudioTarget.piSpeaker
                                    ? Icons.radio_rounded
                                    : Icons.phone_android_rounded,
                                color: widget.audioService.target == AudioTarget.piSpeaker
                                    ? const Color(0xFF22C55E)
                                    : Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.audioService.target == AudioTarget.piSpeaker
                                    ? 'pi-aamps • ${widget.audioService.piService.ipAddress}:${widget.audioService.piService.port}'
                                    : 'This Phone Audio',
                                style: TextStyle(
                                  color: widget.audioService.target == AudioTarget.piSpeaker
                                      ? const Color(0xFF22C55E)
                                      : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down_rounded, color: Colors.white54, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Playback Controls (Shuffle, 10s Rewind, Prev, Play/Pause, Next, 15s Forward, Repeat)
              // Playback Controls (Shuffle, 10s Rewind, Prev, Play/Pause, Next, 15s Forward, Repeat)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.shuffle_rounded,
                          color: _isShuffle ? accent : Colors.white38,
                          size: 24,
                        ),
                        tooltip: _isShuffle ? 'Shuffle On' : 'Shuffle Off',
                        onPressed: () {
                          setState(() => _isShuffle = !_isShuffle);
                          widget.audioService.setShuffleModeEnabled(_isShuffle);
                          AppAlert.show(
                            context,
                            _isShuffle ? 'Shuffle enabled' : 'Shuffle disabled',
                            icon: Icons.shuffle_rounded,
                            isFullScreen: true,
                          );
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.replay_10_rounded, color: Colors.white70, size: 26),
                        tooltip: 'Rewind 10s',
                        onPressed: () => widget.audioService.seekBackward10(),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 34),
                        tooltip: 'Previous Track',
                        onPressed: () => widget.audioService.skipToPrevious(),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (_isPlaying) {
                            widget.audioService.pause();
                          } else {
                            if (widget.audioService.player.audioSource == null) {
                               widget.audioService.playTrack(track);
                            } else {
                              widget.audioService.resume(fallbackTrack: track);
                            }
                          }
                        },
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.35),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: (widget.audioService.isLoading && !_isPlaying && !widget.audioService.player.playing)
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Icon(
                                    (_isPlaying || widget.audioService.player.playing)
                                         ? Icons.pause_rounded
                                         : Icons.play_arrow_rounded,
                                    color: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                    size: 38,
                                  ),
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 34),
                        tooltip: 'Next Track',
                        onPressed: () => widget.audioService.skipToNext(),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.forward_10_rounded, color: Colors.white70, size: 26),
                        tooltip: 'Forward 15s',
                        onPressed: () => widget.audioService.seekForward15(),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          _loopMode == LoopMode.one
                              ? Icons.repeat_one_rounded
                              : Icons.repeat_rounded,
                          color: _loopMode != LoopMode.off ? accent : Colors.white38,
                          size: 26,
                        ),
                        tooltip: _loopMode == LoopMode.off
                            ? 'Repeat Off'
                            : (_loopMode == LoopMode.one ? 'Repeat Track' : 'Repeat All'),
                        onPressed: () {
                          setState(() {
                            if (_loopMode == LoopMode.off) {
                              _loopMode = LoopMode.all;
                            } else if (_loopMode == LoopMode.all) {
                              _loopMode = LoopMode.one;
                            } else {
                              _loopMode = LoopMode.off;
                            }
                          });
                          widget.audioService.setLoopMode(_loopMode);
                          AppAlert.show(
                            context,
                            _loopMode == LoopMode.one
                                ? 'Loop current track'
                                : (_loopMode == LoopMode.all ? 'Loop all tracks' : 'Loop disabled'),
                            icon: _loopMode == LoopMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            isFullScreen: true,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Volume Slider (Dynamic Accent)
              Row(
                children: [
                  const Icon(Icons.volume_mute_rounded, color: Color(0xFF71717A), size: 20),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        activeTrackColor: accent,
                        inactiveTrackColor: const Color(0xFF27272A),
                        thumbColor: accent,
                      ),
                      child: Slider(
                        value: _volume,
                        min: 0.0,
                        max: 100.0,
                        onChanged: (val) {
                          setState(() {
                            _volume = val;
                          });
                          widget.audioService.setVolume(val);
                        },
                      ),
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded, color: Color(0xFF71717A), size: 20),
                ],
              ),
              const SizedBox(height: 16),

              // Bottom Action Bar (Queue List, Lyrics, Output Target, Sleep Timer, Equalizer/DSP)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.format_list_bulleted_rounded, color: Color(0xFFA1A1AA), size: 22),
                    tooltip: 'Queue',
                    onPressed: () => _showQueueModal(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFA1A1AA), size: 22),
                    tooltip: 'Lyrics',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LyricsView(
                            track: track,
                            audioService: widget.audioService,
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      widget.audioService.target == AudioTarget.piSpeaker
                          ? Icons.radio_rounded
                          : Icons.speaker_group_rounded,
                      color: widget.audioService.target == AudioTarget.piSpeaker
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFA1A1AA),
                      size: 22,
                    ),
                    tooltip: 'Output Target (Phone / pi-aamps)',
                    onPressed: () => _showOutputTargetModal(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.bedtime_outlined, color: Color(0xFFA1A1AA), size: 22),
                    tooltip: 'Sleep Timer',
                    onPressed: () => _showSleepTimerModal(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.equalizer_rounded, color: Color(0xFFA1A1AA), size: 22),
                    tooltip: '15-Band Equalizer & AutoEq',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (context) => const EqualizerSheet(),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);
  }

  void _showOutputTargetModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => OutputTargetModal(
        currentTarget: widget.audioService.target,
        piService: widget.audioService.piService,
        onSelectTarget: (newTarget) {
          widget.audioService.setAudioTarget(newTarget);
          if (mounted) setState(() {});
          AppAlert.show(
            context,
            newTarget == AudioTarget.piSpeaker
                ? 'Streaming on pi-aamps (${widget.audioService.piService.ipAddress}:${widget.audioService.piService.port})'
                : 'Playing on This Phone',
            icon: newTarget == AudioTarget.piSpeaker ? Icons.radio_rounded : Icons.phone_android_rounded,
            isFullScreen: true,
          );
        },
      ),
    );
  }

  Widget _buildBackgroundLayer(Track track) {
    final bg = SettingsService.instance.backgroundStyle;
    switch (bg) {
      case BackgroundStyle.pureBlack:
        return const SizedBox.expand(
          child: ColoredBox(color: Color(0xFF000000)),
        );

      case BackgroundStyle.darkGradient:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E1E22), Color(0xFF0E0E10), Color(0xFF000000)],
            ),
          ),
        );

      case BackgroundStyle.albumArtBlur:
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(track.artworkUrl, fit: BoxFit.cover),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
              child: Container(color: Colors.black.withValues(alpha: 0.82)),
            ),
          ],
        );

      case BackgroundStyle.dynamicColor:
        return Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.2,
              colors: [Color(0xFF282830), Color(0xFF121214), Color(0xFF000000)],
            ),
          ),
        );

      case BackgroundStyle.deepNebula:
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?w=1080',
              fit: BoxFit.cover,
            ),
            Container(color: Colors.black.withValues(alpha: 0.78)),
          ],
        );

      case BackgroundStyle.cyberNoir:
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1080',
              fit: BoxFit.cover,
            ),
            Container(color: Colors.black.withValues(alpha: 0.80)),
          ],
        );

      case BackgroundStyle.velvetNight:
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=1080',
              fit: BoxFit.cover,
            ),
            Container(color: Colors.black.withValues(alpha: 0.82)),
          ],
        );

      case BackgroundStyle.customWallpaper:
        final customUrl = SettingsService.instance.customWallpaperUrl;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (customUrl.isNotEmpty)
              Image.network(
                customUrl,
                fit: BoxFit.cover,
                headers: const {
                  'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Mobile Safari/537.36',
                  'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
                },
                errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF000000)),
              )
            else
              const ColoredBox(color: Color(0xFF000000)),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.70),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildArtworkWidget(Track track) {
    final style = SettingsService.instance.playerStyle;
    final accent = SettingsService.instance.accentColor;

    switch (style) {
      case PlayerStyle.vinyl:
        // Authentic Vinyl Turntable with spinning vinyl disc emerging from sleeve
        return SizedBox(
          width: 320,
          height: 270,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Spinning Vinyl Record (Slides out from behind sleeve)
              Positioned(
                right: 8,
                child: RotationTransition(
                  turns: _vinylController,
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFF0F0F0F),
                          Color(0xFF1E1E1E),
                          Color(0xFF0D0D0D),
                          Color(0xFF222222),
                          Color(0xFF111111),
                        ],
                        stops: [0.0, 0.45, 0.65, 0.85, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.9),
                          blurRadius: 20,
                          offset: const Offset(4, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Concentric Vinyl Sound Grooves
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1.5),
                          ),
                        ),
                        Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
                          ),
                        ),
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
                          ),
                        ),
                        // Center Circular Record Label
                        ClipOval(
                          child: SizedBox(
                            width: 86,
                            height: 86,
                            child: Image.network(
                              track.artworkUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: accent,
                                child: const Icon(Icons.album_rounded, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        // Spindle Center Hole
                        Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Color(0xFF000000),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Vinyl Album Jacket Sleeve (Layered in front with depth)
              Positioned(
                left: 12,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.95),
                        blurRadius: 24,
                        offset: const Offset(-4, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.network(
                      track.artworkUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFF1E1E1E),
                        child: const Icon(Icons.music_note_rounded, color: Colors.white54, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case PlayerStyle.minimal:
        // Minimalist circular aesthetic with ambient animated sound waves
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.4), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  track.artworkUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFF121212),
                    child: const Icon(Icons.music_note_rounded, color: Colors.white54, size: 50),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Minimal Rhythm Bar Visualizer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(16, (i) {
                final barHeight = 8.0 + (i % 5) * 4.0;
                return Container(
                  width: 3.5,
                  height: _isPlaying ? barHeight : 4.0,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: i % 2 == 0 ? accent : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ],
        );

      case PlayerStyle.classic:
        // Retro CD Jewel Case with spine tray and glossy light reflection
        return Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            color: const Color(0xFF161618),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.9),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              // Ribbed CD Case Spine (Clear frosted plastic texture)
              Container(
                width: 18,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border(
                    right: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(8, (_) => Container(
                    width: 10,
                    height: 2,
                    color: Colors.white.withValues(alpha: 0.25),
                  )),
                ),
              ),
              // Square CD Booklet Artwork with Glossy Sheen
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      track.artworkUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFF222222),
                        child: const Icon(Icons.album_rounded, color: Colors.white54, size: 60),
                      ),
                    ),
                    // Diagonal CD Glass Reflection Highlight
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.25),
                            Colors.white.withValues(alpha: 0.05),
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.08),
                          ],
                          stops: const [0.0, 0.35, 0.65, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case PlayerStyle.glassmorphism:
        // Frosted Acrylic Floating Glass with ambient glow
        return Container(
          width: 290,
          height: 290,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: accent == Colors.white ? Colors.white38 : accent.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.25),
                blurRadius: 36,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              track.artworkUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: const Color(0xFF1E1E1E),
                child: const Icon(Icons.music_note_rounded, color: Colors.white54, size: 54),
              ),
            ),
          ),
        );

      case PlayerStyle.modern:
        // Modern Sleek Card with soft shadow and accent glow
        return Container(
          width: 290,
          height: 290,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.85),
                blurRadius: 32,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
              if (accent != Colors.white)
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 40,
                  spreadRadius: -4,
                  offset: const Offset(0, 14),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Image.network(
              track.artworkUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: const Color(0xFF1E1E1E),
                child: const Icon(Icons.music_note_rounded, color: Colors.white54, size: 54),
              ),
            ),
          ),
        );
    }
  }

  void _showQueueModal(BuildContext context) {
    final upcomingQueue = [
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
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Now Playing & Queue',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'NOW PLAYING',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(widget.track.artworkUrl, width: 44, height: 44, fit: BoxFit.cover),
                  ),
                  title: Text(widget.track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(widget.track.artist, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                  trailing: const Icon(Icons.volume_up_rounded, color: Colors.white),
                ),
                const Divider(color: Colors.white12),
                const Text(
                  'UP NEXT',
                  style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: upcomingQueue.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 6),
                    itemBuilder: (c, i) {
                      final qTrack = upcomingQueue[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(qTrack.artworkUrl, width: 40, height: 40, fit: BoxFit.cover),
                        ),
                        title: Text(qTrack.title, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        subtitle: Text(qTrack.artist, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                        trailing: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                        onTap: () {
                          Navigator.pop(ctx);
                          widget.audioService.playTrack(qTrack);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlayerView(
                                track: qTrack,
                                audioService: widget.audioService,
                                playerStyle: widget.playerStyle,
                              ),
                            ),
                          );
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

  void _showSleepTimerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          final options = [15, 30, 45, 60, 90];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bedtime_rounded, color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      const Text(
                        'Sleep Timer Setup',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Live Countdown Stream Display
                  ValueListenableBuilder<Duration?>(
                    valueListenable: widget.audioService.sleepTimerRemaining,
                    builder: (context, remaining, _) {
                      if (remaining != null && remaining > Duration.zero) {
                        final m = remaining.inMinutes;
                        final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white30, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Stopping in $m:$s',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  widget.audioService.cancelSleepTimer();
                                  setModalState(() {});
                                },
                                child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  const Text(
                    'QUICK PRESETS',
                    style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((mins) {
                      return ActionChip(
                        backgroundColor: const Color(0xFF222222),
                        label: Text('$mins min', style: const TextStyle(color: Colors.white)),
                        onPressed: () {
                          widget.audioService.setSleepTimer(Duration(minutes: mins));
                          AppAlert.show(
                            context,
                            'Sleep timer set for $mins minutes',
                            icon: Icons.bedtime_rounded,
                            isFullScreen: true,
                          );
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'CUSTOM TIME SETUP',
                    style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 8),
                  _CustomSleepTimerSlider(
                    onSetTimer: (duration) {
                      widget.audioService.setSleepTimer(duration);
                      AppAlert.show(
                        context,
                        'Sleep timer set for ${duration.inMinutes} minutes',
                        icon: Icons.bedtime_rounded,
                        isFullScreen: true,
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 10),

                  if (widget.audioService.isSleepTimerActive)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        icon: const Icon(Icons.timer_off_outlined, color: Colors.white70),
                        label: const Text('Turn Off Sleep Timer', style: TextStyle(color: Colors.white70)),
                        onPressed: () {
                          widget.audioService.cancelSleepTimer();
                          AppAlert.show(
                            context,
                            'Sleep timer disabled',
                            icon: Icons.timer_off_outlined,
                            isFullScreen: true,
                          );
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTrackOptionsModal(BuildContext context, Track track) {
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
                    child: Image.network(track.artworkUrl, width: 44, height: 44, fit: BoxFit.cover),
                  ),
                  title: Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('${track.artist} • ${track.album}', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                ),
                const Divider(color: Colors.white12),
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: Colors.white),
                  title: const Text('Download for Offline', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    DownloadService.instance.downloadTrack(track, YoutubeService());
                    AppAlert.show(
                      context,
                      'Downloading "${track.title}" offline...',
                      icon: Icons.download_rounded,
                      isFullScreen: true,
                    );
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add_rounded, color: Colors.white),
                  title: const Text('Add to Playlist', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    AppAlert.show(
                      context,
                      'Added "${track.title}" to Favorites',
                      icon: Icons.favorite_rounded,
                      isFullScreen: true,
                    );
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lyrics_outlined, color: Colors.white),
                  title: const Text('Live Synced Lyrics', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LyricsView(
                          track: track,
                          audioService: widget.audioService,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.wallpaper_rounded, color: Colors.white),
                  title: const Text('Player Wallpaper & Canvas', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    SettingsService.instance.backgroundStyle.name.toUpperCase(),
                    style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showWallpaperPickerModal(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.equalizer_rounded, color: Colors.white),
                  title: const Text('Audio Settings & DSP', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsView()),
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

  void _showWallpaperPickerModal(BuildContext context) {
    final customUrlCtrl = TextEditingController(text: SettingsService.instance.customWallpaperUrl);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Player Canvas & Wallpapers', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white70), onPressed: () => Navigator.pop(sheetCtx)),
                ],
              ),
              const SizedBox(height: 12),

              // Wallpaper options
              ...BackgroundStyle.values.map((bg) {
                final isSelected = SettingsService.instance.backgroundStyle == bg;
                String title = '';
                String desc = '';
                IconData icon = Icons.wallpaper_rounded;

                switch (bg) {
                  case BackgroundStyle.pureBlack:
                    title = 'Pure AMOLED Black';
                    desc = 'Battery-saving pure black canvas';
                    icon = Icons.brightness_1_rounded;
                    break;
                  case BackgroundStyle.albumArtBlur:
                    title = 'Album Art Glow Blur';
                    desc = 'Cinematic real-time blurred backdrop';
                    icon = Icons.blur_on_rounded;
                    break;
                  case BackgroundStyle.darkGradient:
                    title = 'Dark Zinc Gradient';
                    desc = 'Monochrome vertical gradient';
                    icon = Icons.gradient_rounded;
                    break;
                  case BackgroundStyle.dynamicColor:
                    title = 'Luminescent Radial';
                    desc = 'Adaptive atmospheric glow';
                    icon = Icons.radio_button_checked_rounded;
                    break;
                  case BackgroundStyle.deepNebula:
                    title = 'Deep Cosmic Nebula (Default)';
                    desc = 'AMOLED deep space starlight preset';
                    icon = Icons.auto_awesome_rounded;
                    break;
                  case BackgroundStyle.cyberNoir:
                    title = 'Cyber Noir Studio (Default)';
                    desc = 'Sleek dark studio ambience preset';
                    icon = Icons.nightlife_rounded;
                    break;
                  case BackgroundStyle.velvetNight:
                    title = 'Velvet Aurora Midnight (Default)';
                    desc = 'Atmospheric dark aurora preset';
                    icon = Icons.landscape_rounded;
                    break;
                  case BackgroundStyle.customWallpaper:
                    title = 'Custom Wallpaper';
                    desc = 'Your custom image URL wallpaper';
                    icon = Icons.image_rounded;
                    break;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF222222) : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? Colors.white : Colors.white10),
                  ),
                  child: ListTile(
                    leading: Icon(icon, color: isSelected ? Colors.white : Colors.white54),
                    title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(desc, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                    trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Colors.white) : null,
                    onTap: () {
                      SettingsService.instance.setBackgroundStyle(bg);
                      setSheetState(() {});
                      setState(() {});
                      AppAlert.show(context, 'Set background to "$title"', icon: Icons.check_circle_rounded, isFullScreen: true);
                    },
                  ),
                );
              }),

              const SizedBox(height: 16),
              const Text('SET CUSTOM WALLPAPER URL', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: customUrlCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'https://images.unsplash.com/...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final url = customUrlCtrl.text.trim();
                      if (url.isNotEmpty) {
                        SettingsService.instance.setCustomWallpaperUrl(url);
                        setSheetState(() {});
                        setState(() {});
                        AppAlert.show(context, 'Applied custom player wallpaper', icon: Icons.check_circle_rounded, isFullScreen: true);
                      }
                    },
                    child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomSleepTimerSlider extends StatefulWidget {
  final Function(Duration) onSetTimer;

  const _CustomSleepTimerSlider({required this.onSetTimer});

  @override
  State<_CustomSleepTimerSlider> createState() => _CustomSleepTimerSliderState();
}

class _CustomSleepTimerSliderState extends State<_CustomSleepTimerSlider> {
  double _minutes = 20.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_minutes.toInt()} minutes',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => widget.onSetTimer(Duration(minutes: _minutes.toInt())),
              child: const Text('Start Timer', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        SliderTheme(
          data: const SliderThemeData(
            trackHeight: 3,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Color(0xFF27272A),
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: _minutes,
            min: 5,
            max: 120,
            divisions: 23,
            onChanged: (val) => setState(() => _minutes = val),
          ),
        ),
      ],
    );
  }
}
