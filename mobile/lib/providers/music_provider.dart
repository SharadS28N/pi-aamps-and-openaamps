import '../models/track.dart';
import '../models/playback_source.dart';

enum ProviderCapability {
  searchTracks,
  searchArtists,
  searchAlbums,
  trackLookup,
  albumLookup,
  artistLookup,
  playlistLookup,
  playlistModification,
  sourceResolution,
  streamRetrieval,
  lyricsRetrieval,
  downloadSupport,
  metadataSynchronization,
  audioFingerprint,
}

enum ProviderStatus {
  active,
  degraded,
  offline,
}

abstract class MusicProvider {
  String get id;
  String get name;
  String get version;
  Set<ProviderCapability> get capabilities;
  ProviderStatus get status;

  bool hasCapability(ProviderCapability cap) => capabilities.contains(cap);

  Future<void> initialize();

  Future<List<Track>> search(String query, {int limit = 20});

  Future<Track?> getTrack(String id);

  Future<PlaybackSource?> resolvePlaybackSource(Track track);

  Future<List<String>?> getLyrics(Track track) async => null;

  Future<void> dispose() async {}
}
