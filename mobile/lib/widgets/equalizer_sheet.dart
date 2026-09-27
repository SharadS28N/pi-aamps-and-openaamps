import 'package:flutter/material.dart';
import '../services/equalizer_service.dart';

class EqualizerSheet extends StatefulWidget {
  const EqualizerSheet({super.key});

  @override
  State<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends State<EqualizerSheet> {
  final EqualizerService _eq = EqualizerService.instance;

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
      return k == k.roundToDouble() ? '${k.toInt()}k' : '${k.toStringAsFixed(1)}k';
    }
    return '$hz';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF101010),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header with Master Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    '15-Band Equalizer & AutoEq',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Switch(
                value: _eq.isEnabled,
                activeTrackColor: Colors.white38,
                activeThumbColor: Colors.white,
                onChanged: (val) => _eq.setEnabled(val),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Presets horizontal list
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: EqualizerService.presets.keys.map((presetName) {
                final active = _eq.activePreset == presetName;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: _eq.isEnabled ? () => _eq.setPreset(presetName) : null,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? Colors.white : const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: active ? Colors.white : Colors.white12),
                      ),
                      child: Text(
                        presetName,
                        style: TextStyle(
                          color: active ? Colors.black : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // AutoEq Headphone Correction Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF18181A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.headphones_rounded, color: Colors.white70, size: 20),
                const SizedBox(width: 10),
                const Text('AutoEq Profile:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E1E20),
                      value: _eq.activeAutoEqId,
                      hint: const Text('Select Headphone Profile', style: TextStyle(color: Colors.white38, fontSize: 13)),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      items: EqualizerService.autoEqCatalog.map((prof) {
                        return DropdownMenuItem<String>(
                          value: prof.id,
                          child: Text('${prof.brand} • ${prof.name}', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: _eq.isEnabled
                          ? (id) {
                              if (id != null) _eq.applyAutoEq(id);
                            }
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 15 Vertical Sliders
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(15, (index) {
                    final freq = EqualizerService.bandFrequencies[index];
                    final gain = _eq.bandGains[index];

                    return SizedBox(
                      width: 52,
                      child: Column(
                        children: [
                          Text(
                            '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: gain != 0 ? Colors.white : Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: const Color(0xFF27272A),
                                  thumbColor: Colors.white,
                                  disabledThumbColor: Colors.white24,
                                  disabledActiveTrackColor: Colors.white12,
                                  disabledInactiveTrackColor: Colors.white10,
                                ),
                                child: Slider(
                                  value: gain,
                                  min: -12.0,
                                  max: 12.0,
                                  onChanged: _eq.isEnabled
                                      ? (val) => _eq.setBandGain(index, val)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            _formatFreq(freq),
                            style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          // 16D Spatial Surround Audio Mode (Survey Priority Feature)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _eq.is16dAudio
                    ? [const Color(0xFF6366F1).withValues(alpha: 0.2), const Color(0xFFA855F7).withValues(alpha: 0.15)]
                    : [const Color(0xFF18181A), const Color(0xFF141416)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _eq.is16dAudio ? const Color(0xFF818CF8) : Colors.white10,
                width: _eq.is16dAudio ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _eq.is16dAudio ? const Color(0xFF6366F1) : const Color(0xFF27272A),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.surround_sound_rounded,
                    color: _eq.is16dAudio ? Colors.white : Colors.white54,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '16D Spatial Audio',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          if (_eq.is16dAudio) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Rotating 360° binaural surround & deep resonance',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _eq.is16dAudio,
                  activeThumbColor: const Color(0xFF818CF8),
                  activeTrackColor: const Color(0xFF4338CA),
                  onChanged: _eq.isEnabled ? (_) => _eq.toggle16dAudio() : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Bass Boost & Virtualizer Dual Sliders
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Bass Boost', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('${(_eq.bassBoost * 100).toInt()}%', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                      SliderTheme(
                        data: const SliderThemeData(
                          trackHeight: 2,
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Color(0xFF27272A),
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: _eq.bassBoost,
                          onChanged: _eq.isEnabled ? (v) => _eq.setBassBoost(v) : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Virtualizer 3D', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('${(_eq.virtualizer * 100).toInt()}%', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                      SliderTheme(
                        data: const SliderThemeData(
                          trackHeight: 2,
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Color(0xFF27272A),
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: _eq.virtualizer,
                          onChanged: _eq.isEnabled ? (v) => _eq.setVirtualizer(v) : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
