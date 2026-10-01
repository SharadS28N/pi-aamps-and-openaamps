import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/track.dart';
import '../models/playlist.dart';

class SpotifyArtist {
  final String id;
  final String name;
  final String imageUrl;
  final List<String> genres;
  final int popularity;
  final int followers;

  const SpotifyArtist({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.genres = const [],
    this.popularity = 0,
    this.followers = 0,
  });

  factory SpotifyArtist.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List<dynamic>?) ?? [];
    String img = '';
    if (images.isNotEmpty) {
      img = images.first['url']?.toString() ?? '';
    }
    final genresList = (json['genres'] as List<dynamic>?)
            ?.map((g) => g.toString())
            .toList() ??
        [];

    final followersData = json['followers'] as Map<String, dynamic>?;
    final followersTotal = (followersData?['total'] as num?)?.toInt() ?? 0;

    return SpotifyArtist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Artist',
      imageUrl: img,
      genres: genresList,
      popularity: (json['popularity'] as num?)?.toInt() ?? 0,
      followers: followersTotal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imageUrl': imageUrl,
        'genres': genres,
        'popularity': popularity,
        'followers': followers,
      };
}

class SpotifyUserProfile {
  final String id;
  final String displayName;
  final String email;
  final String avatarUrl;
  final int followers;
  final String product;
  final String profileUrl;

  const SpotifyUserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    this.followers = 0,
    this.product = 'premium',
    this.profileUrl = '',
  });

  factory SpotifyUserProfile.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List<dynamic>?) ?? [];
    String img = '';
    if (images.isNotEmpty) {
      img = images.first['url']?.toString() ?? '';
    }
    final followersData = json['followers'] as Map<String, dynamic>?;
    final followersTotal = (followersData?['total'] as num?)?.toInt() ?? 0;
    final externalUrls = json['external_urls'] as Map<String, dynamic>?;

    return SpotifyUserProfile(
      id: json['id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? 'Spotify User',
      email: json['email']?.toString() ?? '',
      avatarUrl: img,
      followers: followersTotal,
      product: json['product']?.toString() ?? 'free',
      profileUrl: externalUrls?['spotify']?.toString() ?? '',
    );
  }
}

class SpotifyService {
  static final SpotifyService instance = SpotifyService._internal();
  SpotifyService._internal();

  /// Authenticates with Spotify Client Credentials to obtain a Bearer token
  Future<String?> getClientCredentialsToken(String clientId, String clientSecret) async {
    try {
      final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
      final resp = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'grant_type': 'client_credentials'},
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['access_token'] as String?;
      } else {
        debugPrint('Spotify client credentials failed: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('Spotify token error: $e');
    }
    return null;
  }

