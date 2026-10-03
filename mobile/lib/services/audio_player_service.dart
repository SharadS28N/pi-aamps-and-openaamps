import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import 'youtube_service.dart';
import 'local_stream_proxy.dart';
import 'pi_aamps_service.dart';
import 'party_service.dart';
import 'integration_service.dart';
import 'download_service.dart';
import 'settings_service.dart';
import 'equalizer_service.dart';

enum AudioTarget { phoneLocal, piSpeaker, partySession }

class AudioPlayerService extends ChangeNotifier {
  static final AudioPlayerService instance = AudioPlayerService._internal();
  factory AudioPlayerService() => instance;

  final AndroidEqualizer _equalizer = AndroidEqualizer();
  final AndroidLoudnessEnhancer _loudnessEnhancer = AndroidLoudnessEnhancer();
  late final AudioPlayer _player;
  final YoutubeService _ytService = YoutubeService();
  final LocalStreamProxy _proxy = LocalStreamProxy();
  final PiAampsService _piService = PiAampsService.instance;
  AudioTarget _target = AudioTarget.phoneLocal;
  Track? _currentTrack;
  bool _isLoading = false;

  double _playbackSpeed = 1.0;
  double _pitch = 1.0;
  double _crossfadeDuration = 3.0;
  bool _loudnessNormalization = true;

  // Sleep timer state
  Timer? _sleepTimer;
  Timer? _sleepTicker;
  DateTime? _sleepEndTime;
  final ValueNotifier<Duration?> _sleepTimerRemaining = ValueNotifier(null);

  // Playback History & Liked Songs
  final List<Track> _history = [];
  final Set<String> _likedIds = {};
  final List<Track> _likedTracks = [];

  // Playlist Queue
  final List<Track> _queue = [];
  int _queueIndex = -1;

  // Stream Controllers for unified local & Pi telemetry (persistent singleton)
  StreamController<PlayerState> _playerStateController = StreamController<PlayerState>.broadcast();
  StreamController<Duration?> _durationController = StreamController<Duration?>.broadcast();
  StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  StreamController<Track?> _currentTrackController = StreamController<Track?>.broadcast();

  void _ensureControllersActive() {
    if (_playerStateController.isClosed) {
      _playerStateController = StreamController<PlayerState>.broadcast();
    }
    if (_durationController.isClosed) {
      _durationController = StreamController<Duration?>.broadcast();
    }
    if (_positionController.isClosed) {
      _positionController = StreamController<Duration>.broadcast();
    }
    if (_currentTrackController.isClosed) {
      _currentTrackController = StreamController<Track?>.broadcast();
    }
  }

  void _safeAddTrack(Track? track) {
    _ensureControllersActive();
    if (!_currentTrackController.isClosed) {
      _currentTrackController.add(track);
    }
  }

  void _safeAddPlayerState(PlayerState state) {
    _ensureControllersActive();
    if (!_playerStateController.isClosed) {
      _playerStateController.add(state);
    }
  }

  void _safeAddDuration(Duration? dur) {
    _ensureControllersActive();
    if (!_durationController.isClosed) {
      _durationController.add(dur);
    }
  }

  void _safeAddPosition(Duration pos) {
    _ensureControllersActive();
    if (!_positionController.isClosed) {
      _positionController.add(pos);
    }
  }

  AudioPlayer get player => _player;
  PiAampsService get piService => _piService;
  AudioTarget get target => _target;
  Track? get currentTrack => _currentTrack;
  bool get isLoading => _isLoading;
  double get playbackSpeed => _playbackSpeed;
  double get pitch => _pitch;
  double get crossfadeDuration => _crossfadeDuration;
  bool get loudnessNormalization => _loudnessNormalization;

  ValueListenable<Duration?> get sleepTimerRemaining => _sleepTimerRemaining;
  bool get isSleepTimerActive => _sleepTimer != null && _sleepTimer!.isActive;

  List<Track> get history => List.unmodifiable(_history);
  List<Track> get likedTracks => List.unmodifiable(_likedTracks);
  List<Track> get queue => List.unmodifiable(_queue);
  int get queueIndex => _queueIndex;

  Stream<PlayerState> get playerStateStream {
    _ensureControllersActive();
    return _playerStateController.stream;
  }

