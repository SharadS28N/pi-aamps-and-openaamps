import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import 'party_service.dart';
import 'audio_player_service.dart';

class PartyHostServer {
  static final PartyHostServer instance = PartyHostServer._internal();
  factory PartyHostServer() => instance;
  PartyHostServer._internal();

  HttpServer? _server;
  RawDatagramSocket? _beaconSocket;
  Timer? _beaconTimer;
  final Set<WebSocket> _clientSockets = {};

  String? _roomCode;
  String? _hostId;
  String? _hostName;
  String _deviceName = 'Android Device';
  String _localIp = '127.0.0.1';
  int _port = 8765;

  bool _allowCollaborativeDj = true;
  bool _isPlaying = false;
  int _positionMs = 0;
  int _serverTimestampMs = 0;
  int _version = 1;

  final Map<String, PartyMemberModel> _members = {};
  final List<PartyTrackModel> _queue = [];
  final List<Map<String, dynamic>> _reactions = [];
  final List<Map<String, dynamic>> _chatMessages = [];
  Track? _currentTrack;

  bool get isRunning => _server != null;
  String? get roomCode => _roomCode;
  String get localIp => _localIp;
  int get port => _port;
  String get hostBaseUrl => 'http://$_localIp:$_port';

  Future<String> _resolveLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (var iface in interfaces) {
        for (var addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.contains('.')) {
            // Prioritize wlan / wifi interfaces
            if (iface.name.toLowerCase().contains('wlan') ||
                iface.name.toLowerCase().contains('wifi') ||
                addr.address.startsWith('192.168.') ||
                addr.address.startsWith('10.') ||
                addr.address.startsWith('172.')) {
              return addr.address;
            }
          }
        }
      }
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        return interfaces.first.addresses.first.address;
      }
    } catch (e) {
      debugPrint('Error resolving local IP: $e');
    }
    return '127.0.0.1';
  }

  Future<bool> start({
    required String hostId,
    required String hostName,
    required String deviceName,
    required String roomCode,
    Track? initialTrack,
  }) async {
    await stop();

    _hostId = hostId;
    _hostName = hostName;
    _deviceName = deviceName;
    _roomCode = roomCode;
    _localIp = await _resolveLocalIp();
    _currentTrack = initialTrack;
    _isPlaying = initialTrack != null;
    _positionMs = 0;
    _serverTimestampMs = DateTime.now().millisecondsSinceEpoch;
    _version = 1;

    _members.clear();
    _members[hostId] = PartyMemberModel(
      id: hostId,
      name: hostName,
      avatarUrl: '',
      deviceName: deviceName,
      role: 'host',
      isOnline: true,
    );

    _queue.clear();
    _reactions.clear();
    _chatMessages.clear();

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      debugPrint('PartyHostServer listening on http://$_localIp:$_port');

      _server!.listen(_handleHttpRequest, onError: (e) {
        debugPrint('PartyHostServer error: $e');
      });

      _startBeacon();
      return true;
    } catch (e) {
      debugPrint('Failed to bind PartyHostServer on port $_port: $e');
      // Try alternate port 8767
      try {
        _port = 8767;
        _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
        debugPrint('PartyHostServer listening on alternate port http://$_localIp:$_port');
        _server!.listen(_handleHttpRequest);
        _startBeacon();
        return true;
      } catch (err2) {
        debugPrint('Failed to bind on alternate port: $err2');
        return false;
      }
    }
  }

  void _startBeacon() async {
    _beaconTimer?.cancel();
    _beaconSocket?.close();
    try {
      _beaconSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _beaconSocket?.broadcastEnabled = true;

      _beaconTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!isRunning || _roomCode == null) return;
        try {
          final payload = jsonEncode({
            'type': 'openaamps_party_beacon',
            'room_code': _roomCode,
            'host_ip': _localIp,
            'port': _port,
            'host_name': _hostName,
            'device_name': _deviceName,
            'track_title': _currentTrack?.title ?? '',
            'track_artist': _currentTrack?.artist ?? '',
            'track_thumbnail': _currentTrack?.artworkUrl ?? '',
            'is_playing': _isPlaying,
            'members_count': _members.length,
          });
          final bytes = utf8.encode(payload);
          _beaconSocket?.send(bytes, InternetAddress('255.255.255.255'), 8766);
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('Error starting beacon: $e');
    }
  }

  Future<void> stop() async {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _beaconSocket?.close();
    _beaconSocket = null;

    for (var ws in _clientSockets) {
      try {
        ws.close(WebSocketStatus.normalClosure, 'Party ended');
      } catch (_) {}
    }
    _clientSockets.clear();

    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _roomCode = null;
  }

  Map<String, dynamic> toSnapshot() {
    return {
      'room_code': _roomCode ?? '',
      'host_id': _hostId ?? '',
      'host_name': _hostName ?? '',
      'device_name': _deviceName,
      'allow_collaborative_dj': _allowCollaborativeDj,
      'is_playing': _isPlaying,
      'position_ms': _positionMs,
      'server_timestamp_ms': _serverTimestampMs,
      'version': _version,
      'members': {
        for (var entry in _members.entries)
          entry.key: entry.value.toJson(),
      },
      'current_track': _currentTrack != null
          ? {
              'id': _currentTrack!.id,
              'title': _currentTrack!.title,
              'artist': _currentTrack!.artist,
              'thumbnail': _currentTrack!.artworkUrl,
              'duration': _currentTrack!.duration.inSeconds,
              'stream_url': AudioPlayerService.instance.getResolvedStreamUrl(_currentTrack!.id) ?? _currentTrack!.streamUrl,
            }
          : null,
      'queue': [
        for (var item in _queue)
          {
            'id': item.track.id,
            'title': item.track.title,
            'artist': item.track.artist,
            'thumbnail': item.track.artworkUrl,
            'duration': item.track.duration.inSeconds,
            'added_by': item.addedBy,
            'added_by_name': item.addedByName,
            'votes': item.votes,
            'voted_members': item.votedMembers,
          }
      ],
      'recent_reactions': List.from(_reactions),
      'chat_messages': List.from(_chatMessages),
    };
  }

  void broadcast(String eventType) {
    _version++;
    final payload = jsonEncode({
      'type': eventType,
      'data': toSnapshot(),
    });

    final toRemove = <WebSocket>[];
    for (var ws in _clientSockets) {
      try {
        ws.add(payload);
      } catch (_) {
        toRemove.add(ws);
      }
    }
    _clientSockets.removeAll(toRemove);
  }

  void broadcastCustom(String eventType, Map<String, dynamic> data) {
    final payload = jsonEncode({
      'type': eventType,
      'data': data,
    });

    final toRemove = <WebSocket>[];
    for (var ws in _clientSockets) {
      try {
        ws.add(payload);
      } catch (_) {
        toRemove.add(ws);
      }
    }
    _clientSockets.removeAll(toRemove);
  }

  Future<void> _handleHttpRequest(HttpRequest request) async {
    final response = request.response;
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.headers.add('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept');

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.ok;
      await response.close();
      return;
    }

    final path = request.uri.path;

    // 1. WebSocket Upgrade: /api/party/ws/:code
    if (path.startsWith('/api/party/ws')) {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        try {
          final ws = await WebSocketTransformer.upgrade(request);
          _clientSockets.add(ws);
          ws.add(jsonEncode({'type': 'init_party', 'data': toSnapshot()}));

          ws.listen(
            (msg) {
              if (msg == 'ping') {
                try {
                  ws.add(jsonEncode({'type': 'pong'}));
                } catch (_) {}
              }
            },
            onDone: () => _clientSockets.remove(ws),
            onError: (_) => _clientSockets.remove(ws),
          );
        } catch (e) {
          debugPrint('WS upgrade error: $e');
        }
        return;
      }
    }

    // Read JSON body for POST requests
    Map<String, dynamic> body = {};
    if (request.method == 'POST') {
      try {
        final content = await utf8.decoder.bind(request).join();
        if (content.isNotEmpty) {
          body = jsonDecode(content) as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    response.headers.contentType = ContentType.json;

    // 2. POST /api/party/join
    if (path == '/api/party/join') {
      final memberId = body['member_id'] ?? 'member_${DateTime.now().millisecondsSinceEpoch}';
      final memberName = body['member_name'] ?? 'Friend';
      final deviceName = body['device_name'] ?? 'Phone';
      final avatarUrl = body['avatar_url'] ?? '';

      _members[memberId] = PartyMemberModel(
        id: memberId,
        name: memberName,
        avatarUrl: avatarUrl,
        deviceName: deviceName,
        role: _allowCollaborativeDj ? 'dj' : 'listener',
        isOnline: true,
      );

      broadcast('member_joined');
      response.write(jsonEncode({'status': 'ok', 'room': toSnapshot()}));
      await response.close();
      return;
    }

    // 3. POST /api/party/:code/queue
    if (path.endsWith('/queue') && request.method == 'POST') {
      final tMap = body['track'] as Map<String, dynamic>?;
      if (tMap != null) {
        final track = Track(
          id: tMap['id'] ?? '',
          title: tMap['title'] ?? 'Unknown',
          artist: tMap['artist'] ?? 'Unknown Artist',
          album: '',
          duration: Duration(seconds: (tMap['duration'] as num?)?.toInt() ?? 0),
          artworkUrl: tMap['thumbnail'] ?? '',
          streamUrl: '',
        );

        final senderId = body['sender_id'] ?? '';
        final senderName = body['sender_name'] ?? 'Guest';

        _queue.add(PartyTrackModel(
          track: track,
          addedBy: senderId,
          addedByName: senderName,
          votes: 0,
          votedMembers: [],
        ));

        broadcast('queue_updated');
      }
      response.write(jsonEncode({'status': 'ok', 'room': toSnapshot()}));
      await response.close();
      return;
    }

    // 4. POST /api/party/:code/vote
    if (path.endsWith('/vote') && request.method == 'POST') {
      final trackId = body['track_id'] as String?;
      final senderId = body['sender_id'] as String?;

      if (trackId != null && senderId != null) {
        final index = _queue.indexWhere((q) => q.track.id == trackId);
        if (index != -1) {
          final item = _queue[index];
          final hasVoted = item.votedMembers.contains(senderId);
          final updatedVoters = List<String>.from(item.votedMembers);
          int updatedVotes = item.votes;

          if (hasVoted) {
            updatedVoters.remove(senderId);
            updatedVotes = (updatedVotes - 1).clamp(0, 999);
          } else {
            updatedVoters.add(senderId);
            updatedVotes += 1;
          }

          _queue[index] = PartyTrackModel(
            track: item.track,
            addedBy: item.addedBy,
            addedByName: item.addedByName,
            votes: updatedVotes,
            votedMembers: updatedVoters,
          );

          _queue.sort((a, b) => b.votes.compareTo(a.votes));
          broadcast('queue_updated');
        }
      }
      response.write(jsonEncode({'status': 'ok', 'room': toSnapshot()}));
      await response.close();
      return;
    }

    // 5. POST /api/party/:code/playback
    if (path.endsWith('/playback') && request.method == 'POST') {
      final tMap = body['track'] as Map<String, dynamic>?;
      if (tMap != null) {
        _currentTrack = Track(
          id: tMap['id'] ?? '',
          title: tMap['title'] ?? 'Unknown',
          artist: tMap['artist'] ?? 'Unknown Artist',
          album: '',
          duration: Duration(seconds: (tMap['duration'] as num?)?.toInt() ?? 0),
          artworkUrl: tMap['thumbnail'] ?? '',
          streamUrl: '',
        );
      }
      _positionMs = body['position_ms'] ?? _positionMs;
      _isPlaying = body['is_playing'] ?? _isPlaying;
      _serverTimestampMs = DateTime.now().millisecondsSinceEpoch;

      broadcast('playback_updated');
      response.write(jsonEncode({'status': 'ok', 'room': toSnapshot()}));
      await response.close();
      return;
    }

    // 6. POST /api/party/:code/skip
    if (path.endsWith('/skip') && request.method == 'POST') {
      if (_queue.isNotEmpty) {
        final next = _queue.removeAt(0);
        _currentTrack = next.track;
        _positionMs = 0;
        _isPlaying = true;
        _serverTimestampMs = DateTime.now().millisecondsSinceEpoch;
        broadcast('playback_updated');
      }
      response.write(jsonEncode({'status': 'ok', 'room': toSnapshot()}));
      await response.close();
      return;
    }

    // 7. POST /api/party/:code/leave
    if (path.endsWith('/leave') && request.method == 'POST') {
      final memberId = request.uri.queryParameters['member_id'] ?? body['member_id'];
      if (memberId != null) {
        _members.remove(memberId);
        broadcast('member_left');
      }
      response.write(jsonEncode({'status': 'ok', 'room': toSnapshot()}));
      await response.close();
      return;
    }

    // 8. POST /api/party/:code/dj-mode
    if (path.endsWith('/dj-mode') && request.method == 'POST') {
      _allowCollaborativeDj = body['allow_collaborative_dj'] ?? true;
      broadcast('room_settings_updated');
      response.write(jsonEncode({'status': 'ok', 'room': toSnapshot()}));
      await response.close();
      return;
    }

    // 9. POST /api/party/:code/reaction
    if (path.endsWith('/reaction') && request.method == 'POST') {
      final senderName = body['sender_name'] ?? 'Friend';
      final reaction = body['reaction'] ?? 'fire';
      final label = body['label'] ?? 'Fire';
      final rx = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'sender_name': senderName,
        'reaction': reaction,
        'label': label,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      _reactions.insert(0, rx);
      if (_reactions.length > 20) _reactions.removeLast();
      broadcastCustom('party_reaction', rx);
      response.write(jsonEncode({'status': 'ok', 'reaction': rx}));
      await response.close();
      return;
    }

    // 10. POST /api/party/:code/chat
    if (path.endsWith('/chat') && request.method == 'POST') {
      final senderName = body['sender_name'] ?? 'Friend';
      final senderId = body['sender_id'] ?? '';
      final message = body['message'] ?? '';
      final chatItem = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'sender_id': senderId,
        'sender_name': senderName,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      _chatMessages.add(chatItem);
      if (_chatMessages.length > 50) _chatMessages.removeAt(0);
      broadcastCustom('party_chat', chatItem);
      response.write(jsonEncode({'status': 'ok', 'chat': chatItem}));
      await response.close();
      return;
    }

    // 11. GET /api/party/:code/state or /api/party/state
    if (path.contains('/state') && request.method == 'GET') {
      response.write(jsonEncode({'status': 'ok', 'room': toSnapshot()}));
      await response.close();
      return;
    }

    // Default 404
    response.statusCode = HttpStatus.notFound;
    response.write(jsonEncode({'error': 'Not found'}));
    await response.close();
  }

  void updatePlaybackState({
    required Track? track,
    required int positionMs,
    required bool isPlaying,
  }) {
    if (!isRunning) return;
    _currentTrack = track;
    _positionMs = positionMs;
    _isPlaying = isPlaying;
    _serverTimestampMs = DateTime.now().millisecondsSinceEpoch;
    broadcast('playback_updated');
  }

  void addQueueItem(Track track, String senderId, String senderName) {
    if (!isRunning) return;
    _queue.add(PartyTrackModel(
      track: track,
      addedBy: senderId,
      addedByName: senderName,
      votes: 0,
      votedMembers: [],
    ));
    broadcast('queue_updated');
  }

  void voteTrackItem(String trackId, String senderId) {
    if (!isRunning) return;
    final index = _queue.indexWhere((q) => q.track.id == trackId);
    if (index != -1) {
      final item = _queue[index];
      final hasVoted = item.votedMembers.contains(senderId);
      final updatedVoters = List<String>.from(item.votedMembers);
      int updatedVotes = item.votes;

      if (hasVoted) {
        updatedVoters.remove(senderId);
        updatedVotes = (updatedVotes - 1).clamp(0, 999);
      } else {
        updatedVoters.add(senderId);
        updatedVotes += 1;
      }

      _queue[index] = PartyTrackModel(
        track: item.track,
        addedBy: item.addedBy,
        addedByName: item.addedByName,
        votes: updatedVotes,
        votedMembers: updatedVoters,
      );

      _queue.sort((a, b) => b.votes.compareTo(a.votes));
      broadcast('queue_updated');
    }
  }

  void skipToNextTrack() {
    if (!isRunning) return;
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      _currentTrack = next.track;
      _positionMs = 0;
      _isPlaying = true;
      _serverTimestampMs = DateTime.now().millisecondsSinceEpoch;
      broadcast('playback_updated');
    }
  }

  void setCollaborativeDj(bool allow) {
    if (!isRunning) return;
    _allowCollaborativeDj = allow;
    broadcast('room_settings_updated');
  }
}
