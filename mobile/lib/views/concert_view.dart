import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/track.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_player_service.dart';
import '../services/concert_service.dart';
import '../widgets/concert_lightstick_modal.dart';
import '../widgets/app_alert.dart';

class ConcertView extends StatefulWidget {
  final AudioPlayerService audioService;
  final Track? initialTrack;

  const ConcertView({
    super.key,
    required this.audioService,
    this.initialTrack,
  });

  @override
  State<ConcertView> createState() => _ConcertViewState();
}

class _ConcertViewState extends State<ConcertView> with TickerProviderStateMixin {
  final ConcertService _concert = ConcertService.instance;
  late AnimationController _laserController;
  late AnimationController _spotlightController;
  late AnimationController _waveVisualizerController;
  final TextEditingController _shoutoutInputController = TextEditingController();

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Track?>? _trackChangeSub;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.audioService.player.playing;

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _spotlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _waveVisualizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _concert.addListener(_onConcertUpdate);

    _playerStateSub = widget.audioService.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    _trackChangeSub = widget.audioService.currentTrackStream.listen((track) {
      if (mounted) setState(() {});
    });

    // If initial track was provided and nothing is playing yet, play it with acoustics
    if (widget.initialTrack != null && widget.audioService.currentTrack?.id != widget.initialTrack!.id) {
      _concert.convertTrackToConcertPerformance(widget.initialTrack!, widget.audioService);
    } else {
      _concert.applyCurrentAcoustics();
    }
  }

  void _onConcertUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _laserController.dispose();
    _spotlightController.dispose();
    _waveVisualizerController.dispose();
    _shoutoutInputController.dispose();
    _playerStateSub?.cancel();
    _trackChangeSub?.cancel();
    _concert.removeListener(_onConcertUpdate);
    super.dispose();
  }

  Track get _activeTrack {
    return widget.audioService.currentTrack ?? _concert.currentConcert.setlist.first;
  }

  void _openLightstickModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ConcertLightstickModal(concertService: _concert),
    );
  }

  void _showShoutoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.record_voice_over_rounded, color: _concert.currentVenue.primaryColor),
            const SizedBox(width: 10),
            const Text(
              'Backstage Fan Shoutout',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your shoutout will be broadcast to everyone in the Arena live set!',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _shoutoutInputController,
              maxLength: 120,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. London loves this live performance',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _concert.currentVenue.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final text = _shoutoutInputController.text;
              if (text.trim().isNotEmpty) {
                _concert.postShoutout(text);
                _shoutoutInputController.clear();
                Navigator.pop(context);
                AppAlert.show(context, 'Broadcasted to Live Arena Fans', isSuccess: true);
                _concert.triggerReaction('cheer');
              }
            },
            child: const Text('Broadcast', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openHostConcertModal() {
    final titleCtrl = TextEditingController(text: 'Live Acoustic Session');
    final artistCtrl = TextEditingController(text: 'Live Studio Artist');
    String selectedVenueId = ConcertService.availableVenues[0].id;
    final primary = _concert.currentVenue.primaryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Host a Live Concert Stage',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Text(
                      'Broadcast your music live to listeners worldwide with realistic stadium acoustics and crowd sync.',
                      style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'CONCERT OR TOUR TITLE',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: titleCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'e.g. World Stadium Tour, Midnight Acoustic',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'ARTIST NAME',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: artistCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Your Artist / Band Name',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'SELECT VENUE & ACOUSTICS',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ConcertService.availableVenues.map((v) {
                        final isSel = selectedVenueId == v.id;
                        return ChoiceChip(
                          label: Text(
                            v.name,
                            style: TextStyle(
                              color: isSel ? Colors.black : Colors.white,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSel,
                          selectedColor: Colors.white,
                          backgroundColor: const Color(0xFF1A1A1A),
                          side: BorderSide(color: isSel ? Colors.transparent : Colors.white10),
                          onSelected: (val) {
                            if (val) setModalState(() => selectedVenueId = v.id);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.sensors_rounded, size: 20),
                        label: const Text('Go Live & Broadcast Stage', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          final title = titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : 'Live Stage';
                          final artist = artistCtrl.text.trim().isNotEmpty ? artistCtrl.text.trim() : 'Live Artist';
                          final current = widget.audioService.currentTrack;
                          final setlist = current != null
                              ? [current, ..._concert.currentConcert.setlist.take(3)]
                              : _concert.currentConcert.setlist;

                          _concert.hostNewConcert(
                            title: title,
                            artist: artist,
                            venueId: selectedVenueId,
                            setlist: setlist,
                          );
                          if (current != null) {
                            widget.audioService.playTrack(current);
                          }
                          Navigator.pop(context);
                          if (mounted) {
                            AppAlert.show(
                              this.context,
                              'Stage "$title" is now broadcasting live in the Arena!',
                              icon: Icons.check_circle_rounded,
                              isSuccess: true,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLiveArenasFeed(Color primary, Color secondary) {
    final concerts = _concert.allConcerts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LIVE CONCERT ARENAS',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openHostConcertModal,
                child: Row(
                  children: [
                    Icon(Icons.sensors_rounded, color: primary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Host Stage',
                      style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 126,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            scrollDirection: Axis.horizontal,
            itemCount: concerts.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final c = concerts[index];
              final isCurrent = _concert.currentConcert.id == c.id;
              return GestureDetector(
                onTap: () {
                  _concert.selectConcert(c, widget.audioService);
                  HapticFeedback.mediumImpact();
                  AppAlert.show(
                    context,
                    'Joined "${c.title}" live stage!',
                    icon: Icons.check_circle_rounded,
                    isSuccess: true,
                  );
                },
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrent ? primary.withValues(alpha: 0.16) : const Color(0xFF121216),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrent ? primary : Colors.white12,
                      width: isCurrent ? 1.6 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.isLiveNow ? const Color(0xFFFF4757) : Colors.white24,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              c.isLiveNow ? 'LIVE' : 'RECORDED',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          ),
                          Text(
                            '${c.baseAudience} fans',
                            style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${c.artist} • ${c.venueName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: isCurrent ? primary : Colors.white60, fontSize: 11),
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    final venue = _concert.currentVenue;
    final primary = venue.primaryColor;
    final secondary = venue.secondaryColor;
    final currentTrack = _activeTrack;

    return Scaffold(
      backgroundColor: const Color(0xFF070709),
      body: Stack(
        children: [
          // 1. Stage Background with Dynamic Lasers and Spotlights
          Positioned.fill(
            child: CustomPaint(
              painter: _StageAtmospherePainter(
                laserAnimation: _laserController,
                spotlightAnimation: _spotlightController,
                primaryColor: primary,
                secondaryColor: secondary,
              ),
            ),
          ),

          // 2. Main Scrollable Concert Arena Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Bar / Top Navigation
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (Navigator.canPop(context))
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                            onPressed: () => Navigator.pop(context),
                          )
                        else
                          Row(
                            children: [
                              Icon(Icons.stadium_rounded, color: primary, size: 24),
                              const SizedBox(width: 8),
                              const Text(
                                'Concert Arena',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        // Live Arena Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: primary.withValues(alpha: 0.5), width: 1.2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFFF4757),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_concert.liveAudienceCount} FANS',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Action buttons: Host Stage + Lightstick
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.sensors_rounded, color: Colors.white, size: 22),
                              tooltip: 'Host / Broadcast Stage',
                              onPressed: _openHostConcertModal,
                            ),
                            IconButton(
                              icon: Icon(Icons.highlight_rounded, color: secondary, size: 22),
                              tooltip: 'Open Synchronized Lightstick',
                              onPressed: _openLightstickModal,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Live Concert Arenas List
                  _buildLiveArenasFeed(primary, secondary),

                  const SizedBox(height: 14),

                  // 3. Stage Jumbotron Screen (Central Live Performance Visualizer)
                  _buildStageJumbotron(currentTrack, primary, secondary),

                  const SizedBox(height: 20),

                  // 4. Perspective Selector (Front Row, Soundboard, Bleachers)
                  _buildPerspectiveSelector(primary),

                  const SizedBox(height: 18),

                  // 5. Venue Acoustics Switcher Carousel
                  _buildVenueAcousticSelector(primary, secondary),

                  const SizedBox(height: 20),

                  // 6. Stage Soundboard & Dual Routing Quick Deck
                  _buildSoundboardControls(primary, secondary),

                  const SizedBox(height: 24),

                  // 7. Live Fan Social Stream & Backstage Shoutouts
                  _buildLiveFanShoutoutsSection(primary),

                  const SizedBox(height: 24),

                  // 8. Live Arena Setlist & Curated Stages
                  _buildLiveSetlistSection(currentTrack, primary),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // 9. Floating Audience Reaction Particles Layer
          Positioned.fill(
            child: IgnorePointer(
              child: _buildFloatingReactionsLayer(),
            ),
          ),

          // 10. Sticky Bottom Fan Interaction Bar (Cheer, Lightstick, Reactions)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildStickyFanReactionDeck(primary, secondary),
          ),
        ],
      ),
    );
  }

  // --- UI Components ---

  Widget _buildStageJumbotron(Track track, Color primary, Color secondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: primary.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Jumbotron Backdrop Image
              Image.network(
                track.artworkUrl.isNotEmpty ? track.artworkUrl : _concert.currentConcert.bannerUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF151520)),
              ),

              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),

              // Jumbotron Content (Stage Title, Live Codec, Audio Visualizer)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Info Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.spatial_audio_off_rounded, size: 13, color: secondary),
                              const SizedBox(width: 5),
                              Text(
                                _concert.currentVenue.name.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: primary.withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            track.codec.isNotEmpty ? track.codec : 'FLAC 24-bit 96kHz Arena',
                            style: TextStyle(
                              color: secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Center & Bottom: Track Details & Realtime Visualizer Waves
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${track.artist} • ${_concert.currentConcert.tourName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Real-Time Audio Frequency Visualizer Bars
                        AnimatedBuilder(
                          animation: _waveVisualizerController,
                          builder: (context, _) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(24, (i) {
                                final animVal = _waveVisualizerController.value;
                                final heightOffset = math.sin((i / 4.0) + (animVal * math.pi * 2)).abs();
                                final barHeight = _isPlaying ? (8.0 + (heightOffset * 28.0)) : 4.0;

                                return Container(
                                  width: 4.5,
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        primary,
                                        secondary,
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Stage Crowd Silhouette at bottom of Jumbotron
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 38,
                child: CustomPaint(
                  painter: _CrowdSilhouettePainter(crowdColor: Colors.black.withValues(alpha: 0.9)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerspectiveSelector(Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'STAGE PERSPECTIVE ACOUSTICS',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                _concert.currentPerspective.title,
                style: TextStyle(
                  color: primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF141419),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: StagePerspective.values.map((perspective) {
                final isSelected = _concert.currentPerspective == perspective;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _concert.setPerspective(perspective);
                      HapticFeedback.selectionClick();
                      AppAlert.show(
                        context,
                        'Acoustics: ${perspective.title} - ${perspective.description}',
                        isSuccess: true,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            perspective.icon,
                            size: 16,
                            color: isSelected ? Colors.white : Colors.white60,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            perspective.title.split(' ').first,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVenueAcousticSelector(Color primary, Color secondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'VIRTUAL VENUE ACOUSTIC SIMULATOR',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            scrollDirection: Axis.horizontal,
            itemCount: ConcertService.availableVenues.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final v = ConcertService.availableVenues[index];
              final isSelected = _concert.currentVenue.id == v.id;

              return GestureDetector(
                onTap: () {
                  _concert.setVenue(v);
                  HapticFeedback.mediumImpact();
                  AppAlert.show(context, 'Transferred to ${v.name}! Re-equalizing room...', isSuccess: true);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 220,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? v.primaryColor.withValues(alpha: 0.18) : const Color(0xFF121216),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? v.primaryColor : Colors.white12,
                      width: isSelected ? 1.8 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: v.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(v.icon, color: isSelected ? v.secondaryColor : Colors.white60, size: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              v.capacity,
                              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            v.city,
                            style: TextStyle(
                              color: isSelected ? v.secondaryColor : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
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
        ),
      ],
    );
  }

  Widget _buildSoundboardControls(Color primary, Color secondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111116),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune_rounded, color: primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'CONCERT SOUNDBOARD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ZERO LATENCY',
                    style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                // Venue Acoustics Active Switch
                Expanded(
                  child: _buildSoundboardToggleTile(
                    title: 'Venue Reverb',
                    subtitle: 'Stadium EQ',
                    isActive: _concert.isConcertAcousticsActive,
                    icon: Icons.graphic_eq_rounded,
                    activeColor: primary,
                    onTap: () {
                      _concert.toggleConcertAcoustics(!_concert.isConcertAcousticsActive);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Crowd Cheer Ambience Switch
                Expanded(
                  child: _buildSoundboardToggleTile(
                    title: 'Crowd Audio',
                    subtitle: 'Cheer Loop',
                    isActive: _concert.isCrowdAmbienceEnabled,
                    icon: Icons.groups_rounded,
                    activeColor: secondary,
                    onTap: () {
                      _concert.toggleCrowdAmbience(!_concert.isCrowdAmbienceEnabled);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Pi Speaker Broadcast
                Expanded(
                  child: _buildSoundboardToggleTile(
                    title: 'Pi Broadcast',
                    subtitle: 'Stage Speaker',
                    isActive: _concert.isPiBroadcastEnabled,
                    icon: Icons.speaker_group_rounded,
                    activeColor: const Color(0xFF00B894),
                    onTap: () {
                      _concert.togglePiBroadcast(!_concert.isPiBroadcastEnabled);
                      AppAlert.show(
                        context,
                        _concert.isPiBroadcastEnabled
                            ? 'Broadcasting Stadium Audio to Raspberry Pi!'
                            : 'Audio routed back to Phone Headphones',
                        isSuccess: _concert.isPiBroadcastEnabled,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundboardToggleTile({
    required String title,
    required String subtitle,
    required bool isActive,
    required IconData icon,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.16) : const Color(0xFF191920),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? activeColor.withValues(alpha: 0.8) : Colors.white12,
            width: isActive ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? activeColor : Colors.white54, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              style: TextStyle(
                color: isActive ? activeColor : Colors.white38,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveFanShoutoutsSection(Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LIVE FAN SHOUTOUTS',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              GestureDetector(
                onTap: _showShoutoutDialog,
                child: Text(
                  '+ Post Shoutout',
                  style: TextStyle(
                    color: primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFF101014),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _concert.shoutouts.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 16),
              itemBuilder: (context, index) {
                final s = _concert.shoutouts[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: s.avatarColor.withValues(alpha: 0.3),
                      child: Text(
                        s.userName[0].toUpperCase(),
                        style: TextStyle(
                          color: s.avatarColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                s.userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                s.city,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                              if (s.badge != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: s.avatarColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    s.badge!,
                                    style: TextStyle(
                                      color: s.avatarColor,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.message,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveSetlistSection(Track currentTrack, Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LIVE CONCERT SETLIST',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                '${_concert.currentConcert.setlist.length} Songs',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _concert.currentConcert.setlist.length,
            itemBuilder: (context, index) {
              final song = _concert.currentConcert.setlist[index];
              final isCurrent = currentTrack.title == song.title;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: isCurrent ? primary.withValues(alpha: 0.15) : Colors.transparent,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCurrent ? primary : const Color(0xFF222228),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: isCurrent
                        ? const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 18)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                title: Text(
                  song.title,
                  maxLines: 1,
                  style: TextStyle(
                    color: isCurrent ? Colors.white : Colors.white70,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  song.artist,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4757),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ON STAGE',
                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        isCurrent && _isPlaying ? Icons.pause_circle_rounded : Icons.play_circle_fill_rounded,
                        color: isCurrent ? primary : Colors.white54,
                        size: 30,
                      ),
                      onPressed: () {
                        if (isCurrent && _isPlaying) {
                          widget.audioService.pause();
                        } else {
                          widget.audioService.playTrack(song);
                          _concert.applyCurrentAcoustics();
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Convert current library song button
          GestureDetector(
            onTap: () {
              if (widget.audioService.currentTrack != null) {
                _concert.convertTrackToConcertPerformance(widget.audioService.currentTrack!, widget.audioService);
                AppAlert.show(context, 'Enhanced with ${_concert.currentVenue.name} Stadium Acoustics', isSuccess: true);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withValues(alpha: 0.6)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.35),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.surround_sound_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'CONVERT ANY SONG TO ARENA CONCERT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _reactionIcon(String type) {
    switch (type) {
      case 'fire':
        return Icons.local_fire_department_rounded;
      case 'spark':
        return Icons.star_rounded;
      case 'note':
        return Icons.music_note_rounded;
      case 'heart':
        return Icons.favorite_rounded;
      case 'cheer':
      default:
        return Icons.thumb_up_rounded;
    }
  }

  Widget _buildFloatingReactionsLayer() {
    final primary = _concert.currentVenue.primaryColor;

    return Stack(
      children: _concert.reactions.map((r) {
        final ageMs = DateTime.now().difference(r.createdAt).inMilliseconds;
        final progress = (ageMs / 3500.0).clamp(0.0, 1.0);
        final yOffset = (1.0 - progress) * MediaQuery.of(context).size.height * 0.75;
        final opacity = (1.0 - progress).clamp(0.0, 1.0);

        return Positioned(
          left: MediaQuery.of(context).size.width * r.xOffset,
          bottom: 90 + yOffset,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: 0.8 + (0.5 * math.sin(progress * math.pi)),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: primary.withValues(alpha: 0.6)),
                ),
                child: Icon(
                  _reactionIcon(r.reactionType),
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStickyFanReactionDeck(Color primary, Color secondary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C10).withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.9),
            blurRadius: 25,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // Synchronized Lightstick button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              icon: const Icon(Icons.highlight_rounded, size: 18),
              label: const Text(
                'LIGHTSTICK',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0),
              ),
              onPressed: _openLightstickModal,
            ),
            const SizedBox(width: 8),

            // Cheer Loudly Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22222C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: BorderSide(color: secondary.withValues(alpha: 0.5)),
              ),
              onPressed: () {
                HapticFeedback.heavyImpact();
                _concert.triggerCrowdCheer();
              },
              child: Row(
                children: [
                  const Text('CHEER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 4),
                  Icon(Icons.volume_up_rounded, size: 16, color: secondary),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Instant Icon Reaction Buttons
            Row(
              children: [
                (Icons.favorite_rounded, 'heart'),
                (Icons.local_fire_department_rounded, 'fire'),
                (Icons.star_rounded, 'spark'),
                (Icons.music_note_rounded, 'note'),
              ].map((item) {
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _concert.triggerReaction(item.$2);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(item.$1, size: 18, color: Colors.white70),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Custom Painters for Stage Atmosphere & Crowd ---

class _StageAtmospherePainter extends CustomPainter {
  final Animation<double> laserAnimation;
  final Animation<double> spotlightAnimation;
  final Color primaryColor;
  final Color secondaryColor;

  _StageAtmospherePainter({
    required this.laserAnimation,
    required this.spotlightAnimation,
    required this.primaryColor,
    required this.secondaryColor,
  }) : super(repaint: Listenable.merge([laserAnimation, spotlightAnimation]));

  @override
  void paint(Canvas canvas, Size size) {
    final laserVal = laserAnimation.value;
    final spotVal = spotlightAnimation.value;

    // Background Darkness
    final bgPaint = Paint()..color = const Color(0xFF060608);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Dynamic Moving Laser Beams from top corners
    final laserPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.35)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final leftLaserX = size.width * (0.2 + (laserVal * 0.6));
    final rightLaserX = size.width * (0.8 - (laserVal * 0.6));

    canvas.drawLine(const Offset(0, 20), Offset(leftLaserX, size.height * 0.45), laserPaint);
    canvas.drawLine(Offset(size.width, 20), Offset(rightLaserX, size.height * 0.45), laserPaint);

    // Dynamic Spotlight Cones
    final spotPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          secondaryColor.withValues(alpha: 0.15 + (spotVal * 0.1)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.5 + (math.sin(spotVal * math.pi) * 80), size.height * 0.25),
        radius: 200,
      ));

    canvas.drawCircle(
      Offset(size.width * 0.5 + (math.sin(spotVal * math.pi) * 80), size.height * 0.25),
      200,
      spotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StageAtmospherePainter oldDelegate) => true;
}

class _CrowdSilhouettePainter extends CustomPainter {
  final Color crowdColor;

  _CrowdSilhouettePainter({required this.crowdColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = crowdColor;
    final path = Path();

    path.moveTo(0, size.height);
    path.lineTo(0, size.height * 0.4);

    // Draw wavy crowd silhouettes and waving hands
    final step = size.width / 24.0;
    for (int i = 0; i < 24; i++) {
      final x = i * step;
      final y = size.height * (0.3 + (math.sin(i * 1.5) * 0.2));
      path.lineTo(x, y);
      // Small waving hand spikes
      if (i % 3 == 0) {
        path.lineTo(x + 2, y - 8);
        path.lineTo(x + 4, y);
      }
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CrowdSilhouettePainter oldDelegate) => false;
}
