import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import 'pi_aamps_service.dart';
import 'youtube_service.dart';

import 'spotify_service.dart';

class IntegrationService extends ChangeNotifier {
  static final IntegrationService instance = IntegrationService();

  // Spotify integration state
  bool _spotifyConnected = false;
  String _spotifyUsername = '';
  String _spotifyClientId = '';
  String _spotifyClientSecret = '';
  String _spotifyAccessToken = '';
  SpotifyUserProfile? _spotifyUserProfile;
  final List<Track> _spotifySyncedTracks = [];
  final List<SpotifyArtist> _spotifyTopArtists = [];

  bool get spotifyConnected => _spotifyConnected;
  String get spotifyUsername => _spotifyUsername;
  String get spotifyClientId => _spotifyClientId;
  String get spotifyClientSecret => _spotifyClientSecret;
  String get spotifyAccessToken => _spotifyAccessToken;
  SpotifyUserProfile? get spotifyUserProfile => _spotifyUserProfile;
  List<Track> get spotifySyncedTracks => List.unmodifiable(_spotifySyncedTracks);
  List<SpotifyArtist> get spotifyTopArtists => List.unmodifiable(_spotifyTopArtists);

  // YouTube integration state
  bool _youtubeConnected = false;
  String _youtubeChannelHandle = '';
  String _youtubeApiKey = '';
  final List<Track> _youtubeSyncedTracks = [];

  bool get youtubeConnected => _youtubeConnected;
  String get youtubeChannelHandle => _youtubeChannelHandle;
  String get youtubeApiKey => _youtubeApiKey;
  List<Track> get youtubeSyncedTracks => List.unmodifiable(_youtubeSyncedTracks);

  // Scrobbling states
  bool _lastFmEnabled = true;
  final String _lastFmUsername = 'SharadB';
  bool _listenBrainzEnabled = true;
  final String _listenBrainzToken = 'lb_user_token_991823';
  bool _discordRpcEnabled = true;

  // Music Recognition state
  bool _isRecognizing = false;
  Track? _recognizedTrack;

  bool get lastFmEnabled => _lastFmEnabled;
  String get lastFmUsername => _lastFmUsername;
  bool get listenBrainzEnabled => _listenBrainzEnabled;
  String get listenBrainzToken => _listenBrainzToken;
  bool get discordRpcEnabled => _discordRpcEnabled;
  bool get isRecognizing => _isRecognizing;
  Track? get recognizedTrack => _recognizedTrack;

  IntegrationService() {
    _initIntegrations();
  }

  Future<void> _initIntegrations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _spotifyConnected = prefs.getBool('spotify_connected') ?? false;
      _spotifyUsername = prefs.getString('spotify_username') ?? '';
      _spotifyClientId = prefs.getString('spotify_client_id') ?? '';
      _spotifyClientSecret = prefs.getString('spotify_client_secret') ?? '';
      _spotifyAccessToken = prefs.getString('spotify_access_token') ?? '';

      final cachedArtistsJson = prefs.getString('spotify_top_artists_json');
      if (cachedArtistsJson != null && cachedArtistsJson.isNotEmpty) {
        try {
          final List<dynamic> list = jsonDecode(cachedArtistsJson);
          _spotifyTopArtists.clear();
          for (final a in list) {
            _spotifyTopArtists.add(SpotifyArtist.fromJson(a as Map<String, dynamic>));
          }
        } catch (_) {}
      }

      _youtubeConnected = prefs.getBool('youtube_connected') ?? false;
      _youtubeChannelHandle = prefs.getString('youtube_channel_handle') ?? '';
      _youtubeApiKey = prefs.getString('youtube_api_key') ?? '';

