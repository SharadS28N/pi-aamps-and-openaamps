import '../models/track.dart';
import '../models/playback_source.dart';
import '../providers/provider_manager.dart';
import '../providers/music_provider.dart';

class TrackRepository {
  static final TrackRepository instance = TrackRepository._internal();
  TrackRepository._internal();

  final ProviderManager _providerManager = ProviderManager.instance;
  final Map<String, Track> _inMemoryCache = {};

  Future<List<Track>> search(String query, {int limit = 20}) async {
    final searchProviders = _providerManager.getProvidersWithCapability(ProviderCapability.searchTracks);
    final results = <Track>[];
    final seenIds = <String>{};

    for (final provider in searchProviders) {
      try {
        final found = await provider.search(query, limit: limit);
        for (final t in found) {
          if (!seenIds.contains(t.id)) {
            seenIds.add(t.id);
            _inMemoryCache[t.id] = t;
            results.add(t);
          }
        }
      } catch (_) {}
    }

    return results;
  }

  Future<Track?> getTrack(String id) async {
    if (_inMemoryCache.containsKey(id)) {
      return _inMemoryCache[id];
    }

    for (final provider in _providerManager.providers) {
      if (provider.hasCapability(ProviderCapability.trackLookup)) {
        final t = await provider.getTrack(id);
        if (t != null) {
          _inMemoryCache[id] = t;
          return t;
        }
      }
    }
    return null;
  }

  Future<PlaybackSource?> resolveSource(Track track) async {
    return _providerManager.resolveSourceWithFallback(track);
  }

  void cacheTrack(Track track) {
    _inMemoryCache[track.id] = track;
  }
}
