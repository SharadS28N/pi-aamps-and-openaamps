import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PlayerStyle { modern, classic, vinyl, minimal, glassmorphism }
enum BackgroundStyle { pureBlack, darkGradient, albumArtBlur, dynamicColor, deepNebula, cyberNoir, velvetNight, customWallpaper }
enum EqualizerPreset { flat, bassBoost, vocalBoost, trebleBoost, hifi }
enum AccentVibe { monochromeWhite, electricRed, spotifyGreen, cyberCyan, amberGold }

class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService();

  static const String defaultCustomWallpaper = 'https://i.redd.it/5xx3q4lfjqb71.jpg';

  static const List<Map<String, String>> defaultWallpapers = [
    {
      'id': 'redditAnime',
      'name': 'Anime Cyber Aesthetic (Reddit)',
      'url': defaultCustomWallpaper,
    },
    {
      'id': 'deepNebula',
      'name': 'Deep Cosmic Nebula',
      'url': 'https://images.pexels.com/photos/956981/milky-way-starry-sky-night-sky-star-956981.jpeg?auto=compress&cs=tinysrgb&w=1080',
    },
    {
      'id': 'cyberNoir',
      'name': 'Cyber Noir Studio',
      'url': 'https://images.pexels.com/photos/164745/pexels-photo-164745.jpeg?auto=compress&cs=tinysrgb&w=1080',
    },
    {
      'id': 'velvetNight',
      'name': 'Velvet Aurora Midnight',
      'url': 'https://images.pexels.com/photos/1933239/pexels-photo-1933239.jpeg?auto=compress&cs=tinysrgb&w=1080',
    },
    {
      'id': 'minimalAcoustic',
      'name': 'Dark Vinyl Studio',
      'url': 'https://images.pexels.com/photos/1389429/pexels-photo-1389429.jpeg?auto=compress&cs=tinysrgb&w=1080',
    },
    {
      'id': 'astralWaves',
      'name': 'Astral Soundwaves',
      'url': 'https://images.pexels.com/photos/1105666/pexels-photo-1105666.jpeg?auto=compress&cs=tinysrgb&w=1080',
    },
  ];

  PlayerStyle _playerStyle = PlayerStyle.modern;
  BackgroundStyle _backgroundStyle = BackgroundStyle.customWallpaper;
  String _customWallpaperUrl = defaultCustomWallpaper;
  EqualizerPreset _equalizerPreset = EqualizerPreset.flat;
  AccentVibe _accentVibe = AccentVibe.spotifyGreen;
  bool _showWallpaperOnHome = true;
  String _geminiApiKey = '';

  double _playbackSpeed = 1.0;
  double _pitch = 1.0;
  double _crossfadeDuration = 3.0;
  bool _loudnessNormalization = true;
  bool _autoDownloadFavorites = true;
  bool _autoCacheOnPlay = false;

  PlayerStyle get playerStyle => _playerStyle;
  BackgroundStyle get backgroundStyle => _backgroundStyle;
  String get customWallpaperUrl => _customWallpaperUrl;
  EqualizerPreset get equalizerPreset => _equalizerPreset;
  AccentVibe get accentVibe => _accentVibe;
  bool get showWallpaperOnHome => _showWallpaperOnHome;
  String get geminiApiKey => _geminiApiKey;
  bool get autoDownloadFavorites => _autoDownloadFavorites;
  bool get autoCacheOnPlay => _autoCacheOnPlay;

  Color get accentColor {
    switch (_accentVibe) {
      case AccentVibe.monochromeWhite:
        return Colors.white;
      case AccentVibe.electricRed:
        return const Color(0xFFEF4444);
      case AccentVibe.spotifyGreen:
        return const Color(0xFF1DB954);
      case AccentVibe.cyberCyan:
        return const Color(0xFF00F2FE);
      case AccentVibe.amberGold:
        return const Color(0xFFFFB800);
    }
  }

  double get playbackSpeed => _playbackSpeed;
  double get pitch => _pitch;
  double get crossfadeDuration => _crossfadeDuration;
  bool get loudnessNormalization => _loudnessNormalization;

  SettingsService() {
    _loadSettings();
  }

  static String sanitizeWallpaperUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.isEmpty) return '';

    if (url.contains('reddit.com/media')) {
      try {
        final uri = Uri.parse(url);
        final inner = uri.queryParameters['url'];
        if (inner != null && inner.isNotEmpty) {
          url = inner;
        }
      } catch (_) {}
    }

    final regExp = RegExp(
      r'(?:-v0-|\/)([a-zA-Z0-9]{8,32})\.(?:jpg|png|webp|jpeg)',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    if (match != null && (url.contains('redd.it') || url.contains('reddit'))) {
      final imgId = match.group(1);
      return 'https://i.redd.it/$imgId.jpg';
    }

    return url;
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pIndex = prefs.getInt('pref_player_style') ?? PlayerStyle.modern.index;
      if (pIndex >= 0 && pIndex < PlayerStyle.values.length) {
        _playerStyle = PlayerStyle.values[pIndex];
      }

      final bIndex = prefs.getInt('pref_bg_style') ?? BackgroundStyle.customWallpaper.index;
      if (bIndex >= 0 && bIndex < BackgroundStyle.values.length) {
        _backgroundStyle = BackgroundStyle.values[bIndex];
      }

      final savedUrl = prefs.getString('pref_custom_wallpaper');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _customWallpaperUrl = sanitizeWallpaperUrl(savedUrl);
      } else {
        _customWallpaperUrl = defaultCustomWallpaper;
      }

      final vIndex = prefs.getInt('pref_accent_vibe') ?? AccentVibe.spotifyGreen.index;
      if (vIndex >= 0 && vIndex < AccentVibe.values.length) {
        _accentVibe = AccentVibe.values[vIndex];
      }

      _showWallpaperOnHome = prefs.getBool('pref_show_wallpaper_home') ?? true;

      final eIndex = prefs.getInt('pref_eq_preset') ?? 0;
      if (eIndex >= 0 && eIndex < EqualizerPreset.values.length) {
        _equalizerPreset = EqualizerPreset.values[eIndex];
      }

      _playbackSpeed = prefs.getDouble('pref_playback_speed') ?? 1.0;
      _pitch = prefs.getDouble('pref_pitch') ?? 1.0;
      _crossfadeDuration = prefs.getDouble('pref_crossfade') ?? 3.0;
      _loudnessNormalization = prefs.getBool('pref_loudness_norm') ?? true;
      _autoDownloadFavorites = prefs.getBool('pref_auto_download_favs') ?? true;
      _autoCacheOnPlay = prefs.getBool('pref_auto_cache_play') ?? false;
      _geminiApiKey = prefs.getString('pref_gemini_api_key') ?? '';

      notifyListeners();
    } catch (_) {}
  }

  Future<void> setGeminiApiKey(String key) async {
    _geminiApiKey = key.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_gemini_api_key', _geminiApiKey);
  }

  Future<void> setAccentVibe(AccentVibe vibe) async {
    _accentVibe = vibe;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pref_accent_vibe', vibe.index);
  }

  Future<void> setShowWallpaperOnHome(bool value) async {
    _showWallpaperOnHome = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_show_wallpaper_home', value);
  }

  Future<void> setPlayerStyle(PlayerStyle style) async {
    _playerStyle = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pref_player_style', style.index);
  }

  Future<void> setBackgroundStyle(BackgroundStyle style) async {
    _backgroundStyle = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pref_bg_style', style.index);
  }

  Future<void> setCustomWallpaperUrl(String rawUrl) async {
    final cleanUrl = sanitizeWallpaperUrl(rawUrl);
    _customWallpaperUrl = cleanUrl.isNotEmpty ? cleanUrl : defaultCustomWallpaper;
    _backgroundStyle = BackgroundStyle.customWallpaper;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_custom_wallpaper', _customWallpaperUrl);
    await prefs.setInt('pref_bg_style', BackgroundStyle.customWallpaper.index);
  }

  Future<void> setEqualizerPreset(EqualizerPreset preset) async {
    _equalizerPreset = preset;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pref_eq_preset', preset.index);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pref_playback_speed', speed);
  }

  Future<void> setPitch(double pitchVal) async {
    _pitch = pitchVal;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pref_pitch', pitchVal);
  }

  Future<void> setCrossfade(double seconds) async {
    _crossfadeDuration = seconds;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pref_crossfade', seconds);
  }

  Future<void> setLoudnessNormalization(bool enabled) async {
    _loudnessNormalization = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_loudness_norm', enabled);
  }

  Future<void> setAutoDownloadFavorites(bool value) async {
    _autoDownloadFavorites = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_auto_download_favs', value);
  }

  Future<void> setAutoCacheOnPlay(bool value) async {
    _autoCacheOnPlay = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_auto_cache_play', value);
  }
}