  /// Fetches the authenticated user profile from Spotify Web API
  Future<SpotifyUserProfile?> fetchUserProfile(String accessToken) async {
    try {
      final resp = await http.get(
        Uri.parse('https://api.spotify.com/v1/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return SpotifyUserProfile.fromJson(data);
      } else {
        debugPrint('fetchUserProfile error ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      debugPrint('fetchUserProfile error: $e');
    }
    return null;
  }

  /// Fetches user's REAL top artists from Spotify
  Future<List<SpotifyArtist>> fetchUserTopArtists(
    String accessToken, {
    int limit = 20,
    String timeRange = 'medium_term',
  }) async {
    try {
      final resp = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/top/artists?limit=$limit&time_range=$timeRange'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final items = (data['items'] as List<dynamic>?) ?? [];
        return items.map((item) => SpotifyArtist.fromJson(item)).toList();
      } else {
        debugPrint('fetchUserTopArtists status ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      debugPrint('fetchUserTopArtists error: $e');
    }
    return [];
  }

  /// Fetches user's REAL top tracks from Spotify
  Future<List<Track>> fetchUserTopTracks(
    String accessToken, {
    int limit = 50,
    String timeRange = 'medium_term',
  }) async {
    try {
      final resp = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/top/tracks?limit=$limit&time_range=$timeRange'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final items = (data['items'] as List<dynamic>?) ?? [];
        return _parseSpotifyTracks(items);
      }
    } catch (e) {
      debugPrint('fetchUserTopTracks error: $e');
    }
    return [];
  }

  /// Fetches user's recently played tracks from Spotify
  Future<List<Track>> fetchUserRecentlyPlayed(
    String accessToken, {
    int limit = 50,
  }) async {
    try {
      final resp = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/player/recently-played?limit=$limit'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final items = (data['items'] as List<dynamic>?) ?? [];
        final trackItems = items.map((item) => item['track'] ?? {}).toList();
        return _parseSpotifyTracks(trackItems);
      }
    } catch (e) {
      debugPrint('fetchUserRecentlyPlayed error: $e');
    }
    return [];
  }

  /// Fetches user's Spotify playlists
  Future<List<Playlist>> fetchUserPlaylists(
    String accessToken, {
    int limit = 50,
  }) async {
    try {
      final resp = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/playlists?limit=$limit'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final items = (data['items'] as List<dynamic>?) ?? [];
        final playlists = <Playlist>[];

        for (final item in items) {
          final id = item['id']?.toString() ?? '';
          final title = item['name']?.toString() ?? 'Spotify Playlist';
          final desc = item['description']?.toString() ?? '';
          final images = (item['images'] as List<dynamic>?) ?? [];
          final coverUrl = images.isNotEmpty ? images.first['url']?.toString() ?? '' : '';
          final tracksData = item['tracks'] as Map<String, dynamic>?;
          final totalCount = (tracksData?['total'] as num?)?.toInt() ?? 0;

          playlists.add(Playlist(
            id: 'spotify_$id',
            title: title,
            description: desc,
            coverUrl: coverUrl,
            tracks: const [],
            ownerUid: 'spotify_user',
            likesCount: totalCount,
          ));
        }
        return playlists;
      }
    } catch (e) {
      debugPrint('fetchUserPlaylists error: $e');
    }
    return [];
  }

  /// Fetches tracks inside a specific Spotify playlist
  Future<List<Track>> fetchPlaylistTracks(
    String rawPlaylistId,
    String accessToken, {
    int limit = 50,
  }) async {
    try {
      final playlistId = rawPlaylistId.replaceFirst('spotify_', '');
      final resp = await http.get(
        Uri.parse('https://api.spotify.com/v1/playlists/$playlistId/tracks?limit=$limit'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final items = (data['items'] as List<dynamic>?) ?? [];
        final trackItems = items.map((item) => item['track'] ?? {}).toList();
        return _parseSpotifyTracks(trackItems);
      }
    } catch (e) {
      debugPrint('fetchPlaylistTracks error: $e');
    }
    return [];
  }

  /// Scrapes public Spotify playlist, album, or track via Spotify Embed
  Future<List<Track>> scrapeSpotifyPlaylistOrAlbum(String spotifyUrl) async {
    final cleanUrl = spotifyUrl.trim();
    final regExp = RegExp(r'(?:spotify\.(?:com|link)\/|spotify:)(playlist|album|track)(?:\/|:)([a-zA-Z0-9]+)');
    final match = regExp.firstMatch(cleanUrl);

    if (match != null) {
      final type = match.group(1)!;
      final id = match.group(2)!;
      final embedUrl = 'https://open.spotify.com/embed/$type/$id';

      try {
        final response = await http.get(
          Uri.parse(embedUrl),
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final html = response.body;
          final nextDataMatch = RegExp(r'<script id="__NEXT_DATA__" type="application/json">([^<]+)<\/script>').firstMatch(html);
          if (nextDataMatch != null) {
            final jsonStr = nextDataMatch.group(1)!;
            final data = jsonDecode(jsonStr);
            final props = data['props']?['pageProps'];
            final state = props?['state']?['data'] ?? {};
            final entity = state['entity'] ?? {};
            final trackList = (entity['trackList'] as List<dynamic>?) ?? [];
            final entityCover = entity['visualIdentity']?['image']?[0]?['url']?.toString() ??
                entity['coverArt']?['sources']?[0]?['url']?.toString() ??
                '';

            final tracks = <Track>[];
            for (final item in trackList) {
              final title = item['title']?.toString() ?? '';
              final artist = item['subtitle']?.toString() ?? 'Spotify Artist';
              final durationMs = (item['duration'] as num?)?.toInt() ?? 0;
              final uri = item['uri']?.toString() ?? '';
              final trackId = uri.replaceAll('spotify:track:', '');

              if (title.isNotEmpty) {
                tracks.add(Track(
                  id: trackId.isNotEmpty ? trackId : 'sp_${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                  artist: artist,
                  album: entity['title']?.toString() ?? 'Spotify',
                  duration: Duration(milliseconds: durationMs > 0 ? durationMs : 210000),
                  artworkUrl: entityCover,
                  streamUrl: '',
                  spotifyUri: uri,
                ));
              }
            }
            if (tracks.isNotEmpty) return tracks;
          }
        }
      } catch (e) {
        debugPrint('Spotify scraper error: $e');
      }
    }

    return [];
  }

  /// Resolves acoustic taste audio features from Spotify Web API
  Future<Map<String, double>> fetchAudioFeatures(String trackId, String accessToken) async {
    try {
      final cleanId = trackId.replaceAll('spotify:track:', '');
      final resp = await http.get(
        Uri.parse('https://api.spotify.com/v1/audio-features/$cleanId'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return {
          'energy': (data['energy'] as num?)?.toDouble() ?? 0.75,
          'valence': (data['valence'] as num?)?.toDouble() ?? 0.70,
          'danceability': (data['danceability'] as num?)?.toDouble() ?? 0.65,
          'acousticness': (data['acousticness'] as num?)?.toDouble() ?? 0.30,
          'tempo': (data['tempo'] as num?)?.toDouble() ?? 125.0,
        };
      }
    } catch (_) {}
    return {
      'energy': 0.75,
      'valence': 0.70,
      'danceability': 0.65,
      'acousticness': 0.30,
      'tempo': 125.0,
    };
  }

  List<Track> _parseSpotifyTracks(List<dynamic> items) {
    final tracks = <Track>[];
    for (final item in items) {
      if (item == null || item is! Map<String, dynamic>) continue;
      final id = item['id']?.toString() ?? '';
      final title = item['name']?.toString() ?? 'Track';
      final artists = (item['artists'] as List<dynamic>?) ?? [];
      final artistName = artists.isNotEmpty ? artists.first['name']?.toString() ?? 'Artist' : 'Artist';
      final album = item['album'] as Map<String, dynamic>?;
      final albumTitle = album?['name']?.toString() ?? 'Album';
      final images = (album?['images'] as List<dynamic>?) ?? [];
      final artworkUrl = images.isNotEmpty ? images.first['url']?.toString() ?? '' : '';
      final durationMs = (item['duration_ms'] as num?)?.toInt() ?? 210000;
      final uri = item['uri']?.toString() ?? '';

      if (title.isNotEmpty) {
        tracks.add(Track(
          id: id.isNotEmpty ? id : 'sp_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          artist: artistName,
          album: albumTitle,
          duration: Duration(milliseconds: durationMs),
          artworkUrl: artworkUrl,
          streamUrl: '',
          spotifyUri: uri,
        ));
      }
    }
    return tracks;
  }
}