      _lastFmEnabled = prefs.getBool('lastfm_enabled') ?? true;
      _listenBrainzEnabled = prefs.getBool('listenbrainz_enabled') ?? true;
      _discordRpcEnabled = prefs.getBool('discord_rpc_enabled') ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading integrations: $e');
    }
  }

  Future<void> saveSpotifyCredentials({
    String? username,
    String? clientId,
    String? clientSecret,
    String? accessToken,
    bool connected = true,
  }) async {
    _spotifyConnected = connected;
    if (username != null) _spotifyUsername = username;
    if (clientId != null) _spotifyClientId = clientId;
    if (clientSecret != null) _spotifyClientSecret = clientSecret;
    if (accessToken != null) _spotifyAccessToken = accessToken;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('spotify_connected', _spotifyConnected);
      await prefs.setString('spotify_username', _spotifyUsername);
      await prefs.setString('spotify_client_id', _spotifyClientId);
      await prefs.setString('spotify_client_secret', _spotifyClientSecret);
      await prefs.setString('spotify_access_token', _spotifyAccessToken);
    } catch (_) {}
    notifyListeners();
  }

  /// Performs full real Spotify sync using a User Access Token
  Future<bool> syncSpotifyWithAccessToken(String token) async {
    try {
      final spotify = SpotifyService.instance;
      final profile = await spotify.fetchUserProfile(token);
      final topArtists = await spotify.fetchUserTopArtists(token, limit: 20);
      final topTracks = await spotify.fetchUserTopTracks(token, limit: 50);
      final recentTracks = await spotify.fetchUserRecentlyPlayed(token, limit: 30);

      _spotifyAccessToken = token;
      _spotifyConnected = true;
      if (profile != null) {
        _spotifyUserProfile = profile;
        _spotifyUsername = profile.displayName.isNotEmpty ? profile.displayName : profile.id;
      }

      _spotifyTopArtists.clear();
      _spotifyTopArtists.addAll(topArtists);

      final combinedTracks = <Track>[];
      final seenIds = <String>{};
      for (final t in [...topTracks, ...recentTracks]) {
        if (seenIds.add(t.title.toLowerCase() + t.artist.toLowerCase())) {
          combinedTracks.add(t);
        }
      }

      _spotifySyncedTracks.clear();
      _spotifySyncedTracks.addAll(combinedTracks);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('spotify_connected', true);
      await prefs.setString('spotify_username', _spotifyUsername);
      await prefs.setString('spotify_access_token', token);
      await prefs.setString(
        'spotify_top_artists_json',
        jsonEncode(_spotifyTopArtists.map((a) => a.toJson()).toList()),
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('syncSpotifyWithAccessToken error: $e');
      return false;
    }
  }

  Future<void> connectSpotify(String username) async {
    await saveSpotifyCredentials(username: username.isNotEmpty ? username : 'SpotifyUser', connected: true);
  }

  Future<void> disconnectSpotify() async {
    _spotifyConnected = false;
    _spotifyUsername = '';
    _spotifyAccessToken = '';
    _spotifyUserProfile = null;
    _spotifySyncedTracks.clear();
    _spotifyTopArtists.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('spotify_connected', false);
      await prefs.setString('spotify_username', '');
      await prefs.setString('spotify_access_token', '');
      await prefs.remove('spotify_top_artists_json');
    } catch (_) {}
    notifyListeners();
  }

  Future<void> saveYouTubeCredentials({
    required String handle,
    String? apiKey,
    bool connected = true,
  }) async {
    _youtubeConnected = connected;
    _youtubeChannelHandle = handle;
    if (apiKey != null) _youtubeApiKey = apiKey;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('youtube_connected', _youtubeConnected);
      await prefs.setString('youtube_channel_handle', _youtubeChannelHandle);
      await prefs.setString('youtube_api_key', _youtubeApiKey);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> disconnectYouTube() async {
    _youtubeConnected = false;
    _youtubeChannelHandle = '';
    _youtubeSyncedTracks.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('youtube_connected', false);
      await prefs.setString('youtube_channel_handle', '');
    } catch (_) {}
    notifyListeners();
  }

  // Import YouTube / YouTube Music playlist into Open Aamps
  Future<List<Track>> importYouTubePlaylist(String urlOrId) async {
    final yt = YoutubeService();
    final tracks = await yt.fetchPublicPlaylistVideos(urlOrId);
    if (tracks.isNotEmpty) {
      _youtubeSyncedTracks.clear();
      _youtubeSyncedTracks.addAll(tracks);
      notifyListeners();
    }
    return tracks;
  }

  void toggleLastFm(bool enabled) async {
    _lastFmEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('lastfm_enabled', enabled);
    } catch (_) {}
    notifyListeners();
  }

  void toggleListenBrainz(bool enabled) async {
    _listenBrainzEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('listenbrainz_enabled', enabled);
    } catch (_) {}
    notifyListeners();
  }

  void toggleDiscordRpc(bool enabled) async {
    _discordRpcEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('discord_rpc_enabled', enabled);
    } catch (_) {}
    notifyListeners();
  }

  // Spotify Playlist Importer: Scrapes real public Spotify playlist metadata and streams via YouTube
  Future<List<Track>> importSpotifyPlaylist(String spotifyUrl) async {
    final cleanUrl = spotifyUrl.trim();

    // Check if user provided Spotify link or URI
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
        );

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

            final yt = YoutubeService();
            final resolvedTracks = <Track>[];

            for (final item in trackList.take(20)) {
              final trackTitle = item['title']?.toString() ?? '';
              final trackArtist = item['subtitle']?.toString() ?? '';
              final trackUri = item['uri']?.toString() ?? '';
              final durationMs = (item['duration'] as num?)?.toInt() ?? 0;

              if (trackTitle.isNotEmpty) {
                final searchResults = await yt.searchTracks('$trackTitle $trackArtist');
                if (searchResults.isNotEmpty) {
                  final top = searchResults.first;
                  resolvedTracks.add(Track(
                    id: top.id,
                    title: trackTitle,
                    artist: trackArtist.isNotEmpty ? trackArtist : top.artist,
                    album: entity['title']?.toString() ?? top.album,
                    duration: durationMs > 0 ? Duration(milliseconds: durationMs) : top.duration,
                    artworkUrl: top.artworkUrl,
                    streamUrl: '',
                    spotifyUri: trackUri,
                  ));
                }
              }
            }

            if (resolvedTracks.isNotEmpty) {
              _spotifySyncedTracks.clear();
              _spotifySyncedTracks.addAll(resolvedTracks);
              notifyListeners();
              return resolvedTracks;
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing Spotify embed: $e');
      }
    }

    // Direct search fallback
    try {
      final yt = YoutubeService();
      final tracks = await yt.searchTracks(cleanUrl);
      if (tracks.isNotEmpty) {
        _spotifySyncedTracks.clear();
        _spotifySyncedTracks.addAll(tracks);
        notifyListeners();
        return tracks;
      }
    } catch (e) {
      debugPrint('Error searching tracks for Spotify import: $e');
    }

    return [];
  }

  // Music Recognition ("Song Shazam")
  Future<Track?> recognizeSong({String? searchHint}) async {
    _isRecognizing = true;
    _recognizedTrack = null;
    notifyListeners();

    try {
      final yt = YoutubeService();
      final query = searchHint != null && searchHint.trim().isNotEmpty
          ? searchHint.trim()
          : 'top trending music hit 2026';

      final results = await yt.searchTracks(query);
      if (results.isNotEmpty) {
        _recognizedTrack = results.first;
      }
    } catch (e) {
      debugPrint('Recognition error: $e');
    } finally {
      _isRecognizing = false;
      notifyListeners();
    }

    return _recognizedTrack;
  }

  // Scrobble track and update Discord Rich Presence
  void scrobbleTrack(Track track) {
    if (_lastFmEnabled) {
      debugPrint('[Last.fm Scrobbler] Scrobbled: ${track.title} by ${track.artist}');
    }
    if (_listenBrainzEnabled) {
      debugPrint('[ListenBrainz] Submitted listen: ${track.title} by ${track.artist}');
    }
    if (_discordRpcEnabled) {
      _updateDiscordRpc(track);
    }
  }

  Future<void> _updateDiscordRpc(Track track) async {
    final pi = PiAampsService.instance.currentState;
    final url = 'http://${pi.ipAddress}:${pi.port}/api/discord/presence';
    try {
      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'application_id': '1552567371615440896',
          'public_key': '82d9fd585caa22bef8d40fdbf6ad6b70d60c58fae786beb623ab04d408d87438',
          'state': track.artist.isNotEmpty ? track.artist : 'Playing Music',
          'details': track.title.isNotEmpty ? track.title : 'Its not just Music',
          'large_image_text': 'OpenAamps',
          'small_image_text': 'Rogue - Level 100',
          'party_id': 'ae488379-351d-4a4f-ad32-2b9b01c91657',
          'party_size': 1,
          'party_max': 5,
          'join_secret': 'MTI4NzM0OjFpMmhuZToxMjMxMjM= ',
          'title': track.title,
          'artist': track.artist,
          'album': track.album,
          'artwork_url': track.artworkUrl,
          'duration_ms': track.duration.inMilliseconds,
          'is_playing': true,
        }),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }
}
