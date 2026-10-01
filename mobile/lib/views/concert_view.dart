import 'dart:async';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();

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

    _playerStateSub = widget.audioService.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });

    _trackChangeSub = widget.audioService.currentTrackStream.listen((track) {
      if (mounted) setState(() {});
    });

    if (widget.initialTrack != null && widget.audioService.currentTrack?.id != widget.initialTrack!.id) {
      _concert.convertTrackToConcertPerformance(widget.initialTrack!, widget.audioService);
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
        backgroundColor: const Color(0xFF141414),
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
              'Your shoutout will be broadcast to everyone in the Arena live set.',
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
                fillColor: const Color(0xFF222222),
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
            child: const Text('Broadcast', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openSeatBookingSheet(LiveConcert concert) {
    String selectedTier = 'General Admission';
    String selectedSeat = 'SEC-A • ROW 3 • SEAT 14';
    double currentPrice = concert.ticketPrice;
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
                          'Online Concert Seat Booking',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Text(
                      '${concert.title} • ${concert.artist}',
                      style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${concert.venueName} • ${concert.scheduledTime}',
                      style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                    ),
                    const SizedBox(height: 20),

                    // TICKET TIERS
                    const Text(
                      'SELECT TICKET TIER',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 10),
                    _buildTierOption(
                      title: 'General Admission Stand',
                      subtitle: 'Direct online arena stereo stream & live chat',
                      priceTag: concert.isPaid ? '\$${concert.ticketPrice.toStringAsFixed(2)}' : 'FREE RSVP',
                      isSelected: selectedTier == 'General Admission',
                      onTap: () {
                        setModalState(() {
                          selectedTier = 'General Admission';
                          selectedSeat = 'SEC-STAND • ROW 12 • SEAT 44';
                          currentPrice = concert.ticketPrice;
                        });
                      },
                      primary: primary,
                    ),
                    const SizedBox(height: 8),
                    _buildTierOption(
                      title: 'VIP Front Row Pit',
                      subtitle: 'Proximity vocal monitor + Interactive lightstick synch',
                      priceTag: concert.isPaid ? '\$${(concert.ticketPrice + 4.99).toStringAsFixed(2)}' : '\$4.99 VIP',
                      isSelected: selectedTier == 'VIP Front Row Pit',
                      onTap: () {
                        setModalState(() {
                          selectedTier = 'VIP Front Row Pit';
                          selectedSeat = 'SEC-PIT • ROW 1 • SEAT 08';
                          currentPrice = concert.ticketPrice + 4.99;
                        });
                      },
                      primary: primary,
                    ),
                    const SizedBox(height: 8),
                    _buildTierOption(
                      title: 'Backstage Pass & Soundboard',
                      subtitle: 'Master audio feed + Stage shoutouts & VIP badge',
                      priceTag: concert.isPaid ? '\$${(concert.ticketPrice + 9.99).toStringAsFixed(2)}' : '\$9.99 ALL ACCESS',
                      isSelected: selectedTier == 'Backstage Pass',
                      onTap: () {
                        setModalState(() {
                          selectedTier = 'Backstage Pass';
                          selectedSeat = 'SEC-SOUNDBOARD • VIP DESK';
                          currentPrice = concert.ticketPrice + 9.99;
                        });
                      },
                      primary: primary,
                    ),

                    const SizedBox(height: 20),

                    // SEAT NUMBER DISPLAY
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161616),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ASSIGNED SEAT', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(selectedSeat, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              currentPrice == 0.0 ? 'FREE' : '\$${currentPrice.toStringAsFixed(2)}',
                              style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.confirmation_number_rounded, size: 20),
                        label: Text(
                          currentPrice == 0.0 ? 'Confirm Free Seat Booking' : 'Book Seat • \$${currentPrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: () async {
                          final pass = await _concert.bookSeat(
                            concert: concert,
                            tier: selectedTier,
                            seatNumber: selectedSeat,
                            price: currentPrice,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          if (mounted) {
                            AppAlert.show(
                              this.context,
                              'Seat confirmed: ${pass.seatNumber} (${pass.passCode})',
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

  Widget _buildTierOption({
    required String title,
    required String subtitle,
    required String priceTag,
    required bool isSelected,
    required VoidCallback onTap,
    required Color primary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? primary.withValues(alpha: 0.12) : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? primary : Colors.white10, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? primary : Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected ? primary : Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                priceTag,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openHostConcertModal() {
    final titleCtrl = TextEditingController(text: 'Online Acoustic Stage');
    final artistCtrl = TextEditingController(text: 'Live Studio Artist');
    final priceCtrl = TextEditingController(text: '0.00');
    String selectedVenueId = ConcertService.availableVenues[0].id;
    bool isPaid = false;
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
                          'Host an Online Concert Stage',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Text(
                      'Host a live concert like an interactive online podcast. Set ticket pricing, capacity, and go live.',
                      style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'CONCERT TITLE',
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
                          hintText: 'e.g. Acoustic Sessions World Tour',
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
                          hintText: 'Your Artist Name',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // FREE OR PAID TOGGLE
                    const Text(
                      'TICKET PRICING',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Free Concert', style: TextStyle(fontSize: 11)),
                          selected: !isPaid,
                          selectedColor: primary,
                          onSelected: (val) {
                            if (val) setModalState(() => isPaid = false);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Paid Tickets', style: TextStyle(fontSize: 11)),
                          selected: isPaid,
                          selectedColor: primary,
                          onSelected: (val) {
                            if (val) setModalState(() => isPaid = true);
                          },
                        ),
                      ],
                    ),

                    if (isPaid) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            prefixText: '\$ ',
                            prefixStyle: TextStyle(color: Colors.white70),
                            hintText: 'Ticket price in USD (e.g. 4.99)',
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Text(
                      'SELECT VENUE ACOUSTICS',
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

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
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
                                isPaid: isPaid,
                                ticketPrice: isPaid ? (double.tryParse(priceCtrl.text) ?? 4.99) : 0.0,
                                goLiveNow: false,
                              );
                              Navigator.pop(context);
                              AppAlert.show(this.context, 'Scheduled "$title" in Online Arena', isSuccess: true);
                            },
                            child: const Text('Schedule for Later', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.sensors_rounded, size: 18),
                            label: const Text('Go Live Now', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                isPaid: isPaid,
                                ticketPrice: isPaid ? (double.tryParse(priceCtrl.text) ?? 4.99) : 0.0,
                                goLiveNow: true,
                              );
                              if (current != null) {
                                widget.audioService.playTrack(current);
                              }
                              Navigator.pop(context);
                              AppAlert.show(this.context, 'Stage is LIVE in the Arena!', isSuccess: true);
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final venue = _concert.currentVenue;
    final primary = venue.primaryColor;
    final secondary = venue.secondaryColor;
    final isStageLive = _concert.isStageLive;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // If stage is live: render stage lighting
          if (isStageLive)
            Positioned.fill(
              child: Opacity(
                opacity: 0.85,
                child: CustomPaint(
                  painter: _StageLaserPainter(
                    laserAnimation: _laserController,
                    spotlightAnimation: _spotlightController,
                    primaryColor: primary,
                    secondaryColor: secondary,
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                // Top Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (Navigator.canPop(context))
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                                onPressed: () => Navigator.pop(context),
                              )
                            else
                              Icon(Icons.stadium_rounded, color: primary, size: 20),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Concert Arena',
                                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Stage Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isStageLive
                              ? const Color(0xFFEF4444).withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isStageLive ? const Color(0xFFEF4444) : Colors.white24,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isStageLive ? const Color(0xFFEF4444) : Colors.white54,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isStageLive ? '${_concert.liveAudienceCount} LIVE' : 'STAGE STANDBY',
                              style: TextStyle(
                                color: isStageLive ? const Color(0xFFEF4444) : Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Host / Action Icon
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                        tooltip: 'Host Concert',
                        onPressed: _openHostConcertModal,
                      ),
                    ],
                  ),
                ),

                // Main Content: Offline Mode vs Live Mode
                Expanded(
                  child: isStageLive
                      ? _buildLiveStage(primary, secondary)
                      : _buildOfflineLobby(primary, secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- OFFLINE LOBBY / BOOKING PLATFORM ---
  Widget _buildOfflineLobby(Color primary, Color secondary) {
    final passes = _concert.userPasses;
    final concerts = _concert.allConcerts;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // STAGE STANDBY BANNER
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF141414),
                  primary.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'STAGE CURRENTLY DARK',
                        style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.nightlife_rounded, color: Colors.white38, size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Live Online Concert Arena',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'The arena stage activates exclusively when an artist or host broadcasts. Browse upcoming scheduled concerts, reserve your seat pass, or broadcast your own stage.',
                  style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: const Icon(Icons.sensors_rounded, size: 16),
                      label: const Text('Host Concert', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: _openHostConcertModal,
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () {
                        // Enter immediately with the first concert
                        _concert.enterStage(concerts.first, widget.audioService);
                      },
                      child: const Text('Enter Live Test Stage', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // MY BOOKED PASSES SECTION
          if (passes.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text(
              'My Booked Passes',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 135,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: passes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final pass = passes[index];
                  return Container(
                    width: 250,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              pass.passCode,
                              style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: pass.isPaid ? const Color(0xFFFFB800).withValues(alpha: 0.2) : Colors.white12,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                pass.isPaid ? 'PAID VIP' : 'FREE PASS',
                                style: TextStyle(
                                  color: pass.isPaid ? const Color(0xFFFFB800) : Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          pass.concertTitle,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pass.seatNumber,
                          style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pass.venueName,
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 28),

          // UPCOMING CONCERTS FEED
          const Text(
            'Upcoming Shows & Seat Reservation',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Reserve a virtual seat tier before the stage broadcast begins.',
            style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: concerts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final c = concerts[index];
              final hasBooked = _concert.hasPass(c.id);

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      child: Stack(
                        children: [
                          Image.network(
                            c.bannerUrl,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(height: 120, color: const Color(0xFF222222)),
                          ),
                          Container(
                            height: 120,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.black54, Colors.transparent],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                c.scheduledTime.toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: c.isPaid ? const Color(0xFFFFB800) : primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                c.isPaid ? '\$${c.ticketPrice.toStringAsFixed(2)} TICKET' : 'FREE RSVP',
                                style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Details
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.title,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${c.artist} • ${c.venueName}',
                            style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 13),
                          ),
                          const SizedBox(height: 12),

                          // Seat Capacity Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${c.bookedSeats} / ${c.totalSeats} seats reserved',
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                              Text(
                                '${((c.bookedSeats / c.totalSeats) * 100).toInt()}% Full',
                                style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (c.bookedSeats / c.totalSeats).clamp(0.0, 1.0),
                              backgroundColor: Colors.white12,
                              color: primary,
                              minHeight: 4,
                            ),
                          ),

                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: hasBooked ? Colors.white12 : primary,
                                    foregroundColor: hasBooked ? Colors.white : Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: Icon(hasBooked ? Icons.check_circle_rounded : Icons.confirmation_number_rounded, size: 16),
                                  label: Text(
                                    hasBooked ? 'Seat Reserved' : (c.isPaid ? 'Book Seat' : 'Reserve Free Seat'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  onPressed: () => _openSeatBookingSheet(c),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 34),
                                tooltip: 'Enter / Broadcast Stage',
                                onPressed: () {
                                  _concert.enterStage(c, widget.audioService);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // --- LIVE STAGE MODE ---
  Widget _buildLiveStage(Color primary, Color secondary) {
    final venue = _concert.currentVenue;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // STAGE JUMBOTRON
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primary.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(color: primary.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _concert.currentConcert.bannerUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(color: const Color(0xFF1B1429)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.9),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),

                  // Stage Live Overlay Info
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _concert.currentConcert.title,
                                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_concert.currentConcert.artist} • ${venue.name}',
                                style: TextStyle(color: secondary, fontSize: 13, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: () => _concert.leaveStage(),
                          child: const Text('Exit Stage', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // ACOUSTIC VENUE SWITCHER
          const Text(
            'VENUE ACOUSTIC PRESET',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ConcertService.availableVenues.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final v = ConcertService.availableVenues[index];
                final isSelected = v.id == venue.id;
                return ChoiceChip(
                  label: Text(v.name),
                  selected: isSelected,
                  selectedColor: primary,
                  backgroundColor: const Color(0xFF141414),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) _concert.setVenue(v);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 18),

          // PERSPECTIVE SELECTOR
          const Text(
            'STAGE SEAT PERSPECTIVE',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Row(
            children: StagePerspective.values.map((p) {
              final isSel = _concert.currentPerspective == p;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _concert.setPerspective(p),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSel ? primary.withValues(alpha: 0.15) : const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSel ? primary : Colors.white10),
                    ),
                    child: Column(
                      children: [
                        Icon(p.icon, color: isSel ? primary : Colors.white54, size: 18),
                        const SizedBox(height: 4),
                        Text(
                          p.title,
                          style: TextStyle(
                            color: isSel ? Colors.white : Colors.white70,
                            fontSize: 10,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // INTERACTION BUTTONS
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF141414),
                    foregroundColor: primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: primary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.highlight_rounded, size: 18),
                  label: const Text('Lightstick', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: _openLightstickModal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF141414),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.celebration_rounded, size: 18),
                  label: const Text('Crowd Cheer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _concert.triggerCrowdCheer(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF141414),
                  side: const BorderSide(color: Colors.white24),
                ),
                icon: const Icon(Icons.record_voice_over_rounded, color: Colors.white),
                tooltip: 'Fan Shoutout',
                onPressed: _showShoutoutDialog,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // LIVE FAN SHOUTOUTS TICKER
          const Text(
            'LIVE ARENA CHAT & SHOUTOUTS',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: ListView.separated(
              itemCount: _concert.shoutouts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final s = _concert.shoutouts[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 8,
                      backgroundColor: s.avatarColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${s.userName}: ',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            TextSpan(
                              text: s.message,
                              style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StageLaserPainter extends CustomPainter {
  final Animation<double> laserAnimation;
  final Animation<double> spotlightAnimation;
  final Color primaryColor;
  final Color secondaryColor;

  _StageLaserPainter({
    required this.laserAnimation,
    required this.spotlightAnimation,
    required this.primaryColor,
    required this.secondaryColor,
  }) : super(repaint: laserAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final t = laserAnimation.value;
    final w = size.width;
    final h = size.height;

    // Laser sweeps
    paint.color = primaryColor.withValues(alpha: 0.25);
    canvas.drawLine(
      Offset(w * 0.1, 0),
      Offset(w * (0.2 + 0.6 * t), h * 0.45),
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.9, 0),
      Offset(w * (0.8 - 0.6 * t), h * 0.45),
      paint,
    );

    // Spotlight cone
    final spotPaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final spotPath = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * (0.2 + 0.3 * spotlightAnimation.value), h * 0.5)
      ..lineTo(w * (0.8 - 0.3 * spotlightAnimation.value), h * 0.5)
      ..close();

    canvas.drawPath(spotPath, spotPaint);
  }

  @override
  bool shouldRepaint(covariant _StageLaserPainter oldDelegate) => true;
}
