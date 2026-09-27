import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/track.dart';
import '../services/party_service.dart';
import '../services/party_discovery_service.dart';
import '../services/audio_player_service.dart';
import '../services/account_service.dart';
import '../services/youtube_service.dart';
import '../services/settings_service.dart';
import '../widgets/app_alert.dart';

class PartyView extends StatefulWidget {
  final AudioPlayerService? audioService;

  const PartyView({
    super.key,
    this.audioService,
  });

  @override
  State<PartyView> createState() => _PartyViewState();
}

class _PartyViewState extends State<PartyView> {
  final PartyService _party = PartyService.instance;
  final AccountService _account = AccountService.instance;
  late AudioPlayerService _audio;

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<Track> _searchResults = [];
  bool _isLoadingSearch = false;

  @override
  void initState() {
    super.initState();
    _audio = widget.audioService ?? AudioPlayerService.instance;
    _party.addListener(_onPartyUpdate);
    PartyDiscoveryService.instance.addListener(_onPartyUpdate);
    PartyDiscoveryService.instance.startDiscovery();
  }

  void _onPartyUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _party.removeListener(_onPartyUpdate);
    PartyDiscoveryService.instance.removeListener(_onPartyUpdate);
    _codeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddTrackSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.playlist_add_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Add Song to Party Queue',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search title, artist or paste YouTube URL...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF27272A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (query) async {
                  if (query.trim().isEmpty) return;
                  setSheetState(() => _isLoadingSearch = true);
                  final results = await YoutubeService().searchTracks(query.trim());
                  setSheetState(() {
                    _searchResults = results;
                    _isLoadingSearch = false;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_isLoadingSearch)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                )
              else if (_searchResults.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.45),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final track = _searchResults[idx];
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: const Color(0xFF1E1E24),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: track.artworkUrl.isNotEmpty
                              ? Image.network(track.artworkUrl, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (context, error, stack) => const Icon(Icons.music_note, color: Colors.white54))
                              : const Icon(Icons.music_note, color: Colors.white54),
                        ),
                        title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                          tooltip: 'Add to Party',
                          onPressed: () {
                            _party.addToPartyQueue(track);
                            Navigator.pop(ctx);
                            AppAlert.show(this.context, 'Added "${track.title}" to Party Queue', icon: Icons.check_circle_rounded, isSuccess: true);
                          },
                        ),
                      );
                    },
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('Type a song name and tap enter to search', style: TextStyle(color: Colors.white38, fontSize: 13)),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        final accent = SettingsService.instance.accentColor;
        return Scaffold(
          backgroundColor: const Color(0xFF000000),
          appBar: AppBar(
            backgroundColor: const Color(0xFF000000),
            elevation: 0,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: Row(
              children: [
                Icon(Icons.speaker_group_rounded, color: accent, size: 22),
                const SizedBox(width: 10),
                const Text('Music Party & Jam', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            actions: [
              if (_party.isInParty)
                IconButton(
                  icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
                  tooltip: 'Leave Party',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF18181B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Leave Music Party?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        content: const Text('You will disconnect from this synchronized session. Your audio will pause locally.', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Leave'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _party.leaveParty();
                    }
                  },
                ),
            ],
          ),
          body: _party.isInParty ? _buildActivePartyView(accent) : _buildLobbyView(accent),
        );
      },
    );
  }

  // --- 1. LOBBY VIEW (Not in party) ---
  Widget _buildLobbyView(Color accent) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Hero Card: How it works
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.12),
                const Color(0xFF141416),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sync_rounded, color: accent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'TIMESTAMP DRIFT SYNC ENGINE',
                      style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Listen Together in Real Time',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connect Bluetooth earbuds or phone speakers. OpenAamps synchronizes track playback and queue changes across all devices in real-time over Wi-Fi.',
                style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Nearby Parties on Local Wi-Fi (Auto-Detected)
        if (PartyDiscoveryService.instance.hasNearbyParties) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'NEARBY PARTIES ON WI-FI',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        '${PartyDiscoveryService.instance.nearbyParties.length} ACTIVE',
                        style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...PartyDiscoveryService.instance.nearbyParties.map((party) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E24),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: party.trackThumbnail.isNotEmpty
                              ? Image.network(
                                  party.trackThumbnail,
                                  width: 46,
                                  height: 46,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) => const Icon(Icons.music_note, color: Colors.white54),
                                )
                              : const Icon(Icons.speaker_group_rounded, color: Colors.white70, size: 30),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      party.hostName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      party.roomCode,
                                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                party.trackTitle.isNotEmpty
                                    ? '${party.trackTitle} • ${party.trackArtist}'
                                    : '${party.deviceName} • Tap to join',
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _party.isConnecting
                              ? null
                              : () async {
                                  final success = await _party.joinParty(party.roomCode);
                                  if (success && mounted) {
                                    AppAlert.show(context, 'Joined ${party.hostName}\'s party!', icon: Icons.check_circle_rounded, isSuccess: true);
                                  } else if (mounted) {
                                    AppAlert.show(context, 'Could not join party. Retrying...', icon: Icons.error_outline_rounded, isSuccess: false);
                                  }
                                },
                          child: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Listening for nearby Wi-Fi Jam Sessions...',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Action 1: Host a New Party
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'START A NEW SESSION',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _party.isConnecting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_circle_rounded, size: 20),
                  label: Text(
                    _party.isConnecting ? 'Starting Party...' : 'Host a Music Party',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: _party.isConnecting
                      ? null
                      : () async {
                          final success = await _party.createParty(initialTrack: _audio.currentTrack);
                          if (success && mounted) {
                            AppAlert.show(context, 'Party started! Share room code "${_party.currentRoomCode}"', icon: Icons.celebration_rounded, isSuccess: true);
                          }
                        },
                ),
              ),
              if (_account.activeAccount.isCoupleProfile) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 18),
                    label: Text(
                      'Listen with ${_account.activeAccount.partnerName} (Couple Mode)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () async {
                      final success = await _account.startCoupleListenTogether(track: _audio.currentTrack);
                      if (success && mounted) {
                        AppAlert.show(context, 'Couple Session started with ${_account.activeAccount.partnerName}', icon: Icons.favorite_rounded, isSuccess: true);
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action 2: Join Existing Party with Room Code
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'JOIN WITH ROOM CODE',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                      decoration: InputDecoration(
                        hintText: 'e.g. JAM-251 or 251',
                        hintStyle: const TextStyle(color: Colors.white30, letterSpacing: 1.0),
                        filled: true,
                        fillColor: const Color(0xFF27272A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _party.isConnecting
                          ? null
                          : () async {
                              final code = _codeController.text.trim();
                              if (code.isEmpty) return;
                              final success = await _party.joinParty(code);
                              if (success && mounted) {
                                AppAlert.show(context, 'Joined party $code!', icon: Icons.check_circle_rounded, isSuccess: true);
                              } else if (mounted) {
                                AppAlert.show(context, 'Could not join party. Check room code or Wi-Fi.', icon: Icons.error_outline_rounded, isSuccess: false);
                              }
                            },
                      child: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Tip: You can enter the full code (JAM-251), the last digits (251), or host IP directly.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 2. ACTIVE PARTY VIEW (In party session) ---
  Widget _buildActivePartyView(Color accent) {
    final currentTrack = _party.partyCurrentTrack ?? _audio.currentTrack;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Room Code Banner & Copy
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ROOM CODE', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      const SizedBox(height: 2),
                      Text(_party.currentRoomCode ?? 'JAM-0000', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white),
                    tooltip: 'Copy Code',
                    onPressed: () {
                      if (_party.currentRoomCode != null) {
                        Clipboard.setData(ClipboardData(text: _party.currentRoomCode!));
                        AppAlert.show(context, 'Room code copied to clipboard', icon: Icons.copy_rounded, isSuccess: true);
                      }
                    },
                  ),
                ],
              ),
              if (_party.activePartyBaseUrl != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.wifi_rounded, color: accent, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _party.isHost
                            ? 'Hosting on Wi-Fi (${_party.activePartyBaseUrl!.replaceAll('http://', '')})'
                            : 'Host IP: ${_party.activePartyBaseUrl!.replaceAll('http://', '')}',
                        style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Live Sync Status Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Synchronized (${_party.driftMs}ms drift)',
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.headphones_rounded, color: accent, size: 16),
                  const SizedBox(width: 4),
                  const Text('Local Audio Active', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Host Permissions Toggle
        if (_party.isHost)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.group_work_rounded, color: Colors.white70, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Collaborative DJ (Anyone can skip/play)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: _party.allowCollaborativeDj,
                  activeThumbColor: accent,
                  onChanged: (val) => _party.toggleCollaborativeDj(val),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // Participants Avatars Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PARTICIPANTS (${_party.members.length})', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _party.members.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, idx) {
              final m = _party.members[idx];
              return Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: m.avatarUrl.isNotEmpty ? NetworkImage(m.avatarUrl) : null,
                        backgroundColor: const Color(0xFF27272A),
                        child: m.avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                      ),
                      if (m.role == 'host')
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                            child: const Icon(Icons.star, size: 10, color: Colors.black),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11)),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // Now Playing Card
        if (currentTrack != null) ...[
          const Text('NOW PLAYING IN PARTY', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: currentTrack.artworkUrl.isNotEmpty
                      ? Image.network(currentTrack.artworkUrl, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (context, error, stack) => const Icon(Icons.music_note, color: Colors.white54, size: 30))
                      : const Icon(Icons.music_note, color: Colors.white54, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentTrack.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(currentTrack.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                if (_party.canControlPlayback) ...[
                  IconButton(
                    icon: Icon(_audio.player.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: accent, size: 38),
                    onPressed: () {
                      if (_audio.player.playing) {
                        _audio.pause();
                      } else {
                        _audio.resume();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
                    tooltip: 'Skip to Next',
                    onPressed: () => _party.skipPartyTrack(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Live Party Reactions & Chat
        _buildPartyVibesAndReactionsBar(accent),

        // Collaborative Queue
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('SHARED QUEUE (${_party.partyQueue.length})', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            TextButton.icon(
              icon: Icon(Icons.add_rounded, size: 16, color: accent),
              label: Text('Add Song', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: _showAddTrackSheet,
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_party.partyQueue.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.queue_music_rounded, color: Colors.white38, size: 36),
                  const SizedBox(height: 8),
                  const Text('Party queue is empty', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27272A), foregroundColor: Colors.white),
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: const Text('Search & Add Tracks'),
                    onPressed: _showAddTrackSheet,
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _party.partyQueue.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final qItem = _party.partyQueue[idx];
              final hasVoted = qItem.votedMembers.contains(_account.activeAccount.id);

              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: const Color(0xFF141414),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: qItem.track.artworkUrl.isNotEmpty
                      ? Image.network(qItem.track.artworkUrl, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (context, error, stack) => const Icon(Icons.music_note, color: Colors.white54))
                      : const Icon(Icons.music_note, color: Colors.white54),
                ),
                title: Text(qItem.track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('${qItem.track.artist} • Added by ${qItem.addedByName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                trailing: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: hasVoted ? accent.withValues(alpha: 0.15) : Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                  ),
                  icon: Icon(Icons.thumb_up_alt_rounded, size: 16, color: hasVoted ? accent : Colors.white54),
                  label: Text('${qItem.votes}', style: TextStyle(color: hasVoted ? accent : Colors.white54, fontWeight: FontWeight.bold)),
                  onPressed: () => _party.voteQueueTrack(qItem.track.id),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildPartyVibesAndReactionsBar(Color accent) {
    final recentRx = _party.recentReactions.isNotEmpty ? _party.recentReactions.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recentRx != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                _getReactionIcon(recentRx['reaction'] ?? '', 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${recentRx['sender_name']} reacted with ${recentRx['label'] ?? 'Vibe'}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'LIVE REACTIONS & CHAT',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
              icon: Icon(Icons.forum_rounded, size: 15, color: accent),
              label: Text(
                'Party Chat (${_party.chatMessages.length})',
                style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showPartyChatSheet(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildReactionButton('fire', 'Fire', Icons.local_fire_department_rounded, Colors.deepOrangeAccent),
              _buildReactionButton('love', 'Love', Icons.favorite_rounded, Colors.pinkAccent),
              _buildReactionButton('vibe', 'Vibe', Icons.music_note_rounded, Colors.cyanAccent),
              _buildReactionButton('clap', 'Clap', Icons.thumb_up_alt_rounded, Colors.amber),
              _buildReactionButton('hype', 'Hype', Icons.bolt_rounded, Colors.yellowAccent),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70, size: 20),
                tooltip: 'Send Message',
                onPressed: () => _showPartyChatSheet(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildReactionButton(String type, String label, IconData icon, Color color) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await _party.sendReaction(type, label);
        if (mounted) {
          AppAlert.show(context, 'Sent $label reaction', icon: icon, isSuccess: true);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _getReactionIcon(String type, double size) {
    switch (type) {
      case 'fire':
        return Icon(Icons.local_fire_department_rounded, color: Colors.deepOrangeAccent, size: size);
      case 'love':
        return Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: size);
      case 'vibe':
        return Icon(Icons.music_note_rounded, color: Colors.cyanAccent, size: size);
      case 'clap':
        return Icon(Icons.thumb_up_alt_rounded, color: Colors.amber, size: size);
      case 'hype':
        return Icon(Icons.bolt_rounded, color: Colors.yellowAccent, size: size);
      default:
        return Icon(Icons.local_fire_department_rounded, color: Colors.deepOrangeAccent, size: size);
    }
  }

  void _showPartyChatSheet(BuildContext context) {
    final TextEditingController chatInputController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.65,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF141416),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.forum_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text('Live Party Chat & Shoutouts', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _party,
                    builder: (context, _) {
                      final msgs = _party.chatMessages;
                      if (msgs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white24, size: 40),
                              const SizedBox(height: 8),
                              const Text('No messages yet', style: TextStyle(color: Colors.white38, fontSize: 13)),
                              const SizedBox(height: 4),
                              const Text('Send a shoutout to everyone listening together!', style: TextStyle(color: Colors.white24, fontSize: 11)),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        reverse: false,
                        itemCount: msgs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final msg = msgs[index];
                          final isMe = msg['sender_id'] == _account.activeAccount.id;
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? const Color(0xFF27272A) : const Color(0xFF1E1E22),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: isMe ? 0.15 : 0.06)),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg['sender_name'] ?? 'Member',
                                    style: TextStyle(
                                      color: isMe ? Colors.white70 : const Color(0xFF818CF8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    msg['message'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: chatInputController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Type a shoutout...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFF27272A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (text) async {
                          if (text.trim().isNotEmpty) {
                            await _party.sendChatMessage(text.trim());
                            chatInputController.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      onPressed: () async {
                        final text = chatInputController.text.trim();
                        if (text.isNotEmpty) {
                          await _party.sendChatMessage(text);
                          chatInputController.clear();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
