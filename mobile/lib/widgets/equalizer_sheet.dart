import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/equalizer_service.dart';
import '../services/settings_service.dart';

class EqualizerSheet extends StatefulWidget {
  const EqualizerSheet({super.key});

  @override
  State<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends State<EqualizerSheet> {
  final EqualizerService _eq = EqualizerService.instance;
  bool _showAll15Bands = false;

  // 5 primary display bands: 40 Hz, 131 Hz, 261 Hz, 900 Hz, 8.7 kHz
  static const List<int> _coreBandIndices = [1, 4, 6, 8, 13];
  static const List<String> _coreBandLabels = ['40 Hz', '131 Hz', '261 Hz', '900 Hz', '8.7 kHz'];

  @override
  void initState() {
    super.initState();
    _eq.addListener(_onStateChange);
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _eq.removeListener(_onStateChange);
    super.dispose();
  }

  String _formatFreq(int hz) {
    if (hz >= 1000) {
      final k = hz / 1000;
      return k == k.roundToDouble() ? '${k.toInt()} kHz' : '${k.toStringAsFixed(1)} kHz';
    }
    return '$hz Hz';
  }

  @override
  Widget build(BuildContext context) {
    final accent = SettingsService.instance.accentColor;
    final secondaryAccent = Color.lerp(accent, Colors.cyanAccent, 0.45) ?? accent;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F13),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1.2)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Top Bar: Back, Equalizer Title, Master Switch Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'Equalizer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: _eq.isEnabled,
                    activeThumbColor: accent,
                    activeTrackColor: accent.withValues(alpha: 0.4),
                    inactiveThumbColor: Colors.white38,
                    inactiveTrackColor: const Color(0xFF222433),
                    onChanged: (val) => _eq.setEnabled(val),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF1E202B), height: 16),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preset Header Row with Sleek Dropdown Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Preset',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF171822),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: EqualizerService.presets.containsKey(_eq.activePreset)
                                ? _eq.activePreset
                                : 'Flat',
                            dropdownColor: const Color(0xFF171822),
                            icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            items: EqualizerService.presets.keys.map((p) {
                              return DropdownMenuItem<String>(
                                value: p,
                                child: Text(p),
                              );
                            }).toList(),
                            onChanged: _eq.isEnabled
                                ? (val) {
                                    if (val != null) _eq.setPreset(val);
                                  }
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Vertical Frequency Sliders Area with Left dB Scale (+10, 0, -10)
                  Container(
                    height: 210,
                    padding: const EdgeInsets.fromLTRB(6, 12, 12, 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF15161E),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
                    ),
                    child: Row(
                      children: [
                        // Left dB Scale Labels
                        const SizedBox(
                          width: 28,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('10', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text('0', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text('-10', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                              SizedBox(height: 14),
                            ],
                          ),
                        ),

                        // Sliders (5 core bands by default, or 15 bands when toggled)
                        Expanded(
                          child: _showAll15Bands
                              ? ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: 15,
                                  itemBuilder: (context, idx) {
                                    final freq = EqualizerService.bandFrequencies[idx];
                                    final gain = _eq.bandGains[idx];
                                    return _buildVerticalSlider(
                                      freqLabel: _formatFreq(freq),
                                      gain: gain,
                                      onChanged: (val) => _eq.setBandGain(idx, val),
                                      accentColor: accent,
                                    );
                                  },
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: List.generate(_coreBandIndices.length, (i) {
                                    final bandIdx = _coreBandIndices[i];
                                    final freqLabel = _coreBandLabels[i];
                                    final gain = _eq.bandGains[bandIdx];
                                    return Expanded(
                                      child: _buildVerticalSlider(
                                        freqLabel: freqLabel,
                                        gain: gain,
                                        onChanged: (val) => _eq.setBandGain(bandIdx, val),
                                        accentColor: accent,
                                      ),
                                    );
                                  }),
                                ),
                        ),
                      ],
                    ),
                  ),

                  // Toggle for 15-band granular EQ
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showAll15Bands = !_showAll15Bands),
                      icon: Icon(
                        _showAll15Bands ? Icons.compress_rounded : Icons.tune_rounded,
                        color: Colors.white54,
                        size: 14,
                      ),
                      label: Text(
                        _showAll15Bands ? 'Show 5 Bands' : 'Show 15 ISO Bands',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Spatial Preset Row with Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Spatial & Acoustic Effects',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (_eq.virtualizer > 0 || _eq.bassBoost > 0 || _eq.is8dAudio || _eq.is16dAudio) ? 'ACTIVE' : 'OFF',
                            style: TextStyle(
                              color: (_eq.virtualizer > 0 || _eq.bassBoost > 0 || _eq.is8dAudio || _eq.is16dAudio)
                                  ? accent
                                  : Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: _eq.virtualizer > 0 || _eq.bassBoost > 0 || _eq.is8dAudio || _eq.is16dAudio,
                              activeThumbColor: accent,
                              activeTrackColor: accent.withValues(alpha: 0.4),
                              inactiveThumbColor: Colors.white38,
                              inactiveTrackColor: const Color(0xFF222433),
                              onChanged: _eq.isEnabled
                                  ? (val) {
                                      if (val) {
                                        _eq.setVirtualizer(0.46);
                                        _eq.setBassBoost(0.80);
                                      } else {
                                        _eq.setVirtualizer(0.0);
                                        _eq.setBassBoost(0.0);
                                        _eq.set8dAudio(false);
                                        _eq.set16dAudio(false);
                                      }
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 8D & 16D Spatial Audio Preset Pills
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _eq.isEnabled ? () => _eq.toggle8dAudio() : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            decoration: BoxDecoration(
                              color: _eq.is8dAudio ? accent.withValues(alpha: 0.18) : const Color(0xFF15161E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _eq.is8dAudio ? accent : Colors.white.withValues(alpha: 0.08),
                                width: _eq.is8dAudio ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.surround_sound_rounded, color: _eq.is8dAudio ? accent : Colors.white70, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  '8D Binaural',
                                  style: TextStyle(
                                    color: _eq.is8dAudio ? Colors.white : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: _eq.isEnabled ? () => _eq.toggle16dAudio() : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            decoration: BoxDecoration(
                              color: _eq.is16dAudio ? secondaryAccent.withValues(alpha: 0.18) : const Color(0xFF15161E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _eq.is16dAudio ? secondaryAccent : Colors.white.withValues(alpha: 0.08),
                                width: _eq.is16dAudio ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.spatial_audio_off_rounded, color: _eq.is16dAudio ? secondaryAccent : Colors.white70, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  '16D Sphere',
                                  style: TextStyle(
                                    color: _eq.is16dAudio ? Colors.white : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // TWO CIRCULAR DIALS (Surround & Bass Booster) - Pure 0% min, 100% max, No looping
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Dial: Surround / Virtualizer
                      Expanded(
                        child: _CircularEffectDial(
                          value: _eq.virtualizer,
                          title: 'Surround',
                          subtitle: 'Spatial acoustics and stereo stage width expansion.',
                          activeColor: secondaryAccent,
                          trackColor: const Color(0xFF1E202B),
                          onChanged: _eq.isEnabled ? (v) => _eq.setVirtualizer(v) : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right Dial: Bass Booster
                      Expanded(
                        child: _CircularEffectDial(
                          value: _eq.bassBoost,
                          title: 'Bass Booster',
                          subtitle: 'Punchy low-end sub-bass resonance and deep harmonics.',
                          activeColor: accent,
                          trackColor: const Color(0xFF1E202B),
                          onChanged: _eq.isEnabled ? (v) => _eq.setBassBoost(v) : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalSlider({
    required String freqLabel,
    required double gain,
    required ValueChanged<double> onChanged,
    required Color accentColor,
  }) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Vertical Tick Marks in background
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(9, (_) => Container(
                  width: 6,
                  height: 1.2,
                  color: Colors.white10,
                )),
              ),
              // Rotated Slider
              RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: accentColor,
                    inactiveTrackColor: const Color(0xFF222433),
                    thumbColor: Colors.white,
                    overlayColor: accentColor.withValues(alpha: 0.2),
                    disabledThumbColor: Colors.white24,
                    disabledActiveTrackColor: Colors.white12,
                    disabledInactiveTrackColor: Colors.white10,
                  ),
                  child: Slider(
                    value: gain,
                    min: -12.0,
                    max: 12.0,
                    onChanged: _eq.isEnabled ? onChanged : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          freqLabel,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Custom Rotary Studio Dial Widget with 270-degree range, deadzone clamping,
/// zero looping at limits (strictly 0% min and 100% max), and both rotary & vertical drag.
class _CircularEffectDial extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final String title;
  final String subtitle;
  final Color activeColor;
  final Color trackColor;
  final ValueChanged<double>? onChanged;

  const _CircularEffectDial({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.activeColor,
    required this.trackColor,
    this.onChanged,
  });

  void _handleAngle(Offset localPosition, Size size) {
    if (onChanged == null) return;
    final center = size.center(Offset.zero);
    final touch = localPosition - center;

    // Standard Cartesian angle (-pi to +pi)
    final theta = math.atan2(touch.dy, touch.dx);

    // Shift relative to 135 deg (bottom-left = 0 rad relative)
    // 135 degrees = 3 * pi / 4
    double rel = theta - (3 * math.pi / 4);
    while (rel < 0) {
      rel += 2 * math.pi;
    }

    // Active sweep is 270 degrees = 1.5 * pi
    const activeSweep = 1.5 * math.pi;
    const deadzoneMid = 1.75 * math.pi; // 90 deg (straight down)

    double newVal;
    if (rel <= activeSweep) {
      newVal = (rel / activeSweep).clamp(0.0, 1.0);
    } else {
      // In bottom deadzone (between 45 deg and 135 deg)
      // If closer to 100% side (bottom-right), pin strictly to 1.0 (100% max)
      // If closer to 0% side (bottom-left), pin strictly to 0.0 (0% min)
      // This completely eliminates looping from 98% -> 0%
      if (rel < deadzoneMid) {
        newVal = 1.0;
      } else {
        newVal = 0.0;
      }
    }

    onChanged!(newVal);
  }

  @override
  Widget build(BuildContext context) {
    final pct = (value.clamp(0.0, 1.0) * 100).toInt();

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const dialSize = Size(100, 100);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: onChanged == null
                  ? null
                  : (details) {
                      // Support rotary tracking with strict clamping
                      _handleAngle(details.localPosition, dialSize);
                    },
              onVerticalDragUpdate: onChanged == null
                  ? null
                  : (details) {
                      // Also support vertical slide gesture (+ up, - down)
                      final delta = -details.primaryDelta! / 120.0;
                      final newVal = (value + delta).clamp(0.0, 1.0);
                      onChanged!(newVal);
                    },
              child: SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(100, 100),
                      painter: _DialPainter(
                        progress: value.clamp(0.0, 1.0),
                        activeColor: activeColor,
                        trackColor: trackColor,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$pct%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: value > 0 ? activeColor : Colors.white24,
                            shape: BoxShape.circle,
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
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFFA1A1AA),
              fontSize: 11,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color trackColor;

  _DialPainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 14) / 2;

    // 270-degree arc: starts at 135 deg (3*pi/4), sweeps 270 deg (1.5*pi) to 45 deg (pi/4)
    const startAngle = 3 * math.pi / 4;
    const totalSweep = 1.5 * math.pi;

    // Background track ring
    final bgPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, totalSweep, false, bgPaint);

    // Active progress arc
    if (progress > 0.005) {
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.5
        ..strokeCap = StrokeCap.round;

      final currentSweep = totalSweep * progress.clamp(0.0, 1.0);
      canvas.drawArc(rect, startAngle, currentSweep, false, activePaint);

      // Draw glowing indicator dot at the end of the arc
      final endAngle = startAngle + currentSweep;
      final indicatorX = center.dx + radius * math.cos(endAngle);
      final indicatorY = center.dy + radius * math.sin(endAngle);

      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(indicatorX, indicatorY), 4.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor;
  }
}
