import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DiscoveredParty {
  final String roomCode;
  final String hostIp;
  final int port;
  final String hostName;
  final String deviceName;
  final String trackTitle;
  final String trackArtist;
  final String trackThumbnail;
  final bool isPlaying;
  final int membersCount;
  final DateTime lastSeen;

  DiscoveredParty({
    required this.roomCode,
    required this.hostIp,
    required this.port,
    required this.hostName,
    required this.deviceName,
    required this.trackTitle,
    required this.trackArtist,
    required this.trackThumbnail,
    required this.isPlaying,
    required this.membersCount,
    required this.lastSeen,
  });

  String get baseUrl => 'http://$hostIp:$port';
}

class PartyDiscoveryService extends ChangeNotifier {
  static final PartyDiscoveryService instance = PartyDiscoveryService._internal();
  factory PartyDiscoveryService() => instance;
  PartyDiscoveryService._internal();

  RawDatagramSocket? _socket;
  Timer? _cleanupTimer;
  final Map<String, DiscoveredParty> _parties = {};

  List<DiscoveredParty> get nearbyParties => _parties.values.toList();
  bool get hasNearbyParties => _parties.isNotEmpty;

  Future<void> startDiscovery() async {
    if (_socket != null) return;

    try {
      try {
        _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          8766,
          reuseAddress: true,
          reusePort: true,
        );
      } catch (_) {
        _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          8766,
          reuseAddress: true,
          reusePort: false,
        );
      }
      _socket?.broadcastEnabled = true;

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            _processBeacon(datagram);
          }
        }
      });

      _cleanupTimer?.cancel();
      _cleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        final now = DateTime.now();
        final expiredKeys = <String>[];
        for (var entry in _parties.entries) {
          if (now.difference(entry.value.lastSeen).inSeconds > 5) {
            expiredKeys.add(entry.key);
          }
        }
        if (expiredKeys.isNotEmpty) {
          for (var k in expiredKeys) {
            _parties.remove(k);
          }
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Party discovery bind error: $e');
    }
  }

  void _processBeacon(Datagram datagram) {
    try {
      final raw = utf8.decode(datagram.data);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['type'] != 'openaamps_party_beacon') return;

      final roomCode = json['room_code'] as String?;
      if (roomCode == null || roomCode.isEmpty) return;

      final hostIp = json['host_ip'] as String? ?? datagram.address.address;
      final port = json['port'] as int? ?? 8765;
      final hostName = json['host_name'] as String? ?? 'OpenAamps Host';
      final deviceName = json['device_name'] as String? ?? 'Phone';
      final trackTitle = json['track_title'] as String? ?? '';
      final trackArtist = json['track_artist'] as String? ?? '';
      final trackThumbnail = json['track_thumbnail'] as String? ?? '';
      final isPlaying = json['is_playing'] as bool? ?? false;
      final membersCount = json['members_count'] as int? ?? 1;

      _parties[roomCode] = DiscoveredParty(
        roomCode: roomCode,
        hostIp: hostIp,
        port: port,
        hostName: hostName,
        deviceName: deviceName,
        trackTitle: trackTitle,
        trackArtist: trackArtist,
        trackThumbnail: trackThumbnail,
        isPlaying: isPlaying,
        membersCount: membersCount,
        lastSeen: DateTime.now(),
      );

      notifyListeners();
    } catch (_) {}
  }

  void stopDiscovery() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _socket?.close();
    _socket = null;
    _parties.clear();
  }

  Future<String?> resolveHostBaseUrl(String inputCode) async {
    final cleaned = inputCode.trim().toUpperCase();
    if (cleaned.isEmpty) return null;

    // 1. Direct match in discovered nearby parties
    if (_parties.containsKey(cleaned)) {
      return _parties[cleaned]!.baseUrl;
    }

    for (var p in _parties.values) {
      if (p.roomCode.toUpperCase() == cleaned || p.roomCode.replaceAll('-', '') == cleaned.replaceAll('-', '')) {
        return p.baseUrl;
      }
    }

    // 2. User typed a direct IP or IP:port (e.g. 192.168.18.251 or 192.168.18.251:8765)
    final ipRegex = RegExp(r'^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(?::(\d+))?$');
    final ipMatch = ipRegex.firstMatch(inputCode.trim());
    if (ipMatch != null) {
      final ip = ipMatch.group(1)!;
      final port = ipMatch.group(2) ?? '8765';
      return 'http://$ip:$port';
    }

    // 3. User typed octet e.g. 159, JAM159, or JAM-159
    final octetRegex = RegExp(r'^(?:JAM-?|jam-?)?(\d{1,3})$', caseSensitive: false);
    final octetMatch = octetRegex.firstMatch(cleaned);
    if (octetMatch != null) {
      final octet = int.tryParse(octetMatch.group(1)!);
      if (octet != null && octet > 0 && octet <= 254) {
        final subnet = await _getLocalSubnetPrefix();
        if (subnet != null) {
          final candidateUrl = 'http://$subnet$octet:8765';
          final reachable = await _probeServer(candidateUrl);
          if (reachable) return candidateUrl;
        }
      }
    }

    // 4. Quick probe across discovered parties if code matches prefix or digits
    for (var p in _parties.values) {
      if (cleaned.contains(p.roomCode) || p.roomCode.contains(cleaned)) {
        return p.baseUrl;
      }
    }

    // 5. Targeted probe of known Pi server IPs on port 8765
    final subnet = await _getLocalSubnetPrefix();
    if (subnet != null) {
      for (final lastOctet in ['251', '159']) {
        final res = await _probeForRoom('http://$subnet$lastOctet:8765', cleaned);
        if (res != null) return res;
      }
    }

    return null;
  }

  Future<String?> _getLocalSubnetPrefix() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (var iface in interfaces) {
        for (var addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.contains('.')) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              return '${parts[0]}.${parts[1]}.${parts[2]}.';
            }
          }
        }
      }
    } catch (_) {}
    return '192.168.18.';
  }

  Future<bool> _probeServer(String baseUrl) async {
    try {
      final resp = await http.get(Uri.parse('$baseUrl/api/party/state')).timeout(const Duration(milliseconds: 600));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _probeForRoom(String baseUrl, String targetCode) async {
    try {
      final resp = await http.get(Uri.parse('$baseUrl/api/party/state')).timeout(const Duration(milliseconds: 350));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final code = (data['room']?['room_code'] as String?)?.toUpperCase();
        if (code == targetCode || targetCode.isEmpty || code?.replaceAll('-', '') == targetCode.replaceAll('-', '')) {
          return baseUrl;
        }
      }
    } catch (_) {}
    return null;
  }
}
