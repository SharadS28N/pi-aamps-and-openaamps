import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';

class LocalAudioService extends ChangeNotifier {
  static final LocalAudioService instance = LocalAudioService._internal();
  factory LocalAudioService() => instance;

  LocalAudioService._internal() {
    _loadPreferencesAndTracks();
  }

  bool _isScanning = false;
  final List<Track> _allLocalTracks = [];
  final Set<String> _excludedFolders = {};
  final Map<String, Map<String, String>> _tagOverrides = {};

  bool get isScanning => _isScanning;
  Set<String> get excludedFolders => Set.unmodifiable(_excludedFolders);

  List<Track> get localTracks {
    return _allLocalTracks.where((track) {
      if (track.localPath == null) return true;
      final parentFolder = _getParentDirectory(track.localPath!);
      return !_excludedFolders.contains(parentFolder);
    }).toList();
  }

  Map<String, List<Track>> get folderTracks {
    final Map<String, List<Track>> map = {};
    for (var track in localTracks) {
      final folder = track.localPath != null
          ? _getParentDirectory(track.localPath!)
          : 'Storage / Music';
      map.putIfAbsent(folder, () => []).add(track);
    }
    return map;
  }

  List<String> get folders => folderTracks.keys.toList();

  String _getParentDirectory(String filePath) {
    try {
      final separator = filePath.contains('/') ? '/' : '\\';
      final parts = filePath.split(separator);
      if (parts.length > 1) {
        parts.removeLast();
        return parts.join(separator);
      }
    } catch (_) {}
    return 'Music';
  }

  Future<void> _loadPreferencesAndTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final excluded = prefs.getStringList('excluded_folders') ?? [];
      _excludedFolders.addAll(excluded);

      final overridesStr = prefs.getString('track_tag_overrides');
      if (overridesStr != null) {
        final decoded = jsonDecode(overridesStr) as Map<String, dynamic>;
        decoded.forEach((key, val) {
          if (val is Map<String, dynamic>) {
            _tagOverrides[key] = val.map((k, v) => MapEntry(k, v.toString()));
          }
        });
      }
    } catch (_) {}

    _loadSampleLocalTracks();
  }

  void _loadSampleLocalTracks() {
    _allLocalTracks.clear();
    final samples = [
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
        id: 'k4V3Mo61fJM',
        title: 'Fix You',
        artist: 'Coldplay',
        album: 'X&Y',
        duration: const Duration(minutes: 4, seconds: 55),
        artworkUrl: 'https://i.ytimg.com/vi/k4V3Mo61fJM/hqdefault.jpg',
        streamUrl: '',
        codec: 'AAC 256kbps',
      ),
      Track(
        id: 'hT_nvWreIhg',
        title: 'Counting Stars',
        artist: 'OneRepublic',
        album: 'Native',
        duration: const Duration(minutes: 4, seconds: 17),
        artworkUrl: 'https://i.ytimg.com/vi/hT_nvWreIhg/hqdefault.jpg',
        streamUrl: '',
        codec: 'FLAC 24-bit',
      ),
      Track(
        id: 'fJ9rUzIMcZQ',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        album: 'A Night at the Opera',
        duration: const Duration(minutes: 5, seconds: 55),
        artworkUrl: 'https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
        streamUrl: '',
        codec: 'ALAC 96kHz',
      ),
    ];

    for (var track in samples) {
      _allLocalTracks.add(_applyTagOverrides(track));
    }
    notifyListeners();
  }

  Track _applyTagOverrides(Track track) {
    if (_tagOverrides.containsKey(track.id)) {
      final override = _tagOverrides[track.id]!;
      return track.copyWith(
        title: override['title'] ?? track.title,
        artist: override['artist'] ?? track.artist,
        album: override['album'] ?? track.album,
      );
    }
    return track;
  }

  Future<void> updateTrackMetadata(String trackId, {String? title, String? artist, String? album, String? lyrics}) async {
    final current = _tagOverrides[trackId] ?? {};
    if (title != null) current['title'] = title;
    if (artist != null) current['artist'] = artist;
    if (album != null) current['album'] = album;
    if (lyrics != null) current['lyrics'] = lyrics;
    _tagOverrides[trackId] = current;

    // Update in memory track
    final index = _allLocalTracks.indexWhere((t) => t.id == trackId);
    if (index != -1) {
      _allLocalTracks[index] = _applyTagOverrides(_allLocalTracks[index]);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('track_tag_overrides', jsonEncode(_tagOverrides));
    } catch (_) {}

    notifyListeners();
  }

  Future<void> excludeFolder(String folderPath) async {
    _excludedFolders.add(folderPath);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('excluded_folders', _excludedFolders.toList());
    } catch (_) {}
    notifyListeners();
  }

  Future<void> includeFolder(String folderPath) async {
    _excludedFolders.remove(folderPath);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('excluded_folders', _excludedFolders.toList());
    } catch (_) {}
    notifyListeners();
  }

  bool isFolderExcluded(String folderPath) => _excludedFolders.contains(folderPath);

  Future<void> scanDeviceAudio() => scanDeviceMusic();

  Future<void> scanDeviceMusic() async {
    _isScanning = true;
    notifyListeners();

    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null && await extDir.exists()) {
        final List<Track> discovered = [];
        final entities = extDir.listSync(recursive: true);
        for (var entity in entities) {
          if (entity is File) {
            final path = entity.path.toLowerCase();
            if (path.endsWith('.mp3') || path.endsWith('.flac') || path.endsWith('.m4a') || path.endsWith('.wav')) {
              final fileName = entity.path.split(Platform.pathSeparator).last;
              final rawTrack = Track(
                id: 'local_${entity.path.hashCode}',
                title: fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
                artist: 'Device Storage',
                album: 'Local Music',
                duration: const Duration(minutes: 3, seconds: 45),
                artworkUrl: '',
                streamUrl: entity.path,
                localPath: entity.path,
                isLocal: true,
                codec: path.endsWith('.flac') ? 'FLAC' : 'MP3',
              );
              discovered.add(_applyTagOverrides(rawTrack));
            }
          }
        }
        if (discovered.isNotEmpty) {
          _allLocalTracks.addAll(discovered);
        }
      }
    } catch (e) {
      debugPrint('Local scanning error: $e');
    }

    _isScanning = false;
    notifyListeners();
  }
}