  Stream<Duration?> get durationStream {
    _ensureControllersActive();
    return _durationController.stream;
  }

  Stream<Duration> get positionStream {
    _ensureControllersActive();
    return _positionController.stream;
  }

  Stream<Track?> get currentTrackStream {
    _ensureControllersActive();
    return _currentTrackController.stream;
  }

  Duration get currentPosition {
    if (_target == AudioTarget.piSpeaker) {
      return Duration(milliseconds: (_piService.currentState.currentPosition * 1000).toInt());
    }
    return _player.position;
  }

  Duration get currentDuration {
    if (_target == AudioTarget.piSpeaker) {
      final d = _piService.currentState.duration;
      if (d > 0) return Duration(milliseconds: (d * 1000).toInt());
    }
    return _player.duration ?? (_currentTrack?.duration ?? Duration.zero);
  }

  AudioPlayerService._internal() {
    final bool isAndroid = !kIsWeb && Platform.isAndroid;
    _player = AudioPlayer(
      audioPipeline: isAndroid
          ? AudioPipeline(
              androidAudioEffects: [
                _equalizer,
                _loudnessEnhancer,
              ],
            )
          : null,
    );
    if (isAndroid) {
      EqualizerService.instance.attachPlayer(
        equalizer: _equalizer,
        loudnessEnhancer: _loudnessEnhancer,
        player: _player,
      );
    }

    _loadHistoryAndLikes();
    _proxy.start();

    // Listen to queue track index changes from just_audio (e.g. Next/Prev in notification shade)
    _player.currentIndexStream.listen((idx) {
      if (_target == AudioTarget.phoneLocal && idx != null && idx >= 0 && idx < _queue.length) {
        if (_queueIndex != idx || _currentTrack?.id != _queue[idx].id) {
          _queueIndex = idx;
          _currentTrack = _queue[idx];
          IntegrationService.instance.scrobbleTrack(_currentTrack!);
          _safeAddTrack(_currentTrack);
          notifyListeners();
        }
      }
    });

    // Local player listeners
    _player.playerStateStream.listen((state) {
      if (_target == AudioTarget.phoneLocal) {
        _safeAddPlayerState(state);
      }
      if (state.processingState == ProcessingState.completed) {
        if (_player.loopMode == LoopMode.one) {
          seek(Duration.zero);
          _player.play();
        } else {
          _handleTrackCompletion();
        }
      }
    });

    _player.durationStream.listen((dur) {
      if (_target == AudioTarget.phoneLocal) {
        _safeAddDuration(dur);
      }
      if (dur != null && dur > Duration.zero && _currentTrack != null) {
        if (_currentTrack!.duration == Duration.zero) {
          _currentTrack = _currentTrack!.copyWith(duration: dur);
          notifyListeners();
        }
      }
    });

    _player.positionStream.listen((pos) {
      if (_target == AudioTarget.phoneLocal) {
        _safeAddPosition(pos);
      }
    });

    // Raspberry Pi telemetry listener
    _piService.stateStream.listen((piState) {
      if (_target == AudioTarget.piSpeaker) {
        _safeAddPosition(Duration(milliseconds: (piState.currentPosition * 1000).toInt()));
        if (piState.duration > 0) {
          _safeAddDuration(Duration(milliseconds: (piState.duration * 1000).toInt()));
        }
        _safeAddPlayerState(
          PlayerState(
            piState.isPlaying,
            piState.isPlaying ? ProcessingState.ready : ProcessingState.idle,
          ),
        );
      }
    });

    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) async {
        debugPrint('Playback error observed on local player: $e');
        if (_currentTrack != null && !_currentTrack!.isLocal && _resolvedStreamCache.containsKey(_currentTrack!.id)) {
          final url = _resolvedStreamCache[_currentTrack!.id];
          if (url != null) {
            try {
              await _playThroughProxy(url, 'mp4', _currentTrack!);
              _player.play();
            } catch (_) {}
          }
        }
      },
    );
  }

  Future<void> _loadHistoryAndLikes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('playback_history') ?? [];
      _history.clear();
      for (var s in historyJson) {
        try {
          _history.add(Track.fromJson(jsonDecode(s)));
        } catch (_) {}
      }

      final likesJson = prefs.getStringList('liked_tracks') ?? [];
      _likedTracks.clear();
      _likedIds.clear();
      for (var s in likesJson) {
        try {
          final t = Track.fromJson(jsonDecode(s));
          _likedTracks.add(t);
          _likedIds.add(t.id);
        } catch (_) {}
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _history.take(50).map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList('playback_history', list);
    } catch (_) {}
  }

  Future<void> _saveLikes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _likedTracks.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList('liked_tracks', list);
    } catch (_) {}
  }

  bool isLiked(String trackId) => _likedIds.contains(trackId);

  void toggleLike(Track track) {
    if (_likedIds.contains(track.id)) {
      _likedIds.remove(track.id);
      _likedTracks.removeWhere((t) => t.id == track.id);
    } else {
      _likedIds.add(track.id);
      _likedTracks.insert(0, track);
      if (SettingsService.instance.autoDownloadFavorites && !DownloadService.instance.isDownloaded(track.id)) {
        DownloadService.instance.downloadTrack(track, _ytService);
      }
    }
    _saveLikes();
    notifyListeners();
  }

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();

    _sleepEndTime = DateTime.now().add(duration);
    _sleepTimerRemaining.value = duration;

    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (ticker) {
      if (_sleepEndTime == null) {
        ticker.cancel();
        return;
      }
      final diff = _sleepEndTime!.difference(DateTime.now());
      if (diff <= Duration.zero) {
        ticker.cancel();
        _sleepTimer?.cancel();
        _sleepTimer = null;
        _sleepEndTime = null;
        _sleepTimerRemaining.value = null;
        pause();
      } else {
        _sleepTimerRemaining.value = diff;
      }
    });

    _sleepTimer = Timer(duration, () {
      _sleepTicker?.cancel();
      _sleepTimer = null;
      _sleepEndTime = null;
      _sleepTimerRemaining.value = null;
      pause();
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    _sleepTimer = null;
    _sleepTicker = null;
    _sleepEndTime = null;
    _sleepTimerRemaining.value = null;
  }

  void setAudioTarget(AudioTarget newTarget) {
    _target = newTarget;
    if (_target == AudioTarget.piSpeaker) {
      _player.pause();
      if (_currentTrack != null) {
        _piService.playTrackOnPi(_currentTrack!);
      }
    } else {
      _piService.pause();
      if (_currentTrack != null) {
        resume();
      }
    }
    notifyListeners();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    if (_target == AudioTarget.phoneLocal) {
      await _player.setSpeed(speed);
    }
    notifyListeners();
  }

  Future<void> setPitch(double pitchVal) async {
    _pitch = pitchVal;
    if (_target == AudioTarget.phoneLocal) {
      await _player.setPitch(pitchVal);
    }
    notifyListeners();
  }

  void setCrossfade(double seconds) {
    _crossfadeDuration = seconds;
    notifyListeners();
  }

  void setLoudnessNormalization(bool enabled) {
    _loudnessNormalization = enabled;
    EqualizerService.instance.applyToNativeEffects();
    if (_target == AudioTarget.piSpeaker) {
      _piService.setLoudnessNorm(enabled);
    }
    notifyListeners();
  }

  LoopMode get loopMode => _player.loopMode;
  Stream<LoopMode> get loopModeStream => _player.loopModeStream;
  Stream<bool> get shuffleModeEnabledStream => _player.shuffleModeEnabledStream;
  Future<void> setLoopMode(LoopMode mode) => _player.setLoopMode(mode);
  Future<void> setShuffleModeEnabled(bool enabled) => _player.setShuffleModeEnabled(enabled);

  final Map<String, String> _resolvedStreamCache = {};
  String? getResolvedStreamUrl(String trackId) => _resolvedStreamCache[trackId];

  MediaItem _mediaItemForTrack(Track track) {
    Uri? artUri;
    if (track.artworkUrl.isNotEmpty &&
        (track.artworkUrl.startsWith('http://') || track.artworkUrl.startsWith('https://'))) {
      artUri = Uri.tryParse(track.artworkUrl);
    }
    return MediaItem(
      id: track.id,
      album: track.album.isNotEmpty ? track.album : 'OpenAamps',
      title: track.title,
      artist: track.artist.isNotEmpty ? track.artist : 'OpenAamps Artist',
      artUri: artUri,
      duration: track.duration > Duration.zero ? track.duration : null,
      playable: true,
    );
  }

  // ignore: deprecated_member_use
  ConcatenatingAudioSource _buildAudioSourceForQueue(List<Track> queueList) {
    // ignore: deprecated_member_use
    return ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: queueList.map((t) {
        if (t.localPath != null && t.localPath!.isNotEmpty) {
          final f = File(t.localPath!);
          if (f.existsSync()) {
            return AudioSource.uri(
              Uri.file(f.path),
              tag: _mediaItemForTrack(t),
            );
          }
        }
        final localFile = _proxy.getLocalCacheFile(t.id);
        if (localFile != null && localFile.existsSync()) {
          return AudioSource.uri(
            Uri.file(localFile.path),
            tag: _mediaItemForTrack(t),
          );
        }
        final streamUrl = _resolvedStreamCache[t.id];
        if (streamUrl != null && streamUrl.isNotEmpty) {
          return AudioSource.uri(
            Uri.parse(streamUrl),
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Referer': 'https://www.youtube.com/',
            },
            tag: _mediaItemForTrack(t),
          );
        }
        final proxyUrl = _proxy.getTrackStreamUrl(t);
        return AudioSource.uri(
          Uri.parse(proxyUrl),
          tag: _mediaItemForTrack(t),
        );
      }).toList(),
    );
  }

  void setQueue(List<Track> tracks, {int startIndex = 0, bool autoPlay = true}) {
    _queue.clear();
    _queue.addAll(tracks);
    _queueIndex = startIndex;
    if (autoPlay && startIndex >= 0 && startIndex < _queue.length) {
      playTrack(_queue[startIndex]);
    }
  }

  void addToQueue(Track track) {
    _queue.add(track);
    notifyListeners();
  }

  /// Called when a track finishes playing and loopMode is not LoopMode.one
  Future<void> _handleTrackCompletion() async {
    // If queue has next track, play it
    if (_queue.isNotEmpty && _queueIndex + 1 < _queue.length) {
      await skipToNext();
    } else if (_player.loopMode == LoopMode.all && _queue.isNotEmpty) {
      // Loop-all: restart from beginning
      _queueIndex = 0;
      await playTrack(_queue[0]);
    } else {
      // Autoplay exhausted / repeat off: stop and notify
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> skipToNext() async {
    if (_target == AudioTarget.piSpeaker) {
      if (_queue.isNotEmpty && _queueIndex + 1 < _queue.length) {
        _queueIndex++;
        await playTrack(_queue[_queueIndex]);
      }
      return;
    }
    if (_player.hasNext) {
      await _player.seekToNext();
    } else if (_player.loopMode == LoopMode.all && _queue.isNotEmpty) {
      _queueIndex = 0;
      await _player.seek(Duration.zero, index: 0);
    } else if (_queue.isNotEmpty && _queueIndex + 1 < _queue.length) {
      _queueIndex++;
      await playTrack(_queue[_queueIndex]);
    }
  }

  Future<void> skipToPrevious() async {
    if (_target == AudioTarget.piSpeaker) {
      if (_queueIndex > 0 && _queue.isNotEmpty) {
        _queueIndex--;
        await playTrack(_queue[_queueIndex]);
      }
      return;
    }
    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else if (_queueIndex > 0 && _queue.isNotEmpty) {
      _queueIndex--;
      await playTrack(_queue[_queueIndex]);
    } else {
      await seek(Duration.zero);
    }
  }

  Future<void> skipNext() => skipToNext();
  Future<void> skipPrevious() => skipToPrevious();

  Future<void> _playThroughProxy(String streamUrl, String container, Track track) async {
    await _proxy.start();
    _proxy.setStream(streamUrl);
    final ext = container.isEmpty ? 'mp4' : container;
    final proxyUrl = _proxy.getProxyUrl('stream.$ext');
    final audioSource = AudioSource.uri(
      Uri.parse(proxyUrl),
      tag: _mediaItemForTrack(track),
    );
    await _player.setAudioSource(audioSource);
  }

  Future<void> playTrack(Track track, {bool playImmediately = true, bool notifyParty = true}) async {
    // Proactively verify notification permissions for Android 13+ lockscreen / notification panel
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    } catch (_) {}

    _currentTrack = track;
    _isLoading = true;

    // Update queue position
    final existingIdx = _queue.indexWhere((t) => t.id == track.id);
    if (existingIdx != -1) {
      _queueIndex = existingIdx;
    } else {
      _queue.insert(0, track);
      _queueIndex = 0;
    }

    // Record into history
    _history.removeWhere((t) => t.id == track.id);
    _history.insert(0, track);
    _saveHistory();
    _safeAddTrack(_currentTrack);
    notifyListeners();

    // Scrobble track and update Discord Rich Presence
    IntegrationService.instance.scrobbleTrack(track);

    // Auto-cache played track if setting enabled (0ms offline caching)
    if (SettingsService.instance.autoCacheOnPlay && !DownloadService.instance.isDownloaded(track.id)) {
      DownloadService.instance.downloadTrack(track, _ytService);
    }

    // If target is Pi Speaker, dispatch to Raspberry Pi
    if (_target == AudioTarget.piSpeaker) {
      _isLoading = false;
      notifyListeners();
      await _piService.playTrackOnPi(track);
      return;
    }

    try {
      // 1. Check if track is available as an offline cached file (local path or DownloadService)
      File? localFile;
      if (track.localPath != null && track.localPath!.isNotEmpty) {
        var file = File(track.localPath!);
        if (!file.existsSync() && track.localPath!.startsWith('/storage/emulated/0/')) {
          final alt = File(track.localPath!.replaceFirst('/storage/emulated/0/', '/sdcard/'));
          if (alt.existsSync()) file = alt;
        } else if (!file.existsSync() && track.localPath!.startsWith('/sdcard/')) {
          final alt = File(track.localPath!.replaceFirst('/sdcard/', '/storage/emulated/0/'));
          if (alt.existsSync()) file = alt;
        }
        if (file.existsSync() && file.lengthSync() > 10000) {
          localFile = file;
        }
      }

      // 2. Check DownloadService for cached tracks (even if track.localPath is null)
      if (localFile == null) {
        final downloadedTrack = DownloadService.instance.downloadedTracks
            .where((t) => t.id == track.id)
            .firstOrNull;
        if (downloadedTrack?.localPath != null && downloadedTrack!.localPath!.isNotEmpty) {
          final df = File(downloadedTrack.localPath!);
          if (df.existsSync() && df.lengthSync() > 10000) {
            localFile = df;
            // Update track with local path for future lookups
            _currentTrack = _currentTrack!.copyWith(
              localPath: df.path,
              isDownloaded: true,
              isLocal: true,
            );
          }
        }
      }

      // 3. Check LocalStreamProxy cache directory
      localFile ??= _proxy.getLocalCacheFile(track.id);

      if (localFile != null && localFile.existsSync()) {
        final audioSource = AudioSource.uri(
          Uri.file(localFile.path),
          tag: _mediaItemForTrack(track),
        );

        if (_queue.length > 1) {
          final concatenating = _buildAudioSourceForQueue(_queue);
          await _player.setAudioSource(concatenating, initialIndex: _queueIndex);
        } else {
          await _player.setAudioSource(audioSource);
        }
      } else {
        // Online stream resolution
        await _player.stop();
        StreamData? streamData;

        // Fast-path: Check if direct stream URL was provided by Jam host or previously resolved
        final cachedUrl = _resolvedStreamCache[track.id];
        final directCandidate = (cachedUrl != null && cachedUrl.isNotEmpty)
            ? cachedUrl
            : (track.streamUrl.isNotEmpty &&
                    (track.streamUrl.startsWith('http://') || track.streamUrl.startsWith('https://'))
                ? track.streamUrl
                : null);

        if (directCandidate != null) {
          streamData = StreamData(url: directCandidate, totalBytes: 0, container: 'mp4');
        } else {
          streamData = await _ytService.getBestAudioStream(
            track.id,
            queryFallback: '${track.title} ${track.artist}',
          );
        }

        if (streamData == null) {
          throw Exception('No stream URL found for track "${track.title}"');
        }

        final codecName = streamData.codec.isNotEmpty
            ? streamData.codec
            : (streamData.container.toLowerCase() == 'mp4' ? 'AAC 320kbps' : 'OPUS 160kbps');
        _currentTrack = _currentTrack!.copyWith(codec: codecName);
        _resolvedStreamCache[track.id] = streamData.url;
        _proxy.registerTrackStream(track.id, streamData.url);
        notifyListeners();

        if (_queue.length > 1) {
          final concatenating = _buildAudioSourceForQueue(_queue);
          await _player.setAudioSource(concatenating, initialIndex: _queueIndex);
        } else {
          final desktopHeaders = {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://www.youtube.com/',
          };

          try {
            final audioSource = AudioSource.uri(
              Uri.parse(streamData.url),
              headers: desktopHeaders,
              tag: _mediaItemForTrack(_currentTrack!),
            );
            await _player.setAudioSource(audioSource);
          } catch (e) {
            debugPrint('Direct audio source failed, falling back to proxy: $e');
            await _playThroughProxy(streamData.url, streamData.container, _currentTrack!);
          }
        }
      }
      _isLoading = false;
      await _player.setSpeed(_playbackSpeed);
      await _player.setPitch(_pitch);
      if (playImmediately) {
        _player.play();
      }
      Future.delayed(const Duration(milliseconds: 350), () {
        EqualizerService.instance.applyToNativeEffects();
      });
      if (notifyParty) {
        _notifyPartyPlaybackChange(isPlaying: playImmediately, track: track);
      }
    } catch (e) {
      debugPrint('Error playing track "${track.title}": $e');
      _isLoading = false;
    }
  }

  Future<void> pause({bool notifyParty = true}) async {
    if (_target == AudioTarget.piSpeaker) {
      await _piService.pause();
    } else {
      await _player.pause();
    }
    if (notifyParty) {
      _notifyPartyPlaybackChange(isPlaying: false);
    }
    notifyListeners();
  }

  Future<void> resume({Track? fallbackTrack, bool notifyParty = true}) async {
    if (_target == AudioTarget.piSpeaker) {
      final trackToPlay = _currentTrack ?? fallbackTrack;
      if (trackToPlay != null) {
        await _piService.playTrackOnPi(trackToPlay);
      } else {
        await _piService.resume();
      }
      notifyListeners();
      return;
    }
    if (_player.audioSource == null) {
      final trackToPlay = _currentTrack ?? fallbackTrack;
      if (trackToPlay != null) {
        await playTrack(trackToPlay, notifyParty: notifyParty);
        return;
      }
    }
    _player.play();
    if (notifyParty) {
      _notifyPartyPlaybackChange(isPlaying: true);
    }
    notifyListeners();
  }

  Future<void> seek(Duration position, {bool notifyParty = true}) async {
    if (_target == AudioTarget.piSpeaker) {
      await _piService.seek(position.inSeconds.toDouble());
    } else {
      await _player.seek(position);
    }
    if (notifyParty) {
      _notifyPartyPlaybackChange(isPlaying: _player.playing, position: position);
    }
    notifyListeners();
  }

  Future<void> seekBackward10() async {
    final pos = currentPosition - const Duration(seconds: 10);
    await seek(pos < Duration.zero ? Duration.zero : pos);
  }

  Future<void> seekForward15() async {
    final dur = currentDuration;
    final pos = currentPosition + const Duration(seconds: 15);
    await seek(pos > dur ? dur : pos);
  }

  Future<LoopMode> cycleLoopMode() async {
    final next = switch (_player.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await setLoopMode(next);
    notifyListeners();
    return next;
  }

  void _notifyPartyPlaybackChange({required bool isPlaying, Duration? position, Track? track}) {
    try {
      final party = PartyService.instance;
      if (party.isInParty && party.canControlPlayback) {
        party.broadcastPlaybackChange(
          isPlaying: isPlaying,
          position: position ?? currentPosition,
          track: track ?? _currentTrack,
        );
      }
    } catch (_) {}
  }

  Future<void> setVolume(double volume) async {
    if (_target == AudioTarget.piSpeaker) {
      await _piService.setVolume(volume.toInt());
    } else {
      await _player.setVolume(volume / 100.0);
    }
    notifyListeners();
  }

  Future<void> setReplayGain(double gainDb) async {
    final linear = math.pow(10.0, gainDb / 20.0).toDouble().clamp(0.1, 2.0);
    if (_target == AudioTarget.phoneLocal) {
      await _player.setVolume(linear.clamp(0.0, 1.0));
    }
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    // Do not close persistent broadcast controllers or player
    // to preserve active background audio session across UI rebuilds.
    super.dispose();
  }
}
