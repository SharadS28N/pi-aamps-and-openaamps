import '../models/track.dart';
import '../models/playback_source.dart';
import '../models/recognition_result.dart';
import '../repositories/track_repository.dart';
import '../services/audio_player_service.dart';
import '../services/recognition_service.dart';
import '../services/query_parser.dart';
import '../services/equalizer_service.dart';
import '../services/download_service.dart';
import '../services/local_audio_service.dart';
import '../services/youtube_service.dart';
import '../repositories/user_data_repository.dart';

class MusicDomainOperations {
  static final MusicDomainOperations instance = MusicDomainOperations._internal();
  MusicDomainOperations._internal();

  final TrackRepository _trackRepo = TrackRepository.instance;
  final AudioPlayerService _audio = AudioPlayerService.instance;
  final AudioRecognitionService _recognition = AudioRecognitionService.instance;

  // Search & Identification Operations
  Future<List<Track>> searchTracks(String query) async {
    final parsed = NaturalQueryParser.instance.parse(query);
    final term = parsed.cleanSearchTerm.isNotEmpty ? parsed.cleanSearchTerm : query;
    return _trackRepo.search(term);
  }

  Future<PlaybackSource?> resolveTrackSource(Track track) async {
    return _trackRepo.resolveSource(track);
  }

  Future<void> identifySongViaVoice({
    required Function(RecognitionResult result) onRecognized,
    required Function(String error) onError,
  }) async {
    return _recognition.startVoiceSearch(
      onRecognized: onRecognized,
      onError: onError,
    );
  }

  Future<void> identifySongViaHumming({
    required Function(RecognitionResult result) onRecognized,
    required Function(String error) onError,
  }) async {
    return _recognition.startHummingRecognition(
      onRecognized: onRecognized,
      onError: onError,
    );
  }

  // Playback Control Operations
  void startPlayback(Track track) {
    _audio.playTrack(track);
  }

  void pausePlayback() {
    _audio.pause();
  }

  void seekPlayback(Duration position) {
    _audio.seek(position);
  }

  void skipNext() {
    _audio.skipNext();
  }

  void skipPrevious() {
    _audio.skipPrevious();
  }

  void addToQueue(Track track) {
    _audio.addToQueue(track);
  }

  void toggleFavorite(Track track) {
    UserDataRepository.instance.toggleFavorite(track);
  }

  Future<void> downloadTrack(Track track) async {
    await DownloadService.instance.downloadTrack(track, YoutubeService());
  }

  Future<void> scanLibrary() async {
    await LocalAudioService().scanDeviceMusic();
  }

  void applyEqualizerPreset(String preset) {
    EqualizerService.instance.setPreset(preset);
  }

  void applyAutoEq(String profileId) {
    EqualizerService.instance.applyAutoEq(profileId);
  }

  void applyReplayGain(double gainDb) {
    _audio.setReplayGain(gainDb);
  }
}
