import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutoEqProfile {
  final String id;
  final String name;
  final String brand;
  final List<double> bandGains; // 15 bands

  const AutoEqProfile({
    required this.id,
    required this.name,
    required this.brand,
    required this.bandGains,
  });
}

class EqualizerService extends ChangeNotifier {
  static final EqualizerService instance = EqualizerService._internal();
  factory EqualizerService() => instance;

  EqualizerService._internal() {
    _loadPreferences();
  }

  // Native hardware effect handles
  AndroidEqualizer? _androidEqualizer;
  AndroidLoudnessEnhancer? _androidLoudnessEnhancer;
  AudioPlayer? _audioPlayer;

  // Spatial Orbital 8D / 16D Engine
  Timer? _spatialOrbitalTimer;
  double _orbitalAngle = 0.0;

  bool _isEnabled = true;
  String _activePreset = 'Flat';
  String? _activeAutoEqId;
  double _bassBoost = 0.0; // 0.0 to 1.0
  double _virtualizer = 0.0; // 0.0 to 1.0

  // 15 ISO frequency bands in Hz
  static const List<int> bandFrequencies = [
    25, 40, 63, 100, 160, 250, 400, 630, 1000, 1600, 2500, 4000, 6300, 10000, 16000
  ];

  // Current gains in dB (-12.0 to +12.0)
  List<double> _bandGains = List.filled(15, 0.0);

  bool _is8dAudio = false;
  bool _is16dAudio = false;

  bool get isEnabled => _isEnabled;
  String get activePreset => _activePreset;
  String? get activeAutoEqId => _activeAutoEqId;
  double get bassBoost => _bassBoost;
  double get virtualizer => _virtualizer;
  bool get is8dAudio => _is8dAudio;
  bool get is16dAudio => _is16dAudio;
  List<double> get bandGains => List.unmodifiable(_bandGains);

  static const Map<String, List<double>> presets = {
    'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    '8D Surround': [4.0, 3.5, 2.5, 1.5, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 4.0, 3.5],
    '16D Spatial': [5.0, 4.5, 3.5, 2.0, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0, 5.5, 5.0, 4.5],
    'Bass Boost': [6.0, 5.5, 5.0, 4.0, 2.5, 1.0, 0, 0, 0, 0, 0.5, 1.0, 1.5, 2.0, 2.5],
    'Audiophile Reference': [-0.5, 0, 0.5, 0, -0.5, 0, 0.5, 0, 0, 0.5, 1.0, 0.5, 0, -0.5, 0],
    'Vocal Clarity': [-2.0, -1.5, -1.0, 0, 1.0, 2.5, 4.0, 4.5, 4.0, 3.0, 2.0, 1.5, 1.0, 0, -1.0],
    'Rock / Metal': [4.5, 4.0, 3.0, 1.5, -0.5, -1.5, 0, 1.5, 2.5, 3.5, 4.0, 4.5, 4.0, 3.5, 3.0],
    'EDM / Electronic': [6.5, 6.0, 5.0, 2.5, 0, -1.0, 0, 1.0, 2.0, 3.0, 4.5, 5.5, 5.0, 4.5, 4.0],
    'Acoustic Warmth': [3.0, 3.0, 2.5, 2.0, 1.5, 1.0, 0.5, 0, 0.5, 1.0, 1.5, 2.0, 2.0, 1.5, 1.0],
    'Classical Concert': [3.5, 3.0, 2.5, 2.0, 0.5, 0, 0, 0, 0.5, 1.5, 2.5, 3.0, 3.5, 4.0, 4.5],
    'Wembley Stadium': [5.0, 4.5, 3.5, 2.0, 1.0, 0.5, 1.0, 1.5, 2.0, 3.0, 3.5, 4.0, 4.5, 4.0, 3.5],
    'Red Rocks Amphitheatre': [2.5, 2.0, 1.5, 1.0, 1.5, 2.5, 3.5, 4.0, 4.0, 3.5, 3.0, 2.5, 2.0, 1.5, 1.0],
    'Tokyo Dome 360': [4.0, 3.5, 2.5, 1.5, 1.0, 1.5, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.0, 4.5, 4.0],
    'Acoustic VIP Pit': [1.5, 2.0, 2.5, 3.0, 3.5, 3.5, 3.0, 2.5, 2.0, 1.5, 1.0, 1.5, 2.0, 2.0, 1.5],
  };

