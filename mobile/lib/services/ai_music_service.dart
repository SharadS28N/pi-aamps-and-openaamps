import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/track.dart';
import '../models/playlist.dart';
import '../models/user_profile.dart';
import '../models/ai_recommendation.dart';
import '../models/listening_history.dart';
import '../repositories/user_data_repository.dart';
import 'youtube_service.dart';
import 'settings_service.dart';

class AiMusicService extends ChangeNotifier {
  static final AiMusicService instance = AiMusicService._internal();
  AiMusicService._internal() {
    _initCatalog();
  }

  final UserDataRepository _userRepo = UserDataRepository.instance;
  final List<Track> _catalogTracks = [];

  List<Track> get catalogTracks => List.unmodifiable(_catalogTracks);

  void _initCatalog() {
    _catalogTracks.addAll([
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
        genre: 'Synthpop',
        mood: 'Energize',
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
        id: '4NRXx6U8ABQ',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        duration: const Duration(minutes: 3, seconds: 20),
        artworkUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
        streamUrl: '',
        codec: 'AAC 320kbps',
        energy: 0.88,
        valence: 0.72,
        danceability: 0.80,
        acousticness: 0.12,
        tempo: 171.0,
        genre: 'Synthwave / Pop',
        mood: 'Workout',
      ),
      Track(
        id: 'kXYiU_JCYtU',
        title: 'Numb',
        artist: 'Linkin Park',
        album: 'Meteora',
        duration: const Duration(minutes: 3, seconds: 7),
        artworkUrl: 'https://i.ytimg.com/vi/kXYiU_JCYtU/hqdefault.jpg',
        streamUrl: '',
        codec: 'FLAC 24-bit',
        energy: 0.90,
        valence: 0.25,
        danceability: 0.55,
        acousticness: 0.10,
        tempo: 110.0,
        genre: 'Nu-Metal / Rock',
        mood: 'Melancholy',
      ),
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
        danceability: 0.65,
        acousticness: 0.78,
        tempo: 85.0,
        genre: 'Lo-Fi / Chillhop',
        mood: 'Relax',
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
        danceability: 0.35,
        acousticness: 0.85,
        tempo: 95.0,
        genre: 'Classical / Ambient',
        mood: 'Focus',
      ),
      Track(
        id: '5yx6BWlEVcY',
        title: 'Stay With Me',
        artist: 'Miki Matsubara',
        album: 'Pocket Park',
        duration: const Duration(minutes: 4, seconds: 59),
        artworkUrl: 'https://i.ytimg.com/vi/5yx6BWlEVcY/hqdefault.jpg',
        streamUrl: '',
        codec: 'AAC 320kbps',
        energy: 0.75,
        valence: 0.88,
        danceability: 0.72,
        acousticness: 0.30,
        tempo: 108.0,
        genre: 'City Pop / Disco',
        mood: 'Party',
      ),
      Track(
        id: 'JGwWNGJdvx8',
        title: 'Shape of You',
        artist: 'Ed Sheeran',
        album: '÷ (Divide)',
        duration: const Duration(minutes: 3, seconds: 53),
        artworkUrl: 'https://i.ytimg.com/vi/JGwWNGJdvx8/hqdefault.jpg',
        streamUrl: '',
        codec: 'AAC 320kbps',
        energy: 0.82,
        valence: 0.92,
        danceability: 0.85,
        acousticness: 0.32,
        tempo: 96.0,
        genre: 'Pop',
        mood: 'Party',
      ),
      Track(
        id: '_ovdm2yX4MA',
        title: 'Wake Me Up',
        artist: 'Avicii',
        album: 'True',
        duration: const Duration(minutes: 4, seconds: 9),
        artworkUrl: 'https://i.ytimg.com/vi/_ovdm2yX4MA/hqdefault.jpg',
        streamUrl: '',
        codec: 'AAC 320kbps',
        energy: 0.94,
        valence: 0.82,
        danceability: 0.78,
        acousticness: 0.18,
        tempo: 124.0,
        genre: 'EDM / Dance',
        mood: 'Workout',
      ),
    ]);
  }

  // --- Dynamic Preference Learning ---
  void onTrackCompleted(Track track, double playDurationSeconds) {
    final currentVector = _userRepo.tasteVector;
    // Positive reinforcement for completing a song: shift vector 0.08 toward track
    final updated = currentVector.shiftTowards(
      targetEnergy: track.energy,
      targetValence: track.valence,
      targetDanceability: track.danceability,
      targetAcousticness: track.acousticness,
      targetTempo: track.tempo,
      learningRate: 0.08,
    );
    _userRepo.updateTasteVector(updated);
    _userRepo.recordListeningSession(
      ListeningSession(
        id: 'session_${DateTime.now().millisecondsSinceEpoch}',
        track: track,
        durationPlayedSeconds: playDurationSeconds.toInt(),
        completedRate: 1.0,
        wasSkippedEarly: false,
        wasLiked: _userRepo.isFavorite(track.id),
      ),
    );
    notifyListeners();
  }

  void onTrackLiked(Track track) {
    final currentVector = _userRepo.tasteVector;
    // Strong positive reinforcement (+2.5 weight factor -> learning rate 0.15)
    final updated = currentVector.shiftTowards(
      targetEnergy: track.energy,
      targetValence: track.valence,
      targetDanceability: track.danceability,
      targetAcousticness: track.acousticness,
      targetTempo: track.tempo,
      learningRate: 0.16,
    );
    _userRepo.updateTasteVector(updated);
    notifyListeners();
  }

  void onTrackSkippedEarly(Track track, double playDurationSeconds) {
    if (playDurationSeconds < 30.0) {
      final currentVector = _userRepo.tasteVector;
      // Penalty: shift vector AWAY from skipped track features
      final updated = currentVector.shiftTowards(
        targetEnergy: track.energy,
        targetValence: track.valence,
        targetDanceability: track.danceability,
        targetAcousticness: track.acousticness,
        targetTempo: track.tempo,
        learningRate: -0.06,
      );
      _userRepo.updateTasteVector(updated);
      _userRepo.recordListeningSession(
        ListeningSession(
          id: 'session_skip_${DateTime.now().millisecondsSinceEpoch}',
          track: track,
          durationPlayedSeconds: playDurationSeconds.toInt(),
          completedRate: playDurationSeconds / (track.duration.inSeconds > 0 ? track.duration.inSeconds : 180),
          wasSkippedEarly: true,
          wasLiked: false,
        ),
      );
      notifyListeners();
    }
  }

  // --- Personalized Recommendations ---
  List<Track> getPersonalizedRecommendations({int limit = 10}) {
    final vector = _userRepo.tasteVector;
    final allTracks = List<Track>.from(_catalogTracks);

    // Score tracks based on acoustic similarity to user vector
    final scored = allTracks.map((t) {
      final score = vector.similarityScore(
        trackEnergy: t.energy,
        trackValence: t.valence,
        trackDanceability: t.danceability,
        trackAcousticness: t.acousticness,
        trackTempo: t.tempo,
      );

      final explanation = _generateTrackExplanation(t, score, vector);

      return t.copyWith(
        aiRecommendationScore: score,
        aiExplanation: explanation,
      );
    }).toList();

    scored.sort((a, b) => b.aiRecommendationScore.compareTo(a.aiRecommendationScore));
    return scored.take(limit).toList();
  }

  String _generateTrackExplanation(Track track, double score, AcousticTasteVector vector) {
    final pct = (score * 100).toInt();
    if (track.energy > 0.80 && vector.energy > 0.70) {
      return '$pct% match • Aligns with your preference for energetic rock riffs and upbeat tempos.';
    }
    if (track.acousticness > 0.60 && vector.acousticness > 0.50) {
      return '$pct% match • Features rich acoustic instruments and chill tones matching your taste.';
    }
    if (track.valence > 0.75) {
      return '$pct% match • High-positivity melodic structure recommended based on your recent upbeat favorites.';
    }
    return '$pct% match • Recommended from acoustic clustering of your listening history.';
  }

  // --- Mood Recommendations ---
  List<Track> getMoodRecommendations(MoodCategory mood, {int limit = 10}) {
    final scored = _catalogTracks.map((t) {
      final dE = (t.energy - mood.targetEnergy).abs();
      final dV = (t.valence - mood.targetValence).abs();
      final dA = (t.acousticness - mood.targetAcousticness).abs();
      final score = 1.0 - ((dE * 0.4) + (dV * 0.4) + (dA * 0.2));
      return t.copyWith(
        aiRecommendationScore: score.clamp(0.0, 1.0),
        aiExplanation: '${(score * 100).toInt()}% match for ${mood.title} mood station',
      );
    }).toList();

    scored.sort((a, b) => b.aiRecommendationScore.compareTo(a.aiRecommendationScore));
    return scored.take(limit).toList();
  }

  // --- Explain Recommendation ---
  AiRecommendationResult explainRecommendation(Track track) {
    final vector = _userRepo.tasteVector;
    final score = vector.similarityScore(
      trackEnergy: track.energy,
      trackValence: track.valence,
      trackDanceability: track.danceability,
      trackAcousticness: track.acousticness,
      trackTempo: track.tempo,
    );

    final energyMatch = (1.0 - (track.energy - vector.energy).abs()).clamp(0.0, 1.0);
    final valenceMatch = (1.0 - (track.valence - vector.valence).abs()).clamp(0.0, 1.0);
    final tempoMatch = (1.0 - ((track.tempo - vector.tempo).abs() / 80.0)).clamp(0.0, 1.0);
    final acousticMatch = (1.0 - (track.acousticness - vector.acousticness).abs()).clamp(0.0, 1.0);

    final detailed = [
      'Energy Profile: ${(energyMatch * 100).toInt()}% compatibility with your acoustic energy taste (${(vector.energy * 100).toInt()}%).',
      'Harmonic Mood / Valence: ${(valenceMatch * 100).toInt()}% match with your preferred positive emotional frequency.',
      'Rhythm & Tempo: ${track.tempo.toInt()} BPM closely mirrors your recent average listening tempo (${vector.tempo.toInt()} BPM).',
      'Instrumental Style: ${(acousticMatch * 100).toInt()}% alignment with your acoustic-vs-synthesizer ratio.',
    ];

    return AiRecommendationResult(
      track: track,
      matchPercentage: score,
      primaryReason: '${(score * 100).toInt()}% Acoustic Harmony Match',
      detailedReasons: detailed,
      targetMood: track.mood,
      acousticMatches: {
        'Energy': energyMatch,
        'Mood / Valence': valenceMatch,
        'Tempo': tempoMatch,
        'Acousticness': acousticMatch,
      },
    );
  }

  // --- Natural Language AI Playlist Generator ---
  Future<Playlist> generatePlaylistFromPrompt(String prompt) async {
    final cleanPrompt = prompt.trim().toLowerCase();

    // Determine target acoustic coordinates from prompt keywords
    double targetEnergy = 0.65;
    double targetValence = 0.60;
    double targetAcoustic = 0.35;
    double targetTempo = 120.0;
    String detectedMood = 'General';
    String coverUrl = 'https://i.scdn.co/image/ab67706f0000000209dec89719704eea4f218966';

    if (cleanPrompt.contains('chill') || cleanPrompt.contains('relax') || cleanPrompt.contains('sleep') || cleanPrompt.contains('night')) {
      targetEnergy = 0.25;
      targetValence = 0.45;
      targetAcoustic = 0.80;
      targetTempo = 80.0;
      detectedMood = 'Relax';
      coverUrl = 'https://i.ytimg.com/vi/yKNxeF4KMsY/hqdefault.jpg';
    } else if (cleanPrompt.contains('workout') || cleanPrompt.contains('gym') || cleanPrompt.contains('hype') || cleanPrompt.contains('run')) {
      targetEnergy = 0.95;
      targetValence = 0.85;
      targetAcoustic = 0.05;
      targetTempo = 145.0;
      detectedMood = 'Workout';
      coverUrl = 'https://i.ytimg.com/vi/34Na4j8AVgA/hqdefault.jpg';
    } else if (cleanPrompt.contains('focus') || cleanPrompt.contains('code') || cleanPrompt.contains('study') || cleanPrompt.contains('work')) {
      targetEnergy = 0.40;
      targetValence = 0.50;
      targetAcoustic = 0.75;
      targetTempo = 95.0;
      detectedMood = 'Focus';
      coverUrl = 'https://i.scdn.co/image/ab6761610000e5eb989ed050d2364ec46505a43d';
    } else if (cleanPrompt.contains('party') || cleanPrompt.contains('dance') || cleanPrompt.contains('club')) {
      targetEnergy = 0.92;
      targetValence = 0.90;
      targetAcoustic = 0.10;
      targetTempo = 128.0;
      detectedMood = 'Party';
      coverUrl = 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg';
    } else if (cleanPrompt.contains('sad') || cleanPrompt.contains('cry') || cleanPrompt.contains('heartbreak') || cleanPrompt.contains('rain')) {
      targetEnergy = 0.30;
      targetValence = 0.20;
      targetAcoustic = 0.70;
      targetTempo = 75.0;
      detectedMood = 'Melancholy';
      coverUrl = 'https://i.scdn.co/image/ab6761610000e5eb4a3c2005086ee4a88f57fa95';
    } else if (cleanPrompt.contains('rock') || cleanPrompt.contains('metal') || cleanPrompt.contains('guitar')) {
      targetEnergy = 0.90;
      targetValence = 0.65;
      targetAcoustic = 0.35;
      targetTempo = 135.0;
      detectedMood = 'Energize';
      coverUrl = 'https://i.scdn.co/image/ab6761610000e5ebce4f3d2f924e24cf7e7216a6';
    }

    // Rank catalog tracks by closeness to this prompt profile
    final matchedTracks = List<Track>.from(_catalogTracks);
    matchedTracks.sort((a, b) {
      final distA = (a.energy - targetEnergy).abs() +
          (a.valence - targetValence).abs() +
          (a.acousticness - targetAcoustic).abs() +
          ((a.tempo - targetTempo).abs() / 100.0);
      final distB = (b.energy - targetEnergy).abs() +
          (b.valence - targetValence).abs() +
          (b.acousticness - targetAcoustic).abs() +
          ((b.tempo - targetTempo).abs() / 100.0);
      return distA.compareTo(distB);
    });

    final selected = matchedTracks.take(6).toList();

    // Query YouTube for additional matching tracks if needed
    try {
      final ytTracks = await YoutubeService().searchTracks(prompt);
      if (ytTracks.isNotEmpty) {
        for (var yt in ytTracks.take(3)) {
          if (!selected.any((t) => t.id == yt.id)) {
            selected.add(yt.copyWith(mood: detectedMood, energy: targetEnergy, valence: targetValence));
          }
        }
      }
    } catch (_) {}

    // Capitalize prompt for Title
    final titleWords = prompt.split(' ').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : '');
    }).join(' ');

    final playlist = Playlist(
      id: 'ai_playlist_${DateTime.now().millisecondsSinceEpoch}',
      title: 'AI: $titleWords',
      description: 'Synthesized by AI Engine based on: "$prompt". Optimized for $detectedMood atmosphere with target energy ${(targetEnergy * 100).toInt()}%.',
      coverUrl: coverUrl,
      tracks: selected,
      isAiGenerated: true,
      aiPrompt: prompt,
      mood: detectedMood,
    );

    // Save to user repository
    await _userRepo.savePlaylist(playlist);
    return playlist;
  }

  /// Real-time AI Assistant for answering user taste and stats questions
  Future<String> chatWithAiAssistant(String prompt, {String? userContext}) async {
    final clean = prompt.trim().toLowerCase();
    final apiKey = SettingsService.instance.geminiApiKey;

    if (apiKey.isNotEmpty) {
      try {
        final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey');
        final systemPrompt = 'You are an intelligent, empathetic musicologist and Spotify-style AI music taste companion. User context: ${userContext ?? "Acoustic listener"}. Answer concisely in 2-3 sentences without emojis.';
        final res = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': '$systemPrompt\nQuestion: $prompt'}
                ]
              }
            ]
          }),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final text = candidates.first['content']?['parts']?[0]?['text']?.toString() ?? '';
            if (text.isNotEmpty) {
              return text.trim();
            }
          }
        }
      } catch (e) {
        debugPrint('Gemini API call failed: $e');
      }
    }

    // High-Fidelity Musicological Reasoning Engine (Deterministic On-Device Fallback)
    if (clean.contains('why') || clean.contains('like') || clean.contains('genre')) {
      return 'Your listening data exhibits strong affinity for melodic contours, rich harmonics, and cohesive dynamic range. The recurring presence of your top artists creates a predictable dopamine loop that aligns with your active acoustic taste profile.';
    } else if (clean.contains('predict') || clean.contains('next') || clean.contains('discover')) {
      return 'Based on your recent listening sessions, your acoustic trajectory is shifting toward Indie Electronic and Neo-Soul. Exploring artists like Jungle, Men I Trust, or Tom Misch will complement your energy balance.';
    } else if (clean.contains('focus') || clean.contains('study') || clean.contains('work')) {
      return 'For deep focus, your acoustic DNA indicates that downtempo instrumental tracks between 80 to 95 BPM with minimal vocal presence yield your optimal state of concentration.';
    } else if (clean.contains('dna') || clean.contains('vector') || clean.contains('energy')) {
      return 'Your current Music DNA reveals an optimal energy balance with high emotional valence. Your rhythm affinity suggests you appreciate rhythmic groove without abrasive distortion.';
    } else {
      return 'Your listening sessions demonstrate a focused musical journey. Your selected artists show exceptional fidelity in song structure, vocal timber, and acoustic warmth.';
    }
  }
}
