import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/concert_service.dart';

class ConcertLightstickModal extends StatefulWidget {
  final ConcertService concertService;

  const ConcertLightstickModal({
    super.key,
    required this.concertService,
  });

  @override
  State<ConcertLightstickModal> createState() => _ConcertLightstickModalState();
}

class _ConcertLightstickModalState extends State<ConcertLightstickModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _waveCount = 0;
  double _tiltAngle = 0.0;
  bool _isHolding = false;
  Timer? _strobeTimer;
  bool _strobeVisible = true;

  final List<Map<String, dynamic>> _colorPresets = [
    {'name': 'Spotify Green', 'color': const Color(0xFF1DB954)},
    {'name': 'Tokyo Cyan', 'color': const Color(0xFF00CEC9)},
    {'name': 'Neon Magenta', 'color': const Color(0xFFFD79A8)},
    {'name': 'Coldplay Solar', 'color': const Color(0xFFFDCB6E)},
    {'name': 'Stadium Flame', 'color': const Color(0xFFFF7675)},
    {'name': 'Electric Mint', 'color': const Color(0xFF00B894)},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _updateStrobe();
  }

  void _updateStrobe() {
    _strobeTimer?.cancel();
    if (widget.concertService.isStrobeMode) {
      _strobeTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
        if (mounted) {
          setState(() {
            _strobeVisible = !_strobeVisible;
          });
        }
      });
    } else {
      _strobeVisible = true;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _strobeTimer?.cancel();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _tiltAngle = (details.localPosition.dx - (MediaQuery.of(context).size.width / 2)) / 300.0;
      _tiltAngle = _tiltAngle.clamp(-0.55, 0.55);
    });
    if (details.delta.distance > 8) {
      _waveCount++;
      if (_waveCount % 5 == 0) {
        HapticFeedback.lightImpact();
        widget.concertService.triggerReaction('spark');
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _tiltAngle = 0.0;
      _isHolding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.concertService.lightstickColor;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onPanDown: (_) => setState(() => _isHolding = true),
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Stack(
            children: [
              // Ambient Stage Background Glow
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final pulse = _pulseController.value;
                  final opacity = widget.concertService.isStrobeMode
                      ? (_strobeVisible ? 0.35 : 0.04)
                      : (0.15 + 0.15 * pulse);

                  return Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.2),
                          radius: 1.2,
                          colors: [
                            activeColor.withValues(alpha: opacity),
                            Colors.black,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Header Bar
              Positioned(
                top: 16,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Column(
                      children: [
                        const Text(
                          'SYNCHRONIZED LIGHTSTICK',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: activeColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: activeColor.withValues(alpha: 0.8),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'WAVE TO SYNC • $_waveCount WAVES',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        widget.concertService.isStrobeMode
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: widget.concertService.isStrobeMode ? activeColor : Colors.white60,
                        size: 26,
                      ),
                      onPressed: () {
                        widget.concertService.toggleStrobeMode(!widget.concertService.isStrobeMode);
                        _updateStrobe();
                        HapticFeedback.mediumImpact();
                      },
                    ),
                  ],
                ),
              ),

              // Interactive Glowing Concert Lightstick Wand
              Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final pulse = _pulseController.value;
                    final glowSpread = widget.concertService.isStrobeMode
                        ? (_strobeVisible ? 35.0 : 0.0)
                        : (20.0 + 15.0 * pulse);

                    return Transform.rotate(
                      angle: _tiltAngle,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top Lightstick Tube
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 60),
                            width: 64,
                            height: size.height * 0.42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white,
                                  activeColor,
                                  activeColor.withValues(alpha: 0.85),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: activeColor.withValues(
                                    alpha: widget.concertService.isStrobeMode
                                        ? (_strobeVisible ? 0.9 : 0.1)
                                        : 0.75,
                                  ),
                                  blurRadius: glowSpread,
                                  spreadRadius: glowSpread * 0.35,
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.graphic_eq_rounded,
                                    size: 32,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'AAMPS',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 4.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Metal Ring Divider
                          Container(
                            width: 50,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF333333),
                              border: Border.all(color: Colors.white24, width: 1.0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),

                          // Handle
                          Container(
                            width: 44,
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(22),
                                bottomRight: Radius.circular(22),
                              ),
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFF1E1E1E),
                                  Color(0xFF2A2A2A),
                                  Color(0xFF151515),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: activeColor.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Icon(Icons.touch_app_rounded, color: Colors.white24, size: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Interactive Gesture Hint
              Positioned(
                bottom: 120,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      _isHolding ? 'Waving lightstick. Drag to sway' : 'Touch and swipe screen to wave with crowd',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              // Color Preset Selector Bar
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _colorPresets.map((item) {
                      final c = item['color'] as Color;
                      final isSelected = activeColor == c;

                      return GestureDetector(
                        onTap: () {
                          widget.concertService.setLightstickColor(c);
                          HapticFeedback.selectionClick();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 42 : 32,
                          height: isSelected ? 42 : 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 3.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: c.withValues(alpha: 0.8),
                                      blurRadius: 14,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
