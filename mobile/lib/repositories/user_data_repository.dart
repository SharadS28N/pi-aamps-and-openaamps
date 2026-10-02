import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../models/listening_history.dart';
import '../models/user_profile.dart';
import '../services/firebase_service.dart';

class UserDataRepository extends ChangeNotifier {
  static final UserDataRepository instance = UserDataRepository._internal();
  UserDataRepository._internal() {
    _init();
  }

  static const String _prefFavoritesKey = 'repo_user_favorites';
  static const String _prefPlaylistsKey = 'repo_user_playlists';
  static const String _prefHistoryKey = 'repo_user_history';
  static const String _prefTasteVectorKey = 'repo_user_taste_vector';

  final List<Track> _favorites = [];
  final List<Playlist> _playlists = [];
  final List<ListeningSession> _history = [];
  AcousticTasteVector _tasteVector = const AcousticTasteVector();

  List<Track> get favorites => List.unmodifiable(_favorites);
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  List<ListeningSession> get history => List.unmodifiable(_history);
  AcousticTasteVector get tasteVector => _tasteVector;

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load Favorites
      final favList = prefs.getStringList(_prefFavoritesKey);
      if (favList != null && favList.isNotEmpty) {
        _favorites.clear();
        for (var str in favList) {
          try {
            _favorites.add(Track.fromJson(jsonDecode(str)));
          } catch (_) {}
        }
      } else {
        _seedDefaultFavorites();
      }

      // Load Playlists
      final playList = prefs.getStringList(_prefPlaylistsKey);
      if (playList != null && playList.isNotEmpty) {
        _playlists.clear();
        for (var str in playList) {
          try {
            _playlists.add(Playlist.fromJson(jsonDecode(str)));
          } catch (_) {}
        }
      } else {
        _seedDefaultPlaylists();
      }

      // Load History
      final histList = prefs.getStringList(_prefHistoryKey);
      if (histList != null && histList.isNotEmpty) {
        _history.clear();
        for (var str in histList) {
          try {
            _history.add(ListeningSession.fromJson(jsonDecode(str)));
          } catch (_) {}
        }
      }

      // Load Taste Vector
      final tasteStr = prefs.getString(_prefTasteVectorKey);
      if (tasteStr != null && tasteStr.isNotEmpty) {
        _tasteVector = AcousticTasteVector.fromJson(jsonDecode(tasteStr));
      }

