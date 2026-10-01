import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/pi_state.dart';
import '../models/track.dart';

class PiAampsService extends ChangeNotifier {
  static final PiAampsService instance = PiAampsService._internal();
  factory PiAampsService() => instance;

  PiAampsService._internal() {
    _loadSavedSettings();
  }

  String _ipAddress = '192.168.18.159';
  int _port = 8000;
  WebSocketChannel? _wsChannel;
  final StreamController<PiState> _stateController = StreamController<PiState>.broadcast();
  PiState _currentState = PiState();
  Timer? _pollingTimer;
  bool _isDisposed = false;

  String get ipAddress => _ipAddress;
  int get port => _port;
  PiState get currentState => _currentState;
  Stream<PiState> get stateStream => _stateController.stream;

  String get baseUrl => 'http://$_ipAddress:$_port';
  String get wsUrl => 'ws://$_ipAddress:$_port/ws';

  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ipAddress = prefs.getString('pi_aamps_ip') ?? '192.168.18.159';
      _port = prefs.getInt('pi_aamps_port') ?? 8000;
      notifyListeners();
    } catch (_) {}
    startMonitoring();
  }

  Future<void> saveSettings({required String ip, required int port}) async {
    _ipAddress = ip.trim();
    _port = port;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pi_aamps_ip', _ipAddress);
      await prefs.setInt('pi_aamps_port', _port);
    } catch (_) {}
    notifyListeners();
    reconnect();
  }

  void startMonitoring() {
    _pollingTimer?.cancel();
    fetchFullStatus();
    connectWebSocket();
    // Poll telemetry & status periodically every 2.5 seconds
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!_isDisposed) {
        fetchFullStatus();
      }
    });
  }

  void stopMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _wsChannel?.sink.close();
  }

  void reconnect() {
    stopMonitoring();
    startMonitoring();
  }

  Future<bool> checkConnection() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/status')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<PiState> fetchFullStatus() async {
    try {
      // 1. Fetch player status
      final statusRes = await http.get(Uri.parse('$baseUrl/api/status')).timeout(const Duration(seconds: 3));
      if (statusRes.statusCode != 200) {
        _setDisconnected();
        return _currentState;
      }
      final statusData = jsonDecode(statusRes.body) as Map<String, dynamic>;

      // 2. Fetch hardware telemetry metrics
      Map<String, dynamic>? metricsData;
      try {
        final metricsRes = await http.get(Uri.parse('$baseUrl/api/system/metrics')).timeout(const Duration(seconds: 3));
        if (metricsRes.statusCode == 200) {
          metricsData = jsonDecode(metricsRes.body) as Map<String, dynamic>;
        }
      } catch (_) {}

      // 3. Fetch bluetooth status
      Map<String, dynamic>? btData;
      try {
        final btRes = await http.get(Uri.parse('$baseUrl/api/bluetooth/status')).timeout(const Duration(seconds: 3));
        if (btRes.statusCode == 200) {
          btData = jsonDecode(btRes.body) as Map<String, dynamic>;
        }
      } catch (_) {}

      _currentState = PiState.fromStatusAndMetrics(
        status: statusData,
        metrics: metricsData,
        btStatus: btData,
        ip: _ipAddress,
        port: _port,
      );
      _stateController.add(_currentState);
      notifyListeners();
      return _currentState;
    } catch (_) {
      _setDisconnected();
      return _currentState;
    }
  }

  void _setDisconnected() {
    if (_currentState.isConnected) {
      _currentState = _currentState.copyWith(isConnected: false);
      _stateController.add(_currentState);
      notifyListeners();
    }
  }

  void connectWebSocket() {
    _wsChannel?.sink.close();
    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsChannel?.ready.catchError((_) {});
      _wsChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data is Map<String, dynamic>) {
              // Trigger fresh full sync on any broadcast event
              fetchFullStatus();
            }
          } catch (_) {}
        },
        onError: (_) {
          // Fallback to HTTP polling
        },
        onDone: () {
          // Reconnect on disconnect after backoff
        },
      );
    } catch (_) {}
  }

  // --- Remote Playback Commands ---

  Future<bool> playTrackOnPi(Track track) async {
    try {
      final ytUrl = track.id.startsWith('http')
          ? track.id
          : (track.streamUrl.isNotEmpty ? track.streamUrl : 'https://www.youtube.com/watch?v=${track.id}');
      final payload = jsonEncode({
        'url': ytUrl,
        'title': track.title,
        'artist': track.artist,
        'thumbnail': track.artworkUrl,
        'duration': track.duration.inSeconds,
      });
      final res = await http.post(
        Uri.parse('$baseUrl/api/play'),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 4));
      await fetchFullStatus();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> togglePlayPause() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/toggle')).timeout(const Duration(seconds: 3));
      await fetchFullStatus();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> pause() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/pause')).timeout(const Duration(seconds: 3));
      await fetchFullStatus();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resume() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/resume')).timeout(const Duration(seconds: 3));
      await fetchFullStatus();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stop() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/stop')).timeout(const Duration(seconds: 3));
      await fetchFullStatus();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> seek(double positionSeconds) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/seek'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'position': positionSeconds}),
      ).timeout(const Duration(seconds: 3));
      _currentState = _currentState.copyWith(currentPosition: positionSeconds);
      _stateController.add(_currentState);
      notifyListeners();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setVolume(int level) async {
    try {
      final clamped = level.clamp(0, 100);
      final res = await http.post(
        Uri.parse('$baseUrl/api/volume'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'volume': clamped}),
      ).timeout(const Duration(seconds: 3));
      _currentState = _currentState.copyWith(volume: clamped, isMuted: clamped == 0);
      _stateController.add(_currentState);
      notifyListeners();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // --- Hardware Audio Output (DAC) Switcher ---

  Future<bool> setAudioOutput(String outputId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/audio/output'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'output': outputId}),
      ).timeout(const Duration(seconds: 4));
      await fetchFullStatus();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // --- Hardware Equalizer Presets ---

  Future<bool> setEqPreset(String preset) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/equalizer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'preset': preset}),
      ).timeout(const Duration(seconds: 3));
      _currentState = _currentState.copyWith(eqPreset: preset);
      _stateController.add(_currentState);
      notifyListeners();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setLoudnessNorm(bool enabled) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/loudness-norm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'enabled': enabled}),
      ).timeout(const Duration(seconds: 3));
      await fetchFullStatus();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // --- Bluetooth Receiver / Speaker Controls ---

  Future<bool> toggleBluetoothPower(bool power) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/bluetooth/power'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'power': power}),
      ).timeout(const Duration(seconds: 4));
      _currentState = _currentState.copyWith(isBluetoothEnabled: power);
      _stateController.add(_currentState);
      notifyListeners();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setBluetoothMode(String mode) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/bluetooth/mode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mode': mode}),
      ).timeout(const Duration(seconds: 4));
      await fetchFullStatus();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> scanBluetoothDevices() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/bluetooth/devices')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> connectBluetoothDevice(String mac) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/bluetooth/connect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mac': mac}),
      ).timeout(const Duration(seconds: 10));
      await fetchFullStatus();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> disconnectBluetoothDevice(String mac) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/bluetooth/disconnect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mac': mac}),
      ).timeout(const Duration(seconds: 6));
      await fetchFullStatus();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // --- Sleep Timer & System Controls ---

  Future<bool> setSleepTimer(int minutes) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/sleep-timer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'minutes': minutes, 'mode': 'duration'}),
      ).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pollingTimer?.cancel();
    _wsChannel?.sink.close();
    _stateController.close();
    super.dispose();
  }
}