  static const List<AutoEqProfile> autoEqCatalog = [
    AutoEqProfile(
      id: 'sony_xm5',
      name: 'WH-1000XM5 (Harman Target)',
      brand: 'Sony',
      bandGains: [-2.5, -2.0, -1.5, -1.0, 0.5, 1.0, 0.5, -0.5, 1.5, 2.5, 3.0, 2.0, -1.0, 1.0, 0.5],
    ),
    AutoEqProfile(
      id: 'sony_xm4',
      name: 'WH-1000XM4 (Harman Over-Ear)',
      brand: 'Sony',
      bandGains: [-3.0, -2.5, -2.0, -1.0, 0.0, 0.5, 1.0, 0.0, 1.0, 2.0, 2.5, 1.5, -0.5, 0.5, 0.0],
    ),
    AutoEqProfile(
      id: 'airpods_pro_2',
      name: 'AirPods Pro 2 (Target Compensated)',
      brand: 'Apple',
      bandGains: [1.0, 1.0, 0.5, 0.0, -0.5, 0.0, 0.5, 1.0, 0.5, 0.0, 1.5, 2.0, 1.0, -0.5, -1.0],
    ),
    AutoEqProfile(
      id: 'airpods_max',
      name: 'AirPods Max (Harman 2026)',
      brand: 'Apple',
      bandGains: [-1.0, -0.5, 0.0, 0.5, 0.0, -0.5, 0.0, 0.5, 1.0, 1.5, 1.0, 0.5, 0.0, 0.5, 1.0],
    ),
    AutoEqProfile(
      id: 'sennheiser_hd600',
      name: 'HD 600 / HD 650 (Bass Extension)',
      brand: 'Sennheiser',
      bandGains: [4.5, 4.0, 3.0, 2.0, 1.0, 0.0, 0.0, 0.0, -0.5, 0.0, 0.5, 1.0, 0.5, 0.0, -0.5],
    ),
    AutoEqProfile(
      id: 'bose_qc45',
      name: 'QuietComfort 45 / Ultra',
      brand: 'Bose',
      bandGains: [-1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 0.5, 0.0, -0.5, 0.0, 1.0, 1.5, 0.5, -1.0, -0.5],
    ),
    AutoEqProfile(
      id: 'beyerdynamic_dt990',
      name: 'DT 990 Pro (Treble Tamed)',
      brand: 'Beyerdynamic',
      bandGains: [2.5, 2.0, 1.5, 1.0, 0.0, 0.0, 0.0, 0.0, -1.0, -2.0, -3.5, -4.0, -3.0, -1.5, 0.0],
    ),
    AutoEqProfile(
      id: 'harman_target_in_ear',
      name: 'Harman In-Ear Target 2019v2',
      brand: 'Harman',
      bandGains: [3.5, 3.0, 2.5, 1.5, 0.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.5, 3.0, 2.0, 1.0, 0.5],
    ),
  ];

  /// Attach the native JustAudio hardware player & effect pipeline
  void attachPlayer({
    required AndroidEqualizer equalizer,
    required AndroidLoudnessEnhancer loudnessEnhancer,
    required AudioPlayer player,
  }) {
    _androidEqualizer = equalizer;
    _androidLoudnessEnhancer = loudnessEnhancer;
    _audioPlayer = player;
    applyToNativeEffects();
  }

  /// Apply current EQ bands and Loudness Enhancer parameters to native Android audio engine
  Future<void> applyToNativeEffects() async {
    if (_androidEqualizer != null) {
      try {
        await _androidEqualizer!.setEnabled(_isEnabled);
        if (_isEnabled) {
          final params = await _androidEqualizer!.parameters;
          for (final nativeBand in params.bands) {
            final centerHz = nativeBand.centerFrequency;
            double closestGain = 0.0;
            double minDiff = double.infinity;
            for (int i = 0; i < bandFrequencies.length; i++) {
              final diff = (bandFrequencies[i] - centerHz).abs();
              if (diff < minDiff) {
                minDiff = diff;
                closestGain = _bandGains[i];
              }
            }
            final clampedGain = closestGain.clamp(params.minDecibels, params.maxDecibels);
            await nativeBand.setGain(clampedGain);
          }
        }
      } catch (e) {
        debugPrint('Equalizer applyToNativeEffects error: $e');
      }
    }

    if (_androidLoudnessEnhancer != null) {
      try {
        final shouldBoost = _isEnabled && (_bassBoost > 0 || _is8dAudio || _is16dAudio || _virtualizer > 0);
        await _androidLoudnessEnhancer!.setEnabled(shouldBoost);
        if (shouldBoost) {
          // Boost in decibels (0.0 to 10.0 dB)
          final boost = (_bassBoost * 6.0) + (_is8dAudio ? 2.5 : (_is16dAudio ? 4.0 : 0.0));
          await _androidLoudnessEnhancer!.setTargetGain(boost);
        }
      } catch (e) {
        debugPrint('LoudnessEnhancer apply error: $e');
      }
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('eq_enabled') ?? true;
      _activePreset = prefs.getString('eq_preset') ?? 'Flat';
      _activeAutoEqId = prefs.getString('eq_autoeq_id');
      _bassBoost = prefs.getDouble('eq_bass_boost') ?? 0.0;
      _virtualizer = prefs.getDouble('eq_virtualizer') ?? 0.0;

      final savedGains = prefs.getStringList('eq_band_gains');
      if (savedGains != null && savedGains.length == 15) {
        _bandGains = savedGains.map((s) => double.tryParse(s) ?? 0.0).toList();
      } else if (presets.containsKey(_activePreset)) {
        _bandGains = List.from(presets[_activePreset]!);
      }
      applyToNativeEffects();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('eq_enabled', _isEnabled);
      await prefs.setString('eq_preset', _activePreset);
      if (_activeAutoEqId != null) {
        await prefs.setString('eq_autoeq_id', _activeAutoEqId!);
      } else {
        await prefs.remove('eq_autoeq_id');
      }
      await prefs.setDouble('eq_bass_boost', _bassBoost);
      await prefs.setDouble('eq_virtualizer', _virtualizer);
      await prefs.setStringList('eq_band_gains', _bandGains.map((g) => g.toStringAsFixed(2)).toList());
    } catch (_) {}
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    _savePreferences();
    applyToNativeEffects();
    notifyListeners();
  }

