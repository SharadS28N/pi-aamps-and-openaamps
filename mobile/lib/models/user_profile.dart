class AcousticTasteVector {
  final double energy;
  final double valence;
  final double danceability;
  final double acousticness;
  final double tempo;

  const AcousticTasteVector({
    this.energy = 0.65,
    this.valence = 0.60,
    this.danceability = 0.62,
    this.acousticness = 0.35,
    this.tempo = 118.0,
  });

  factory AcousticTasteVector.fromJson(Map<String, dynamic> json) {
    return AcousticTasteVector(
      energy: (json['energy'] as num?)?.toDouble() ?? 0.65,
      valence: (json['valence'] as num?)?.toDouble() ?? 0.60,
      danceability: (json['danceability'] as num?)?.toDouble() ?? 0.62,
      acousticness: (json['acousticness'] as num?)?.toDouble() ?? 0.35,
      tempo: (json['tempo'] as num?)?.toDouble() ?? 118.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'energy': energy,
      'valence': valence,
      'danceability': danceability,
      'acousticness': acousticness,
      'tempo': tempo,
    };
  }

  AcousticTasteVector shiftTowards({
    required double targetEnergy,
    required double targetValence,
    required double targetDanceability,
    required double targetAcousticness,
    required double targetTempo,
    required double learningRate, // e.g. 0.05 for normal play, 0.12 for like, -0.08 for skip
  }) {
    double clamp01(double v) => v.clamp(0.05, 0.98);
    return AcousticTasteVector(
      energy: clamp01(energy + (targetEnergy - energy) * learningRate),
      valence: clamp01(valence + (targetValence - valence) * learningRate),
      danceability: clamp01(danceability + (targetDanceability - danceability) * learningRate),
      acousticness: clamp01(acousticness + (targetAcousticness - acousticness) * learningRate),
      tempo: (tempo + (targetTempo - tempo) * (learningRate * 0.5)).clamp(60.0, 190.0),
    );
  }

  double similarityScore({
    required double trackEnergy,
    required double trackValence,
    required double trackDanceability,
    required double trackAcousticness,
    required double trackTempo,
  }) {
    final dEnergy = (energy - trackEnergy).abs();
    final dValence = (valence - trackValence).abs();
    final dDance = (danceability - trackDanceability).abs();
    final dAcoustic = (acousticness - trackAcousticness).abs();
    final dTempo = ((tempo - trackTempo).abs() / 100.0).clamp(0.0, 1.0);

    // Weighted distance (0 is exact match, higher is less similar)
    final distance = (dEnergy * 0.30) +
        (dValence * 0.25) +
        (dDance * 0.15) +
        (dAcoustic * 0.20) +
        (dTempo * 0.10);

    return (1.0 - distance).clamp(0.0, 1.0);
  }
}

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final List<String> preferredGenres;
  final List<String> topArtists;
  final int totalListeningTimeSeconds;
  final int totalTracksPlayed;
  final AcousticTasteVector tasteVector;
  final DateTime createdAt;
  final Map<String, dynamic> linkedServices;
  final bool isGuest;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl = '',
    this.preferredGenres = const ['Rock', 'Pop', 'Indie', 'Lo-Fi'],
    this.topArtists = const ['Coldplay', 'Queen', 'The Weeknd'],
    this.totalListeningTimeSeconds = 0,
    this.totalTracksPlayed = 0,
    this.tasteVector = const AcousticTasteVector(),
    DateTime? createdAt,
    this.linkedServices = const {'youtube_music': true, 'spotify': false},
    this.isGuest = false,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isYouTubeMusicSynced => linkedServices['youtube_music'] == true;
  bool get isSpotifySynced => linkedServices['spotify'] == true;

  factory UserProfile.defaultProfile({String uid = 'guest_user', String name = 'Music Listener'}) {
    return UserProfile(
      uid: uid,
      email: 'user@openaamps.ai',
      displayName: name,
      photoUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=1DB954&color=fff&bold=true',
      preferredGenres: const ['Alternative Rock', 'Synthwave', 'Lo-Fi', 'Classic Rock'],
      topArtists: const ['Coldplay', 'Queen', 'Dua Lipa', 'Linkin Park'],
      totalListeningTimeSeconds: 4320,
      totalTracksPlayed: 18,
      tasteVector: const AcousticTasteVector(
        energy: 0.75,
        valence: 0.68,
        danceability: 0.65,
        acousticness: 0.28,
        tempo: 122.0,
      ),
      linkedServices: const {'youtube_music': true, 'spotify': false},
      isGuest: true,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] ?? 'guest',
      email: json['email'] ?? '',
      displayName: json['display_name'] ?? 'Music Enthusiast',
      photoUrl: json['photo_url'] ?? '',
      preferredGenres: (json['preferred_genres'] as List?)?.cast<String>() ?? ['Rock', 'Pop'],
      topArtists: (json['top_artists'] as List?)?.cast<String>() ?? ['Coldplay'],
      totalListeningTimeSeconds: json['total_listening_time_seconds'] ?? 0,
      totalTracksPlayed: json['total_tracks_played'] ?? 0,
      tasteVector: json['taste_vector'] != null
          ? AcousticTasteVector.fromJson(json['taste_vector'])
          : const AcousticTasteVector(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      linkedServices: json['linked_services'] != null
          ? Map<String, dynamic>.from(json['linked_services'])
          : const {'youtube_music': true, 'spotify': false},
      isGuest: json['is_guest'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'preferred_genres': preferredGenres,
      'top_artists': topArtists,
      'total_listening_time_seconds': totalListeningTimeSeconds,
      'total_tracks_played': totalTracksPlayed,
      'taste_vector': tasteVector.toJson(),
      'created_at': createdAt.toIso8601String(),
      'linked_services': linkedServices,
      'is_guest': isGuest,
    };
  }

  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    List<String>? preferredGenres,
    List<String>? topArtists,
    int? totalListeningTimeSeconds,
    int? totalTracksPlayed,
    AcousticTasteVector? tasteVector,
    DateTime? createdAt,
    Map<String, dynamic>? linkedServices,
    bool? isGuest,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      preferredGenres: preferredGenres ?? this.preferredGenres,
      topArtists: topArtists ?? this.topArtists,
      totalListeningTimeSeconds: totalListeningTimeSeconds ?? this.totalListeningTimeSeconds,
      totalTracksPlayed: totalTracksPlayed ?? this.totalTracksPlayed,
      tasteVector: tasteVector ?? this.tasteVector,
      createdAt: createdAt ?? this.createdAt,
      linkedServices: linkedServices ?? this.linkedServices,
      isGuest: isGuest ?? this.isGuest,
    );
  }
}
