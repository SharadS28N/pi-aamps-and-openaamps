import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/equalizer_service.dart';

class EqualizerSheet extends StatefulWidget {
  const EqualizerSheet({super.key});

  @override
  State<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends State<EqualizerSheet> {
  final EqualizerService _eq = EqualizerService.instance;
  bool _showAll15Bands = false;

  // 5 primary display bands matching reference image: 40 Hz, 131 Hz, 261 Hz, 900 Hz, 8.7 kHz
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
    const accentPurple = Color(0xFFA855F7);
    const accentPink = Color(0xFFEC4899);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF14151C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF262837), width: 1.2)),
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

          // Top Bar: Back, Equalizer Title, Switch Toggle
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
                    activeThumbColor: accentPink,
                    activeTrackColor: accentPurple.withValues(alpha: 0.5),
                    inactiveThumbColor: Colors.white38,
                    inactiveTrackColor: const Color(0xFF262837),
                    onChanged: (val) => _eq.setEnabled(val),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF202230), height: 16),

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
                          color: const Color(0xFF1E202B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2E3245), width: 1),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: EqualizerService.presets.containsKey(_eq.activePreset)
                                ? _eq.activePreset
                                : 'Flat',
                            dropdownColor: const Color(0xFF1E202B),
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
                      color: const Color(0xFF1A1C26),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF262837), width: 1),
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
                              SizedBox(height: 14), // offset for bottom frequency label
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
                                      accentColor: accentPurple,
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
                                        accentColor: accentPurple,
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

                  // Spatial Preset Row with Toggle (Reference Image 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Preset',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'ON',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: _eq.virtualizer > 0 || _eq.bassBoost > 0 || _eq.is8dAudio || _eq.is16dAudio,
                              activeThumbColor: accentPink,
                              activeTrackColor: accentPurple.withValues(alpha: 0.5),
                              inactiveThumbColor: Colors.white38,
                              inactiveTrackColor: const Color(0xFF262837),
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: _eq.is8dAudio ? accentPurple.withValues(alpha: 0.25) : const Color(0xFF1E202B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _eq.is8dAudio ? accentPurple : const Color(0xFF2E3245),
                                width: _eq.is8dAudio ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.surround_sound_rounded, color: _eq.is8dAudio ? accentPurple : Colors.white70, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  '8D Surround',
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: _eq.is16dAudio ? accentPink.withValues(alpha: 0.25) : const Color(0xFF1E202B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _eq.is16dAudio ? accentPink : const Color(0xFF2E3245),
                                width: _eq.is16dAudio ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.spatial_audio_off_rounded, color: _eq.is16dAudio ? accentPink : Colors.white70, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  '16D Spatial',
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

                  // TWO CIRCULAR DIALS (Surround 46% & Bass Booster 80%) Matching Reference 1 Screen 3
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Dial: Surround
                      Expanded(
                        child: _CircularEffectDial(
                          value: _eq.virtualizer,
                          title: 'Sourround',
                          subtitle: 'Adding surround sound speakers is the next step to another level.',
                          colorA: const Color(0xFF8B5CF6),
                          colorB: const Color(0xFF06B6D4),
                          onChanged: _eq.isEnabled ? (v) => _eq.setVirtualizer(v) : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right Dial: Bass Booster
                      Expanded(
                        child: _CircularEffectDial(
                          value: _eq.bassBoost,
                          title: 'Bass Booster',
                          subtitle: 'Bassbooster sound speakers is the next step to another level.',
                          colorA: const Color(0xFFEC4899),
                          colorB: const Color(0xFF8B5CF6),
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
                    inactiveTrackColor: const Color(0xFF262837),
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

/// Custom Circular Progress Dial Widget matching Reference 1 Screen 3
class _CircularEffectDial extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final String title;
  final String subtitle;
  final Color colorA;
  final Color colorB;
  final ValueChanged<double>? onChanged;

  const _CircularEffectDial({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.colorA,
    required this.colorB,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (value.clamp(0.0, 1.0) * 100).toInt();

    return Column(
      children: [
        GestureDetector(
          onPanUpdate: onChanged == null
              ? null
              : (details) {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    final center = renderBox.size.center(Offset.zero);
                    final touch = details.localPosition - center;
                    // Angle relative to top
                    double angle = math.atan2(touch.dy, touch.dx) + (math.pi / 2);
                    if (angle < 0) angle += 2 * math.pi;
                    final newVal = (angle / (2 * math.pi)).clamp(0.0, 1.0);
                    onChanged!(newVal);
                  }
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
                    startColor: colorA,
                    endColor: colorB,
                  ),
                ),
                Text(
                  '$pct%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
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
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  final double progress;
  final Color startColor;
  final Color endColor;

  _DialPainter({
    required this.progress,
    required this.startColor,
    required this.endColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;

    // Background track ring
    final bgPaint = Paint()
      ..color = const Color(0xFF222433)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Active progress arc
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final activePaint = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [startColor, endColor],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(rect, startAngle, sweepAngle, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor;
  }
}