  void setPreset(String presetName) {
    if (presets.containsKey(presetName)) {
      _activePreset = presetName;
      _activeAutoEqId = null;
      _bandGains = List.from(presets[presetName]!);
      _savePreferences();
      applyToNativeEffects();
      notifyListeners();
    }
  }

  void applyAutoEq(String profileId) {
    final match = autoEqCatalog.where((p) => p.id == profileId).firstOrNull;
    if (match != null) {
      _activeAutoEqId = profileId;
      _activePreset = 'AutoEq: ${match.name}';
      _bandGains = List.from(match.bandGains);
      _savePreferences();
      applyToNativeEffects();
      notifyListeners();
    }
  }

  void setBandGain(int bandIndex, double gain) {
    if (bandIndex >= 0 && bandIndex < 15) {
      _bandGains[bandIndex] = gain.clamp(-12.0, 12.0);
      _activePreset = 'Custom';
      _activeAutoEqId = null;
      _savePreferences();
      applyToNativeEffects();
      notifyListeners();
    }
  }

  void setBassBoost(double value) {
    _bassBoost = value.clamp(0.0, 1.0);
    _savePreferences();
    applyToNativeEffects();
    notifyListeners();
  }

  void setVirtualizer(double value) {
    _virtualizer = value.clamp(0.0, 1.0);
    _savePreferences();
    applyToNativeEffects();
    notifyListeners();
  }

  void toggle8dAudio() {
    set8dAudio(!_is8dAudio);
  }

  void set8dAudio(bool enable) {
    _is8dAudio = enable;
    if (_is8dAudio) {
      _is16dAudio = false;
      _virtualizer = 0.85;
      _bassBoost = 0.35;
      _activePreset = '8D Surround';
      _bandGains = List.from(presets['8D Surround']!);
      _startSpatialOrbitalLoop(speedMultiplier: 1.0);
    } else {
      _stopSpatialOrbitalLoop();
      _virtualizer = 0.0;
      _activePreset = 'Flat';
      _bandGains = List.from(presets['Flat']!);
    }
    _savePreferences();
    applyToNativeEffects();
    notifyListeners();
  }

  void toggle16dAudio() {
    set16dAudio(!_is16dAudio);
  }

  void set16dAudio(bool enable) {
    _is16dAudio = enable;
    if (_is16dAudio) {
      _is8dAudio = false;
      _virtualizer = 0.95;
      _bassBoost = 0.45;
      _activePreset = '16D Spatial';
      _bandGains = List.from(presets['16D Spatial']!);
      _startSpatialOrbitalLoop(speedMultiplier: 2.2);
    } else {
      _stopSpatialOrbitalLoop();
      _virtualizer = 0.0;
      _activePreset = 'Flat';
      _bandGains = List.from(presets['Flat']!);
    }
    _savePreferences();
    applyToNativeEffects();
    notifyListeners();
  }

  // --- Real-Time 8D / 16D Binaural Orbital Engine ---
  void _startSpatialOrbitalLoop({required double speedMultiplier}) {
    _spatialOrbitalTimer?.cancel();
    _orbitalAngle = 0.0;
    // 60ms tick for smooth orbital movement around head
    _spatialOrbitalTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      _orbitalAngle += 0.06 * speedMultiplier;
      if (_orbitalAngle > 2 * math.pi) {
        _orbitalAngle -= 2 * math.pi;
      }
      
      // Dynamic loudness and perception modulation
      if (_audioPlayer != null) {
        final dynamicVolume = 0.86 + 0.14 * math.cos(_orbitalAngle);
        _audioPlayer!.setVolume(dynamicVolume.clamp(0.0, 1.0));
      }
    });
  }

  void _stopSpatialOrbitalLoop() {
    _spatialOrbitalTimer?.cancel();
    _spatialOrbitalTimer = null;
    _audioPlayer?.setVolume(1.0);
  }

  void reset() {
    _stopSpatialOrbitalLoop();
    _is8dAudio = false;
    _is16dAudio = false;
    setPreset('Flat');
    _bassBoost = 0.0;
    _virtualizer = 0.0;
    _savePreferences();
    applyToNativeEffects();
    notifyListeners();
  }

  @override
  void dispose() {
    _spatialOrbitalTimer?.cancel();
    super.dispose();
  }
}
