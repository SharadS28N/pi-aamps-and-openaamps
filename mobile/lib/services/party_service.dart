import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/track.dart';
import 'audio_player_service.dart';
import 'pi_aamps_service.dart';
import 'account_service.dart';
import 'party_host_server.dart';
import 'party_discovery_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PartyMemberModel {
  final String id;
  final String name;
  final String avatarUrl;
  final String deviceName;
  final String role; // "host", "dj", "listener"
  final bool isOnline;

  PartyMemberModel({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.deviceName,
    required this.role,
    required this.isOnline,
  });

  factory PartyMemberModel.fromJson(Map<String, dynamic> json) {
    return PartyMemberModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Member',
      avatarUrl: json['avatar_url'] ?? '',
      deviceName: json['device_name'] ?? 'Phone',
      role: json['role'] ?? 'listener',
      isOnline: json['is_online'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar_url': avatarUrl,
      'device_name': deviceName,
      'role': role,
      'is_online': isOnline,
    };
  }
}

class PartyTrackModel {
  final Track track;
  final String addedBy;
  final String addedByName;
  final int votes;
  final List<String> votedMembers;

  PartyTrackModel({
    required this.track,
    required this.addedBy,
    required this.addedByName,
    required this.votes,
    required this.votedMembers,
  });

