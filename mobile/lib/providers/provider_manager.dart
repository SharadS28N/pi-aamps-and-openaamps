import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../models/playback_source.dart';
import '../services/youtube_service.dart';
import '../services/local_audio_service.dart';
import 'music_provider.dart';

class YouTubeMusicProvider extends MusicProvider {
  final YoutubeService _yt = YoutubeService();
  ProviderStatus _status = ProviderStatus.active;

  @override
  String get id => 'youtube';

  @override
  String get name => 'YouTube Music Core';

  @override
  String get version => '1.4.0';

  @override
  ProviderStatus get status => _status;

  @override
  Set<ProviderCapability> get capabilities => {
        ProviderCapability.searchTracks,
        ProviderCapability.searchArtists,
        ProviderCapability.searchAlbums,
        ProviderCapability.trackLookup,
        ProviderCapability.sourceResolution,
        ProviderCapability.streamRetrieval,
        ProviderCapability.downloadSupport,
      };

  @override
  Future<void> initialize() async {
    _status = ProviderStatus.active;
  }

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    try {
      final tracks = await _yt.searchTracks(query);
      return tracks.take(limit).toList();
    } catch (e) {
      _status = ProviderStatus.degraded;
      return [];
    }
  }

  @override
  Future<Track?> getTrack(String id) async {
    try {
      final streamUrl = await _yt.getAudioStreamUrl(id);
      if (streamUrl != null) {
        return Track(
          id: id,
          title: 'Track $id',
          artist: 'Artist',
          artworkUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
          streamUrl: streamUrl,
        );
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<PlaybackSource?> resolvePlaybackSource(Track track) async {
    try {
      final streamUrl = await _yt.getAudioStreamUrl(track.id);
      if (streamUrl != null && streamUrl.isNotEmpty) {
        return PlaybackSource(
          uri: Uri.parse(streamUrl),
          mimeType: 'audio/webm; codecs=opus',
          codec: 'OPUS',
          bitrate: 160000,
          sampleRate: 48000,
          channelCount: 2,
          duration: track.duration,
          providerId: id,
          isSeekable: true,
          expiresAt: DateTime.now().add(const Duration(hours: 4)),
        );
      }
    } catch (e) {
      debugPrint('YouTube stream resolution error: $e');
    }
    return null;
  }
}

class LocalFilesProvider extends MusicProvider {
  final LocalAudioService _local = LocalAudioService();
  ProviderStatus _status = ProviderStatus.active;

  @override
  String get id => 'local_storage';

  @override
  String get name => 'Local Filesystem & Storage';

  @override
  String get version => '1.0.0';

  @override
  ProviderStatus get status => _status;

  @override
  Set<ProviderCapability> get capabilities => {
        ProviderCapability.searchTracks,
        ProviderCapability.trackLookup,
        ProviderCapability.sourceResolution,
        ProviderCapability.streamRetrieval,
        ProviderCapability.downloadSupport,
      };

  @override
  Future<void> initialize() async {
    await _local.scanDeviceMusic();
    _status = ProviderStatus.active;
  }

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    final lower = query.toLowerCase();
    final matches = _local.localTracks.where((t) {
      return t.title.toLowerCase().contains(lower) ||
          t.artist.toLowerCase().contains(lower) ||
          t.album.toLowerCase().contains(lower);
    }).take(limit).toList();
    return matches;
  }

  @override
  Future<Track?> getTrack(String id) async {
    return _local.localTracks.where((t) => t.id == id).firstOrNull;
  }

  @override
  Future<PlaybackSource?> resolvePlaybackSource(Track track) async {
    if (track.localPath != null && track.localPath!.isNotEmpty) {
      return PlaybackSource(
        uri: Uri.file(track.localPath!),
        mimeType: track.codec == 'FLAC' ? 'audio/flac' : 'audio/mp4',
        codec: track.codec,
        bitrate: 320000,
        sampleRate: 48000,
        channelCount: 2,
        duration: track.duration,
        providerId: id,
        isSeekable: true,
      );
    }
    return null;
  }
}

class ProviderManager extends ChangeNotifier {
  static final ProviderManager instance = ProviderManager._internal();
  ProviderManager._internal() {
    _registerDefaultProviders();
  }

  final List<MusicProvider> _providers = [];
  String _defaultProviderId = 'youtube';

  List<MusicProvider> get providers => List.unmodifiable(_providers);
  String get defaultProviderId => _defaultProviderId;

  void setDefaultProvider(String id) {
    if (_defaultProviderId != id) {
      _defaultProviderId = id;
      notifyListeners();
    }
  }

  void _registerDefaultProviders() {
    registerProvider(YouTubeMusicProvider());
    registerProvider(LocalFilesProvider());
  }

  void registerProvider(MusicProvider provider) {
    if (!_providers.any((p) => p.id == provider.id)) {
      _providers.add(provider);
      provider.initialize();
      notifyListeners();
    }
  }

  MusicProvider? getProvider(String id) {
    return _providers.where((p) => p.id == id).firstOrNull;
  }

  List<MusicProvider> getProvidersWithCapability(ProviderCapability capability) {
    return _providers.where((p) => p.hasCapability(capability) && p.status != ProviderStatus.offline).toList();
  }

  Future<PlaybackSource?> resolveSourceWithFallback(Track track) async {
    // 1. Try local file if available
    if (track.isLocal || (track.localPath != null && track.localPath!.isNotEmpty)) {
      final localProv = getProvider('local_storage');
      if (localProv != null) {
        final source = await localProv.resolvePlaybackSource(track);
        if (source != null) return source;
      }
    }

    // 2. Try default provider
    final primary = getProvider(_defaultProviderId);
    if (primary != null && primary.hasCapability(ProviderCapability.sourceResolution)) {
      final source = await primary.resolvePlaybackSource(track);
      if (source != null) return source;
    }

    // 3. Fallback to all other providers with sourceResolution
    for (final p in _providers) {
      if (p.id != _defaultProviderId && p.hasCapability(ProviderCapability.sourceResolution)) {
        final source = await p.resolvePlaybackSource(track);
        if (source != null) return source;
      }
    }

    return null;
  }
}
