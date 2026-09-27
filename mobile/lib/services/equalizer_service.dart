import 'package:flutter/foundation.dart';
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
    notifyListeners();
  }

  void setPreset(String presetName) {
    if (presets.containsKey(presetName)) {
      _activePreset = presetName;
      _activeAutoEqId = null;
      _bandGains = List.from(presets[presetName]!);
      _savePreferences();
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
      notifyListeners();
    }
  }

  void setBandGain(int bandIndex, double gain) {
    if (bandIndex >= 0 && bandIndex < 15) {
      _bandGains[bandIndex] = gain.clamp(-12.0, 12.0);
      _activePreset = 'Custom';
      _activeAutoEqId = null;
      _savePreferences();
      notifyListeners();
    }
  }

  void setBassBoost(double value) {
    _bassBoost = value.clamp(0.0, 1.0);
    _savePreferences();
    notifyListeners();
  }

  void setVirtualizer(double value) {
    _virtualizer = value.clamp(0.0, 1.0);
    _savePreferences();
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
    } else {
      _virtualizer = 0.0;
      _activePreset = 'Flat';
      _bandGains = List.from(presets['Flat']!);
    }
    _savePreferences();
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
    } else {
      _virtualizer = 0.0;
      _activePreset = 'Flat';
      _bandGains = List.from(presets['Flat']!);
    }
    _savePreferences();
    notifyListeners();
  }

  void reset() {
    _is8dAudio = false;
    _is16dAudio = false;
    setPreset('Flat');
    _bassBoost = 0.0;
    _virtualizer = 0.0;
    _savePreferences();
    notifyListeners();
  }
}