  factory PartyTrackModel.fromJson(Map<String, dynamic> json) {
    return PartyTrackModel(
      track: Track(
        id: json['id'] ?? '',
        title: json['title'] ?? 'Unknown',
        artist: json['artist'] ?? 'Unknown Artist',
        album: '',
        duration: Duration(seconds: json['duration'] ?? 0),
        artworkUrl: json['thumbnail'] ?? '',
        streamUrl: '',
      ),
      addedBy: json['added_by'] ?? '',
      addedByName: json['added_by_name'] ?? '',
      votes: json['votes'] ?? 0,
      votedMembers: (json['voted_members'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class PartyService extends ChangeNotifier {
  static final PartyService instance = PartyService._internal();
  factory PartyService() => instance;

  PartyService._internal() {
    _initDeviceName();
  }

  String _deviceName = 'Android Phone';
  String? _currentRoomCode;
  String? _hostId;
  String? _hostName;
  String? _activePartyBaseUrl;
  bool _allowCollaborativeDj = true;
  bool _isInParty = false;
  bool _isConnecting = false;
  int _driftMs = 0;

  WebSocketChannel? _wsChannel;
  Timer? _driftCheckTimer;
  Timer? _reconnectTimer;
  StreamSubscription<DocumentSnapshot>? _firestoreSub;

  final List<PartyMemberModel> _members = [];
  final List<PartyTrackModel> _partyQueue = [];
  final List<Map<String, dynamic>> _recentReactions = [];
  final List<Map<String, dynamic>> _chatMessages = [];
  Track? _partyCurrentTrack;
  bool _partyIsPlaying = false;
  int _lastServerPositionMs = 0;
  int _lastServerTimestampMs = 0;

  // Stream controller for real-time room state
  final StreamController<Map<String, dynamic>> _partyEventController = StreamController.broadcast();

  String get deviceName => _deviceName;
  String? get currentRoomCode => _currentRoomCode;
  String get roomCode => _currentRoomCode ?? '';
  String? get hostId => _hostId;
  String? get hostName => _hostName;
  String? get activePartyBaseUrl => _activePartyBaseUrl;
  bool get allowCollaborativeDj => _allowCollaborativeDj;
  bool get isInParty => _isInParty;
  bool get isConnecting => _isConnecting;
  int get driftMs => _driftMs;

  List<PartyMemberModel> get members => List.unmodifiable(_members);
  List<PartyTrackModel> get partyQueue => List.unmodifiable(_partyQueue);
  List<Map<String, dynamic>> get recentReactions => List.unmodifiable(_recentReactions);
  List<Map<String, dynamic>> get chatMessages => List.unmodifiable(_chatMessages);
  Track? get partyCurrentTrack => _partyCurrentTrack;
  bool get partyIsPlaying => _partyIsPlaying;
  Stream<Map<String, dynamic>> get partyEventStream => _partyEventController.stream;

  bool get isHost {
    final myId = AccountService.instance.activeAccount.id;
    return _hostId == myId;
  }

  bool get canControlPlayback {
    if (isHost) return true;
    if (_allowCollaborativeDj) return true;
    final myId = AccountService.instance.activeAccount.id;
    final me = _members.firstWhere((m) => m.id == myId, orElse: () => PartyMemberModel(id: '', name: '', avatarUrl: '', deviceName: '', role: 'listener', isOnline: true));
    return me.role == 'dj';
  }

  Future<void> _initDeviceName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _deviceName = prefs.getString('custom_device_name') ?? 'Galaxy A16';
    } catch (_) {}
  }

  Future<void> setCustomDeviceName(String name) async {
    _deviceName = name;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_device_name', name);
    } catch (_) {}
    notifyListeners();
  }

  // --- Create Listening Party ---
  Future<bool> createParty({Track? initialTrack}) async {
    _isConnecting = true;
    notifyListeners();

    final account = AccountService.instance.activeAccount;

    // 1. Check if external Pi server is running and reachable
    final pi = PiAampsService.instance;
    bool piReachable = false;
    try {
      final piCheck = await http.get(Uri.parse('${pi.baseUrl}/api/status')).timeout(const Duration(milliseconds: 600));
      piReachable = piCheck.statusCode == 200;
    } catch (_) {
      piReachable = false;
    }

    if (piReachable) {
      try {
        final payload = {
          'host_id': account.id,
          'host_name': account.name,
          'device_name': _deviceName,
          'avatar_url': account.avatarUrl,
          if (initialTrack != null)
            'initial_track': {
              'id': initialTrack.id,
              'title': initialTrack.title,
              'artist': initialTrack.artist,
              'thumbnail': initialTrack.artworkUrl,
              'duration': initialTrack.duration.inSeconds,
            },
        };

        final res = await http.post(
          Uri.parse('${pi.baseUrl}/api/party/create'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body)['room'];
          _activePartyBaseUrl = pi.baseUrl;
          _applyRoomSnapshot(data);
          _isInParty = true;
          _isConnecting = false;
          _connectWebSocket();
          _startDriftCorrection();
          notifyListeners();
          return true;
        }
      } catch (e) {
        debugPrint('Pi party creation failed: $e');
      }
    }

    // 2. Direct Mobile-to-Mobile Hosting:
    // Start embedded PartyHostServer on this phone so other phones can join directly over Wi-Fi
    try {
      String localIp = '127.0.0.1';
      try {
        final interfaces = await NetworkInterface.list(includeLoopback: false, type: InternetAddressType.IPv4);
        for (var iface in interfaces) {
          for (var addr in iface.addresses) {
            if (!addr.isLoopback && addr.address.contains('.')) {
              if (iface.name.toLowerCase().contains('wlan') ||
                  iface.name.toLowerCase().contains('wifi') ||
                  addr.address.startsWith('192.168.') ||
                  addr.address.startsWith('10.') ||
                  addr.address.startsWith('172.')) {
                localIp = addr.address;
                break;
              }
            }
          }
        }
      } catch (_) {}

      final lastOctet = localIp.split('.').last;
      final roomCode = 'JAM-$lastOctet';

      final success = await PartyHostServer.instance.start(
        hostId: account.id,
        hostName: account.name,
        deviceName: _deviceName,
        roomCode: roomCode,
        initialTrack: initialTrack,
      );

      if (success) {
        _activePartyBaseUrl = PartyHostServer.instance.hostBaseUrl;
        final snap = PartyHostServer.instance.toSnapshot();
        _applyRoomSnapshot(snap);
        _isInParty = true;
        _isConnecting = false;
        _connectWebSocket();
        _startDriftCorrection();
        _saveRoomToFirestore(roomCode, snap);
        _listenFirestoreRoom(roomCode);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error starting embedded party host server: $e');
    }

    _isConnecting = false;
    notifyListeners();
    return false;
  }

  // --- Join Listening Party by Room Code ---
  Future<bool> joinParty(String roomCode) async {
    // 1. Sanitize room code properly: handles 'JAM-159', 'JAM159', '159', 'jam 159'
    String clean = roomCode.trim().toUpperCase().replaceAll(' ', '');
    if (clean.isEmpty) return false;
    if (clean.startsWith('JAM')) {
      clean = clean.substring(3);
      if (clean.startsWith('-')) clean = clean.substring(1);
    }
    if (clean.isEmpty) return false;
    final normalizedCode = 'JAM-$clean';
    final rawNumber = clean;

    _isConnecting = true;
    notifyListeners();

    final account = AccountService.instance.activeAccount;

    // 2. Dual-Track Parallel Discovery: Local Wi-Fi + Cloud Firestore (Tokha / WAN / LTE)
    // Run both concurrently so remote friends join in <400ms without waiting for local subnet timeouts!

    Future<bool> tryLocalLan() async {
      try {
        String? hostBaseUrl = await PartyDiscoveryService.instance.resolveHostBaseUrl(normalizedCode);
        hostBaseUrl ??= await PartyDiscoveryService.instance.resolveHostBaseUrl(rawNumber);

        // Fallback check configured Pi server
        if (hostBaseUrl == null) {
          final pi = PiAampsService.instance;
          try {
            final res = await http.get(Uri.parse('${pi.baseUrl}/api/party/$normalizedCode/state')).timeout(const Duration(milliseconds: 700));
            if (res.statusCode == 200) hostBaseUrl = pi.baseUrl;
          } catch (_) {}
        }

        if (hostBaseUrl != null) {
          final payload = {
            'room_code': normalizedCode,
            'member_id': account.id,
            'member_name': account.name,
            'device_name': _deviceName,
            'avatar_url': account.avatarUrl,
          };

          final res = await http.post(
            Uri.parse('$hostBaseUrl/api/party/join'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          ).timeout(const Duration(seconds: 3));

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body)['room'];
            _activePartyBaseUrl = hostBaseUrl;
            _applyRoomSnapshot(data);
            _isInParty = true;
            _isConnecting = false;
            _connectWebSocket();
            _startDriftCorrection();
            _syncLocalAudioPlayer();
            _listenFirestoreRoom(normalizedCode);
            notifyListeners();
            return true;
          }
        }
      } catch (e) {
        debugPrint('[PartyService] Local LAN join attempt error: $e');
      }
      return false;
    }

    Future<bool> tryFirestore() async {
      try {
        var doc = await FirebaseFirestore.instance
            .collection('jam_rooms')
            .doc(normalizedCode)
            .get()
            .timeout(const Duration(seconds: 4));

        if (!doc.exists) {
          doc = await FirebaseFirestore.instance
              .collection('jam_rooms')
              .doc(rawNumber)
              .get()
              .timeout(const Duration(seconds: 4));
        }

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final myMember = {
            'id': account.id,
            'name': account.name,
            'avatar_url': account.avatarUrl,
            'device_name': _deviceName,
            'role': 'listener',
            'is_online': true,
          };
          await FirebaseFirestore.instance.collection('jam_rooms').doc(doc.id).set({
            'members': {
              account.id: myMember,
            }
          }, SetOptions(merge: true));

          _applyRoomSnapshot(data);
          _isInParty = true;
          _isConnecting = false;
          _listenFirestoreRoom(doc.id);
          _startDriftCorrection();
          _syncLocalAudioPlayer();
          notifyListeners();
          return true;
        }
      } catch (e) {
        debugPrint('[PartyService] Firestore join attempt error: $e');
      }
      return false;
    }

    // Run LAN and Firestore lookups concurrently
    final results = await Future.wait([tryLocalLan(), tryFirestore()]);
    if (results.any((r) => r == true)) {
      _isConnecting = false;
      notifyListeners();
      return true;
    }

    _isConnecting = false;
    notifyListeners();
    return false;
  }

  // --- Leave Listening Party ---
  Future<void> leaveParty() async {
    if (!_isInParty) return;

    final account = AccountService.instance.activeAccount;
    final baseUrl = _activePartyBaseUrl ?? PiAampsService.instance.baseUrl;
    final code = _currentRoomCode;

    _driftCheckTimer?.cancel();
    _reconnectTimer?.cancel();
    _wsChannel?.sink.close();
    _wsChannel = null;
    _firestoreSub?.cancel();
    _firestoreSub = null;

    if (code != null) {
      try {
        await http.post(
          Uri.parse('$baseUrl/api/party/$code/leave?member_id=${account.id}'),
        ).timeout(const Duration(seconds: 2));
      } catch (_) {}
      try {
        await FirebaseFirestore.instance.collection('jam_rooms').doc(code).update({
          'members.${account.id}.is_online': false,
        });
      } catch (_) {}
    }

    if (PartyHostServer.instance.isRunning) {
      await PartyHostServer.instance.stop();
    }

    _isInParty = false;
    _currentRoomCode = null;
    _hostId = null;
    _hostName = null;
    _activePartyBaseUrl = null;
    _members.clear();
    _partyQueue.clear();
    _recentReactions.clear();
    _chatMessages.clear();
    _partyCurrentTrack = null;
    _partyIsPlaying = false;
    _driftMs = 0;
    notifyListeners();
  }

  // --- WebSocket Connection ---
  void _connectWebSocket() {
    if (_currentRoomCode == null) return;
    
    // Connect to active party host base URL (embedded host phone or Pi server)
    final targetUrl = _activePartyBaseUrl ?? PiAampsService.instance.baseUrl;
    final uri = Uri.parse(targetUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final portPart = uri.hasPort ? ':${uri.port}' : '';
    final wsUrl = '$wsScheme://${uri.host}$portPart/api/party/ws/$_currentRoomCode';

    try {
      _wsChannel?.sink.close();
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsChannel?.ready.catchError((_) {});

      _wsChannel!.stream.listen(
        (message) {
          try {
            final json = jsonDecode(message);
            final type = json['type'];
            final data = json['data'];

            if (type == 'init_party' ||
                type == 'member_joined' ||
                type == 'member_left' ||
                type == 'room_settings_updated' ||
                type == 'host_transferred') {
              _applyRoomSnapshot(data);
              notifyListeners();
            } else if (type == 'playback_updated') {
              _applyRoomSnapshot(data);
              _syncLocalAudioPlayer();
              notifyListeners();
            } else if (type == 'queue_updated') {
              _applyRoomSnapshot(data);
              notifyListeners();
            } else if (type == 'party_reaction') {
              if (data is Map) {
                _recentReactions.insert(0, Map<String, dynamic>.from(data));
                if (_recentReactions.length > 20) _recentReactions.removeLast();
                notifyListeners();
              }
            } else if (type == 'party_chat') {
              if (data is Map) {
                _chatMessages.add(Map<String, dynamic>.from(data));
                if (_chatMessages.length > 50) _chatMessages.removeAt(0);
                notifyListeners();
              }
            }
          } catch (_) {}
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_isInParty || _currentRoomCode == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () {
      if (_isInParty) _connectWebSocket();
    });
  }

  void _listenFirestoreRoom(String roomCode) {
    _firestoreSub?.cancel();
    _firestoreSub = FirebaseFirestore.instance
        .collection('jam_rooms')
        .doc(roomCode)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        _applyRoomSnapshot(data);
        _syncLocalAudioPlayer();
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('[PartyService] Firestore jam room listener error: $e');
    });
  }

  Future<void> _saveRoomToFirestore(String roomCode, Map<String, dynamic> snapshot) async {
    try {
      await FirebaseFirestore.instance.collection('jam_rooms').doc(roomCode).set(snapshot, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PartyService] Firestore save room error: $e');
    }
  }

  // --- Apply Room Snapshot from Server ---
  void _applyRoomSnapshot(Map<String, dynamic> data) {
    _currentRoomCode = data['room_code'];
    _hostId = data['host_id'];
    _hostName = data['host_name'];
    _allowCollaborativeDj = data['allow_collaborative_dj'] ?? true;
    _partyIsPlaying = data['is_playing'] ?? false;
    _lastServerPositionMs = data['position_ms'] ?? 0;
    _lastServerTimestampMs = data['server_timestamp_ms'] ?? 0;

    // Members
    _members.clear();
    final membersRaw = data['members'];
    if (membersRaw is Map) {
      for (var m in membersRaw.values) {
        if (m is Map) {
          _members.add(PartyMemberModel.fromJson(Map<String, dynamic>.from(m)));
        }
      }
    } else if (membersRaw is List) {
      for (var m in membersRaw) {
        if (m is Map) {
          _members.add(PartyMemberModel.fromJson(Map<String, dynamic>.from(m)));
        }
      }
    }

    // Current Track
    if (data['current_track'] != null && data['current_track'] is Map) {
      final ct = Map<String, dynamic>.from(data['current_track'] as Map);
      _partyCurrentTrack = Track(
        id: ct['id']?.toString() ?? '',
        title: ct['title']?.toString() ?? 'Unknown',
        artist: ct['artist']?.toString() ?? 'Unknown Artist',
        album: ct['album']?.toString() ?? '',
        duration: Duration(seconds: (ct['duration'] as num?)?.toInt() ?? 0),
        artworkUrl: ct['thumbnail']?.toString() ?? '',
        streamUrl: ct['stream_url']?.toString() ?? '',
      );
    } else {
      _partyCurrentTrack = null;
    }

    // Queue
    _partyQueue.clear();
    final qList = data['queue'] as List<dynamic>? ?? [];
    for (var item in qList) {
      if (item is Map) {
        _partyQueue.add(PartyTrackModel.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    // Reactions
    if (data['recent_reactions'] is List) {
      _recentReactions.clear();
      for (var r in data['recent_reactions']) {
        if (r is Map) _recentReactions.add(Map<String, dynamic>.from(r));
      }
    }

    // Chat Messages
    if (data['chat_messages'] is List) {
      _chatMessages.clear();
      for (var c in data['chat_messages']) {
        if (c is Map) _chatMessages.add(Map<String, dynamic>.from(c));
      }
    }
  }

  // --- Timestamp-Based Synchronization & Drift Corrector ---
  void _startDriftCorrection() {
    _driftCheckTimer?.cancel();
    _driftCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isInParty) return;
      _calculateAndCorrectDrift();
    });
  }

  void _calculateAndCorrectDrift() {
    final player = AudioPlayerService.instance.player;
    if (_partyCurrentTrack == null || !player.playing) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedSinceUpdate = _partyIsPlaying ? (nowMs - _lastServerTimestampMs) : 0;
    final expectedPositionMs = _lastServerPositionMs + elapsedSinceUpdate;

    final actualPositionMs = player.position.inMilliseconds;
    _driftMs = (actualPositionMs - expectedPositionMs).abs();

    // Deadband: if drift is less than 200ms, consider in-sync to avoid audio stutter
    // If drift exceeds 450ms, gently seek to expected position
    if (_driftMs > 450) {
      player.seek(Duration(milliseconds: expectedPositionMs));
    }
    notifyListeners();
  }

  Future<void> _syncLocalAudioPlayer() async {
    final audio = AudioPlayerService.instance;
    if (_partyCurrentTrack == null) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedSinceUpdate = _partyIsPlaying ? (nowMs - _lastServerTimestampMs) : 0;
    final targetPosition = Duration(milliseconds: _lastServerPositionMs + elapsedSinceUpdate);

    // If local player is playing a different song, load the party song
    if (audio.currentTrack?.id != _partyCurrentTrack!.id) {
      await audio.playTrack(_partyCurrentTrack!, playImmediately: _partyIsPlaying, notifyParty: false);
      if (targetPosition > Duration.zero) {
        audio.seek(targetPosition, notifyParty: false);
      }
    } else {
      // Same song: synchronize play/pause state and position
      if (_partyIsPlaying && !audio.player.playing) {
        audio.player.play();
      } else if (!_partyIsPlaying && audio.player.playing) {
        audio.player.pause();
      }

      final drift = (audio.player.position - targetPosition).inMilliseconds.abs();
      if (drift > 450) {
        audio.seek(targetPosition, notifyParty: false);
      }
    }
  }

  // --- Collaborative Actions Dispatched by Client ---

  Future<void> broadcastPlaybackChange({
    required bool isPlaying,
    required Duration position,
    Track? track,
  }) async {
    if (!_isInParty || _currentRoomCode == null || !canControlPlayback) return;

    final account = AccountService.instance.activeAccount;
    final baseUrl = _activePartyBaseUrl ?? PiAampsService.instance.baseUrl;

    // If this device is the local embedded server host, update local server
    if (PartyHostServer.instance.isRunning) {
      PartyHostServer.instance.updatePlaybackState(
        track: track ?? _partyCurrentTrack,
        positionMs: position.inMilliseconds,
        isPlaying: isPlaying,
      );
      _applyRoomSnapshot(PartyHostServer.instance.toSnapshot());
      notifyListeners();
    }

    final payload = {
      'room_code': _currentRoomCode,
      'sender_id': account.id,
      'is_playing': isPlaying,
      'position_ms': position.inMilliseconds,
      if (track != null)
        'track': {
          'id': track.id,
          'title': track.title,
          'artist': track.artist,
          'thumbnail': track.artworkUrl,
          'duration': track.duration.inSeconds,
        },
    };

    // 1. Send via WebSocket for minimal latency
    if (_wsChannel != null) {
      try {
        _wsChannel!.sink.add(jsonEncode({
          'type': 'sync_playback',
          'data': payload,
        }));
      } catch (_) {}
    }

    // 2. Fallback REST
    try {
      await http.post(
        Uri.parse('$baseUrl/api/party/$_currentRoomCode/playback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (_) {}

    // 3. Cloud Firestore real-time sync for cross-network / remote devices (e.g. Tokha friend)
    try {
      final activeTrack = track ?? _partyCurrentTrack;
      final updateData = <String, dynamic>{
        'is_playing': isPlaying,
        'position_ms': position.inMilliseconds,
        'server_timestamp_ms': DateTime.now().millisecondsSinceEpoch,
      };
      if (activeTrack != null) {
        updateData['current_track'] = {
          'id': activeTrack.id,
          'title': activeTrack.title,
          'artist': activeTrack.artist,
          'thumbnail': activeTrack.artworkUrl,
          'duration': activeTrack.duration.inSeconds,
          'stream_url': AudioPlayerService.instance.getResolvedStreamUrl(activeTrack.id) ?? activeTrack.streamUrl,
        };
      }
      await FirebaseFirestore.instance.collection('jam_rooms').doc(_currentRoomCode!).set(
        updateData,
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[PartyService] Firestore playback update error: $e');
    }
  }

  Future<void> addToPartyQueue(Track track) async {
    if (!_isInParty || _currentRoomCode == null) return;

    final account = AccountService.instance.activeAccount;
    final baseUrl = _activePartyBaseUrl ?? PiAampsService.instance.baseUrl;

    if (PartyHostServer.instance.isRunning) {
      PartyHostServer.instance.addQueueItem(track, account.id, account.name);
      _applyRoomSnapshot(PartyHostServer.instance.toSnapshot());
      notifyListeners();
    }

    final payload = {
      'room_code': _currentRoomCode,
      'sender_id': account.id,
      'sender_name': account.name,
      'track': {
        'id': track.id,
        'title': track.title,
        'artist': track.artist,
        'thumbnail': track.artworkUrl,
        'duration': track.duration.inSeconds,
      },
    };

    if (_wsChannel != null) {
      try {
        _wsChannel!.sink.add(jsonEncode({
          'type': 'add_queue',
          'data': payload,
        }));
      } catch (_) {}
    }

    try {
      await http.post(
        Uri.parse('$baseUrl/api/party/$_currentRoomCode/queue'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (_) {}

    // Cloud Firestore queue append
    try {
      final item = {
        'id': track.id,
        'title': track.title,
        'artist': track.artist,
        'thumbnail': track.artworkUrl,
        'duration': track.duration.inSeconds,
        'added_by': account.id,
        'added_by_name': account.name,
        'votes': 1,
        'voted_members': [account.id],
      };
      FirebaseFirestore.instance.collection('jam_rooms').doc(_currentRoomCode!).update({
        'queue': FieldValue.arrayUnion([item]),
      });
    } catch (_) {}
  }

  Future<void> voteQueueTrack(String trackId) async {
    if (!_isInParty || _currentRoomCode == null) return;

    final account = AccountService.instance.activeAccount;
    final baseUrl = _activePartyBaseUrl ?? PiAampsService.instance.baseUrl;

    if (PartyHostServer.instance.isRunning) {
      PartyHostServer.instance.voteTrackItem(trackId, account.id);
      _applyRoomSnapshot(PartyHostServer.instance.toSnapshot());
      notifyListeners();
      return;
    }

    final payload = {
      'room_code': _currentRoomCode,
      'sender_id': account.id,
      'track_id': trackId,
    };

    if (_wsChannel != null) {
      try {
        _wsChannel!.sink.add(jsonEncode({
          'type': 'vote_track',
          'data': payload,
        }));
      } catch (_) {}
    }

    try {
      await http.post(
        Uri.parse('$baseUrl/api/party/$_currentRoomCode/vote'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (_) {}
  }

  Future<void> skipPartyTrack() async {
    if (!_isInParty || _currentRoomCode == null || !canControlPlayback) return;

    final account = AccountService.instance.activeAccount;
    final baseUrl = _activePartyBaseUrl ?? PiAampsService.instance.baseUrl;

    if (PartyHostServer.instance.isRunning) {
      PartyHostServer.instance.skipToNextTrack();
      _applyRoomSnapshot(PartyHostServer.instance.toSnapshot());
      _syncLocalAudioPlayer();
      notifyListeners();
    }

    if (_wsChannel != null) {
      try {
        _wsChannel!.sink.add(jsonEncode({
          'type': 'skip_track',
          'data': {'sender_id': account.id},
        }));
      } catch (_) {}
    }

    try {
      await http.post(
        Uri.parse('$baseUrl/api/party/$_currentRoomCode/skip?sender_id=${account.id}'),
      );
    } catch (_) {}

    // Cloud Firestore skip
    try {
      if (_partyQueue.isNotEmpty) {
        final next = _partyQueue.first;
        FirebaseFirestore.instance.collection('jam_rooms').doc(_currentRoomCode!).update({
          'current_track': {
            'id': next.track.id,
            'title': next.track.title,
            'artist': next.track.artist,
            'thumbnail': next.track.artworkUrl,
            'duration': next.track.duration.inSeconds,
          },
          'position_ms': 0,
          'is_playing': true,
          'server_timestamp_ms': DateTime.now().millisecondsSinceEpoch,
          'queue': _partyQueue.sublist(1).map((q) => {
            'id': q.track.id,
            'title': q.track.title,
            'artist': q.track.artist,
            'thumbnail': q.track.artworkUrl,
            'duration': q.track.duration.inSeconds,
            'added_by': q.addedBy,
            'added_by_name': q.addedByName,
            'votes': q.votes,
            'voted_members': q.votedMembers,
          }).toList(),
        });
      }
    } catch (_) {}
  }

  Future<void> toggleCollaborativeDj(bool allow) async {
    if (!_isInParty || _currentRoomCode == null || !isHost) return;

    final account = AccountService.instance.activeAccount;
    final baseUrl = _activePartyBaseUrl ?? PiAampsService.instance.baseUrl;

    if (PartyHostServer.instance.isRunning) {
      PartyHostServer.instance.setCollaborativeDj(allow);
      _allowCollaborativeDj = allow;
      notifyListeners();
      return;
    }

    try {
      await http.post(
        Uri.parse('$baseUrl/api/party/$_currentRoomCode/dj-mode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'room_code': _currentRoomCode,
          'sender_id': account.id,
          'allow_collaborative_dj': allow,
        }),
      );
      _allowCollaborativeDj = allow;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> sendReaction(String reactionType, String label) async {
    if (!_isInParty || _currentRoomCode == null) return;
    final account = AccountService.instance.activeAccount;
    final rx = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'sender_name': account.name,
      'reaction': reactionType,
      'label': label,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _recentReactions.insert(0, rx);
    if (_recentReactions.length > 20) _recentReactions.removeLast();
    notifyListeners();

    if (PartyHostServer.instance.isRunning) {
      PartyHostServer.instance.broadcastCustom('party_reaction', rx);
    } else {
      final baseUrl = _activePartyBaseUrl ?? PiAampsService.instance.baseUrl;
      try {
        await http.post(
          Uri.parse('$baseUrl/api/party/$_currentRoomCode/reaction'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'sender_name': account.name,
            'reaction': reactionType,
            'label': label,
          }),
        ).timeout(const Duration(seconds: 2));
      } catch (_) {}
    }

    try {
      await FirebaseFirestore.instance.collection('jam_rooms').doc(_currentRoomCode!).update({
        'recent_reactions': FieldValue.arrayUnion([rx]),
      });
    } catch (_) {}
  }

  Future<void> sendChatMessage(String message) async {
    if (!_isInParty || _currentRoomCode == null || message.trim().isEmpty) return;
    final account = AccountService.instance.activeAccount;
    final chatItem = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'sender_id': account.id,
      'sender_name': account.name,
      'message': message.trim(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _chatMessages.add(chatItem);
    if (_chatMessages.length > 50) _chatMessages.removeAt(0);
    notifyListeners();

    if (PartyHostServer.instance.isRunning) {
      PartyHostServer.instance.broadcastCustom('party_chat', chatItem);
    } else {
      final baseUrl = _activePartyBaseUrl ?? PiAampsService.instance.baseUrl;
      try {
        await http.post(
          Uri.parse('$baseUrl/api/party/$_currentRoomCode/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'sender_id': account.id,
            'sender_name': account.name,
            'message': message.trim(),
          }),
        ).timeout(const Duration(seconds: 2));
      } catch (_) {}
    }

    try {
      await FirebaseFirestore.instance.collection('jam_rooms').doc(_currentRoomCode!).update({
        'chat_messages': FieldValue.arrayUnion([chatItem]),
      });
    } catch (_) {}
  }
}