      notifyListeners();
    } catch (e) {
      debugPrint('UserDataRepository init error: $e');
    }
  }

  void _seedDefaultFavorites() {
    _favorites.addAll([
      Track(
        id: '4NRXx6U8ABQ',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        duration: const Duration(minutes: 3, seconds: 20),
        artworkUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
        streamUrl: '',
        codec: 'OPUS 160kbps',
        energy: 0.85,
        valence: 0.70,
        danceability: 0.75,
        acousticness: 0.15,
        tempo: 171.0,
        genre: 'Synthwave / Pop',
        mood: 'Energize',
      ),
      Track(
        id: 'H5v3kku4y6Q',
        title: 'As It Was',
        artist: 'Harry Styles',
        album: "Harry's House",
        duration: const Duration(minutes: 2, seconds: 47),
        artworkUrl: 'https://i.ytimg.com/vi/H5v3kku4y6Q/hqdefault.jpg',
        streamUrl: '',
        codec: 'AAC 320kbps',
        energy: 0.82,
        valence: 0.80,
        danceability: 0.75,
        acousticness: 0.20,
        tempo: 174.0,
        genre: 'Pop / Indie',
        mood: 'Party',
      ),
      Track(
        id: 'fJ9rUzIMcZQ',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        album: 'A Night at the Opera',
        duration: const Duration(minutes: 5, seconds: 55),
        artworkUrl: 'https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
        streamUrl: '',
        codec: 'FLAC 24-bit',
        energy: 0.88,
        valence: 0.65,
        danceability: 0.52,
        acousticness: 0.45,
        tempo: 140.0,
        genre: 'Classic Rock',
        mood: 'Energize',
      ),
    ]);
  }

  void _seedDefaultPlaylists() {
    _playlists.addAll([
      Playlist(
        id: 'playlist_ai_curated_1',
        title: 'Cyberpunk Focus & Flow',
        description: 'AI-generated high-focus electronic soundscapes for programming and deep work.',
        coverUrl: 'https://i.ytimg.com/vi/jfKfPfyJRdk/hqdefault.jpg',
        isAiGenerated: true,
        aiPrompt: 'High focus electronic soundscapes for programming',
        mood: 'Focus',
        tracks: [
          Track(
            id: 'jfKfPfyJRdk',
            title: 'Lofi Hip Hop Beats - Chill Session',
            artist: 'Lofi Girl',
            album: 'Chilled Beats 2026',
            duration: const Duration(minutes: 3, seconds: 45),
            artworkUrl: 'https://i.ytimg.com/vi/jfKfPfyJRdk/hqdefault.jpg',
            streamUrl: '',
            codec: 'AAC 320kbps',
            energy: 0.28,
            valence: 0.55,
            acousticness: 0.78,
            tempo: 85.0,
            mood: 'Focus',
          ),
          Track(
            id: 'pUZa33hSYWg',
            title: 'Experience',
            artist: 'Ludovico Einaudi',
            album: 'In a Time Lapse',
            duration: const Duration(minutes: 5, seconds: 15),
            artworkUrl: 'https://i.ytimg.com/vi/pUZa33hSYWg/hqdefault.jpg',
            streamUrl: '',
            codec: 'FLAC 24-bit',
            energy: 0.42,
            valence: 0.48,
            acousticness: 0.85,
            tempo: 95.0,
            mood: 'Focus',
          ),
        ],
      ),
      Playlist(
        id: 'playlist_ai_curated_2',
        title: 'Morning Acoustic Warmth',
        description: 'AI-curated soothing guitars and optimistic vocals for starting your day.',
        coverUrl: 'https://i.ytimg.com/vi/bCuhuePlP8o/hqdefault.jpg',
        isAiGenerated: true,
        aiPrompt: 'Soothing morning acoustic guitars with uplifting warmth',
        mood: 'Energize',
        tracks: [
          Track(
            id: 'bCuhuePlP8o',
            title: 'Someone You Loved',
            artist: 'Lewis Capaldi',
            album: 'Divinely Uninspired',
            duration: const Duration(minutes: 3, seconds: 2),
            artworkUrl: 'https://i.ytimg.com/vi/bCuhuePlP8o/hqdefault.jpg',
            streamUrl: '',
            codec: 'AAC 320kbps',
            energy: 0.65,
            valence: 0.70,
            acousticness: 0.60,
            tempo: 110.0,
            mood: 'Energize',
          ),
        ],
      ),
    ]);
  }

  // --- Favorite Operations ---
  bool isFavorite(String trackId) {
    return _favorites.any((t) => t.id == trackId);
  }

  Future<bool> toggleFavorite(Track track) async {
    final idx = _favorites.indexWhere((t) => t.id == track.id);
    final isFav = idx != -1;
    if (isFav) {
      _favorites.removeAt(idx);
    } else {
      _favorites.add(track);
    }
    notifyListeners();
    await _saveFavorites();
    return !isFav;
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _favorites.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList(_prefFavoritesKey, list);
      // Cloud backup via Firebase
      FirebaseService.instance.syncFavoritesToFirestore(_favorites.map((t) => t.toJson()).toList());
    } catch (_) {}
  }

  // --- Playlist Operations ---
  Future<void> savePlaylist(Playlist playlist) async {
    final idx = _playlists.indexWhere((p) => p.id == playlist.id);
    if (idx != -1) {
      _playlists[idx] = playlist;
    } else {
      _playlists.insert(0, playlist);
    }
    notifyListeners();
    await _savePlaylists();
    // Cloud backup via Firebase
    FirebaseService.instance.syncPlaylistToFirestore(playlist.toJson());
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final p = _playlists[idx];
      if (!p.tracks.any((t) => t.id == track.id)) {
        final updatedTracks = List<Track>.from(p.tracks)..add(track);
        _playlists[idx] = p.copyWith(tracks: updatedTracks);
        notifyListeners();
        await _savePlaylists();
        FirebaseService.instance.syncPlaylistToFirestore(_playlists[idx].toJson());
      }
    }
  }

  Future<void> _savePlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _playlists.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_prefPlaylistsKey, list);
    } catch (_) {}
  }

  // --- History & Telemetry Operations ---
  Future<void> recordListeningSession(ListeningSession session) async {
    _history.insert(0, session);
    if (_history.length > 100) {
      _history.removeRange(100, _history.length);
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _history.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_prefHistoryKey, list);
      // Cloud event record
      FirebaseService.instance.recordPlayEvent(
        trackId: session.track.id,
        title: session.track.title,
        artist: session.track.artist,
        listenedSeconds: session.durationPlayedSeconds.toDouble(),
      );
    } catch (_) {}
  }

  // --- Acoustic Vector Persistence ---
  Future<void> updateTasteVector(AcousticTasteVector newVector) async {
    _tasteVector = newVector;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefTasteVectorKey, jsonEncode(newVector.toJson()));
    } catch (_) {}
  }

  // --- YouTube Music Synchronisation ---
  Future<void> setSyncedPlaylists(List<Playlist> newPlaylists) async {
    _playlists.removeWhere((p) => p.id.startsWith('yt_'));
    _playlists.insertAll(0, newPlaylists);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> setSyncedFavorites(List<Track> newFavorites) async {
    for (final track in newFavorites) {
      if (!_favorites.any((f) => f.id == track.id)) {
        _favorites.add(track);
      }
    }
    await _saveFavorites();
    notifyListeners();
  }
}
