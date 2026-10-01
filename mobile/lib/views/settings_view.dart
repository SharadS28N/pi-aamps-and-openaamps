import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/account_service.dart';
import '../services/audio_player_service.dart';
import '../services/integration_service.dart';
import '../services/settings_service.dart';
import '../widgets/account_switcher_modal.dart';
import '../widgets/account_sync_modal.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/app_alert.dart';
import '../services/update_service.dart';
import 'ai/ai_studio_view.dart';

class SettingsView extends StatefulWidget {
  final AudioPlayerService? audioService;

  const SettingsView({
    super.key,
    this.audioService,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final AccountService _account = AccountService.instance;
  final IntegrationService _integration = IntegrationService.instance;
  final SettingsService _settings = SettingsService.instance;
  late AudioPlayerService _audio;
  late TextEditingController _customWallpaperInputCtrl;
  late TextEditingController _geminiKeyCtrl;

  @override
  void initState() {
    super.initState();
    _audio = widget.audioService ?? AudioPlayerService();
    _customWallpaperInputCtrl = TextEditingController(text: _settings.customWallpaperUrl);
    _geminiKeyCtrl = TextEditingController(text: _settings.geminiApiKey);
    _settings.addListener(_onSettingsChange);
  }

  void _onSettingsChange() {
    if (mounted) {
      if (_customWallpaperInputCtrl.text != _settings.customWallpaperUrl) {
        _customWallpaperInputCtrl.text = _settings.customWallpaperUrl;
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChange);
    _customWallpaperInputCtrl.dispose();
    _geminiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Settings & Preferences',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Section 1: Active Account & Profile
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: const Color(0xFF141414),
            leading: CircleAvatar(
              radius: 22,
              backgroundImage: NetworkImage(_account.activeAccount.avatarUrl),
            ),
            title: Text(
              _account.activeAccount.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${_account.activeAccount.email} • YouTube Music Active',
              style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
            ),
            trailing: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => AccountSwitcherModal(accountService: _account),
              ).then((_) => setState(() {}));
            },
          ),
          const SizedBox(height: 24),

          // Section 2: Player Theme & Aesthetics Customization
          const Text(
            'PLAYER THEME & CANVAS CUSTOMIZATION',
            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),

          // Player Style Dropdown & Picker
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFF141414),
            leading: const Icon(Icons.style_rounded, color: Colors.white),
            title: const Text('Player Style Theme', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              _settings.playerStyle.name.toUpperCase(),
              style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
            ),
            trailing: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 28),
            onTap: () => _showPlayerStylePicker(context),
          ),
          const SizedBox(height: 10),

          // Background Style Dropdown & Picker
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFF141414),
            leading: const Icon(Icons.wallpaper_rounded, color: Colors.white),
            title: const Text('Background Canvas Style', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              _settings.backgroundStyle.name.toUpperCase(),
              style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
            ),
            trailing: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 28),
            onTap: () => _showBackgroundStylePicker(context),
          ),
          const SizedBox(height: 10),

          // Accent Color Vibe Picker
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Accent Color Vibe',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _settings.accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Default is authentic monochrome Spotify black & white. Any color vibe is optional.',
                  style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildAccentVibeChip(AccentVibe.spotifyGreen, 'Spotify Green', const Color(0xFF1DB954)),
                    _buildAccentVibeChip(AccentVibe.electricRed, 'Electric Red', const Color(0xFFEF4444)),
                    _buildAccentVibeChip(AccentVibe.cyberCyan, 'Cyber Cyan', const Color(0xFF00F2FE)),
                    _buildAccentVibeChip(AccentVibe.amberGold, 'Amber Gold', const Color(0xFFFFB800)),
                    _buildAccentVibeChip(AccentVibe.monochromeWhite, 'Monochrome White', Colors.white),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Active Wallpaper Canvas Preview Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.photo_size_select_actual_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Active Custom Wallpaper Canvas',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Renders live on the music player canvas and ambient home backdrop.',
                  style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Image.network(
                        _settings.customWallpaperUrl,
                        height: 110,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        headers: const {
                          'User-Agent':
                              'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Mobile Safari/537.36',
                        },
                        errorBuilder: (_, _, _) => Container(
                          height: 110,
                          color: const Color(0xFF222222),
                          child: const Center(
                            child: Icon(Icons.broken_image_rounded, color: Colors.white38),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Text(
                            'LIVE PREVIEW',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _settings.customWallpaperUrl,
                  style: const TextStyle(color: Color(0xFF727272), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SettingsService.defaultWallpapers.map((wp) {
                    final isSel = _settings.customWallpaperUrl == wp['url'];
                    return ChoiceChip(
                      label: Text(wp['name'] ?? ''),
                      selected: isSel,
                      selectedColor: Colors.white,
                      backgroundColor: const Color(0xFF242424),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.black : Colors.white,
                        fontSize: 11,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        _settings.setCustomWallpaperUrl(wp['url'] ?? '');
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Custom URL input
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF242424),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: TextField(
                          controller: _customWallpaperInputCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: const InputDecoration(
                            hintText: 'Paste custom image / Reddit URL',
                            hintStyle: TextStyle(color: Color(0xFF727272), fontSize: 11),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        final text = _customWallpaperInputCtrl.text.trim();
                        if (text.isNotEmpty) {
                          _settings.setCustomWallpaperUrl(text);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Custom wallpaper applied!')),
                          );
                        }
                      },
                      child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Show Ambient Wallpaper on Home Switch
          SwitchListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFF141414),
            secondary: const Icon(Icons.home_rounded, color: Colors.white),
            title: const Text('Show Wallpaper on Home Screen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('Displays a subtle ambient backdrop behind top header', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
            value: _settings.showWallpaperOnHome,
            activeTrackColor: Colors.white38,
            activeThumbColor: Colors.white,
            onChanged: (val) {
              _settings.setShowWallpaperOnHome(val);
              setState(() {});
            },
          ),
          const SizedBox(height: 28),

          // Section 3: Audio Engine & DSP Controls
          const Text(
            'AUDIO ENGINE & DSP CONTROLS',
            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),

          // Equalizer DSP Preset
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFF141414),
            leading: const Icon(Icons.graphic_eq_rounded, color: Colors.white),
            title: const Text('Equalizer DSP Preset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              _settings.equalizerPreset.name.toUpperCase(),
              style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
            ),
            trailing: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 28),
            onTap: () => _showEqualizerPicker(context),
          ),
          const SizedBox(height: 10),

          // Playback Speed Slider
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFF141414),
            leading: const Icon(Icons.speed_rounded, color: Colors.white),
            title: Text('Playback Speed (${_settings.playbackSpeed.toStringAsFixed(2)}x)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 3,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Color(0xFF27272A),
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: _settings.playbackSpeed,
                min: 0.5,
                max: 2.0,
                divisions: 6,
                onChanged: (val) {
                  _settings.setPlaybackSpeed(val);
                  _audio.setPlaybackSpeed(val);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Pitch Shifter Slider
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFF141414),
            leading: const Icon(Icons.music_note_rounded, color: Colors.white),
            title: Text('Pitch Shifter (${_settings.pitch.toStringAsFixed(2)}x)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 3,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Color(0xFF27272A),
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: _settings.pitch,
                min: 0.5,
                max: 1.5,
                divisions: 10,
                onChanged: (val) {
                  _settings.setPitch(val);
                  _audio.setPitch(val);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Crossfade Duration Slider
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFF141414),
            leading: const Icon(Icons.tune_rounded, color: Colors.white),
            title: Text('Crossfade Duration (${_settings.crossfadeDuration.toInt()}s)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 3,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Color(0xFF27272A),
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: _settings.crossfadeDuration,
                min: 0.0,
                max: 12.0,
                divisions: 12,
                onChanged: (val) {
                  _settings.setCrossfade(val);
                  _audio.setCrossfade(val);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Loudness Normalization Toggle
          SwitchListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFF141414),
            secondary: const Icon(Icons.equalizer_rounded, color: Colors.white),
            title: const Text('EBU R128 Loudness Normalization', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('Balances dynamic volume ranges to target -14 LUFS', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
            value: _settings.loudnessNormalization,
            activeTrackColor: Colors.white38,
            activeThumbColor: Colors.white,
            onChanged: (val) {
              _settings.setLoudnessNormalization(val);
              _audio.setLoudnessNormalization(val);
            },
          ),
          const SizedBox(height: 28),

          // Section 4: Notification & System Media Controls
          const Text(
            'NOTIFICATION & SYSTEM MEDIA CONTROLS',
            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),

          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFF141414),
            leading: const Icon(Icons.notifications_active_rounded, color: Colors.white),
            title: const Text('Status Bar & Lock Screen Media Player', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('Always display real-time playback controls, scrubber & artwork in notification shade', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            onTap: () async {
              final status = await Permission.notification.status;
              if (!status.isGranted) {
                final req = await Permission.notification.request();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(req.isGranted ? 'Notification permissions granted!' : 'Permission denied. Please enable notifications in Android Settings.'),
                      backgroundColor: const Color(0xFF222222),
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notification & Lock Screen controls are active and granted.'),
                      backgroundColor: Color(0xFF222222),
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 28),

          // Section: Offline Storage & Direct-Saving Cache (Survey Priority)
          const Text(
            'OFFLINE STORAGE & DIRECT-SAVING CACHE',
            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),

          SwitchListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFF141414),
            secondary: const Icon(Icons.download_for_offline_rounded, color: Colors.white),
            title: const Text('Auto-Download Favorited Tracks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('Directly saves tracks to local offline storage when liked for 0ms playback', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
            value: _settings.autoDownloadFavorites,
            activeTrackColor: Colors.white38,
            activeThumbColor: Colors.white,
            onChanged: (val) => _settings.setAutoDownloadFavorites(val),
          ),
          const SizedBox(height: 10),

          SwitchListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFF141414),
            secondary: const Icon(Icons.cached_rounded, color: Colors.white),
            title: const Text('Direct-Cache on Playback', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('Pre-buffers and saves stream to phone storage on first play for 0ms reload', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
            value: _settings.autoCacheOnPlay,
            activeTrackColor: Colors.white38,
            activeThumbColor: Colors.white,
            onChanged: (val) => _settings.setAutoCacheOnPlay(val),
          ),
          const SizedBox(height: 28),

          // Section: AI Music Studio & Gemini AI Studio Settings
          const Text(
            'AI MUSIC STUDIO & GOOGLE AI STUDIO (GEMINI)',
            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),

          // Launch AI Studio
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFF141414),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Center(
                child: Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 20),
              ),
            ),
            title: const Text('Launch AI Music Studio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('Deconstruct stems, detect instruments, and query musical DNA', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AiStudioView(
                    audioService: _audio,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // Gemini API Key Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF24242A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.vpn_key_rounded, color: Colors.white70, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Google AI Studio API Key (Gemini)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Powers real-time deep acoustic musicology and instrument analysis. Free keys available at aistudio.google.com. (Built-in acoustic intelligence runs if left blank).',
                  style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, height: 1.3),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C24),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2C2C38)),
                        ),
                        child: TextField(
                          controller: _geminiKeyCtrl,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Paste AI Studio API Key (AIzaSy...)',
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _settings.accentColor == Colors.white ? const Color(0xFF2A2A38) : _settings.accentColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onPressed: () async {
                        await _settings.setGeminiApiKey(_geminiKeyCtrl.text.trim());
                        if (context.mounted) {
                          AppAlert.show(
                            context,
                            _geminiKeyCtrl.text.trim().isNotEmpty
                                ? 'AI Studio Gemini Key Saved'
                                : 'Cleared Gemini Key (using Acoustic AI)',
                            icon: Icons.check_circle_rounded,
                            isSuccess: true,
                          );
                        }
                      },
                      child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Section 4: Scrobblers & Integrations
          const Text(
            'ACCOUNT & CLOUD SYNCHRONIZATION (SPOTIFY & YOUTUBE)',
            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),

          // Spotify & YouTube Account Connection Tile
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFF141414),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Center(
                child: Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 20),
              ),
            ),
            title: const Text('Spotify & YouTube Sync Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              'Spotify: ${_integration.spotifyConnected ? "@${_integration.spotifyUsername}" : "Not linked"} • YouTube: ${_integration.youtubeConnected ? _integration.youtubeChannelHandle : "Not linked"}',
              style: const TextStyle(
                color: Color(0xFFA1A1AA),
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => const AccountSyncModal(),
              ).then((_) => setState(() {}));
            },
          ),
          const SizedBox(height: 10),

          // Last.fm Scrobbler Toggle
          SwitchListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFF141414),
            secondary: const Icon(Icons.graphic_eq_rounded, color: Colors.white),
            title: const Text('Last.fm Scrobbler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('Connected as @${_integration.lastFmUsername}', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
            value: _integration.lastFmEnabled,
            activeTrackColor: Colors.white38,
            activeThumbColor: Colors.white,
            onChanged: (val) => _integration.toggleLastFm(val),
          ),
          const SizedBox(height: 10),

          // ListenBrainz Sync Toggle
          SwitchListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFF141414),
            secondary: const Icon(Icons.headphones_rounded, color: Colors.white),
            title: const Text('ListenBrainz Sync', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('Submit listens automatically on 50% track completion', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
            value: _integration.listenBrainzEnabled,
            activeTrackColor: Colors.white38,
            activeThumbColor: Colors.white,
            onChanged: (val) => _integration.toggleListenBrainz(val),
          ),
          const SizedBox(height: 10),

          // Discord Rich Presence Toggle
          SwitchListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0xFF141414),
            secondary: const Icon(Icons.discord_rounded, color: Colors.white),
            title: const Text('Discord Rich Presence (RPC)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('Display real-time playing status on Discord profile', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
            value: _integration.discordRpcEnabled,
            activeTrackColor: Colors.white38,
            activeThumbColor: Colors.white,
            onChanged: (val) => _integration.toggleDiscordRpc(val),
          ),
          const SizedBox(height: 28),

          // Section 5: Autonomous Music Intelligence
          _buildAiIntelligenceSection(context),
          const SizedBox(height: 28),

          // Section 6: App Updates & Version Control
          _buildAppUpdateSection(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAiIntelligenceSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AUTONOMOUS ON-DEVICE ACOUSTIC AI',
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OpenAamps Neural Acoustic Engine',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'Active • Zero Cloud Credentials Required',
                          style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'High-performance on-device music reasoning model actively analyzing harmonic keys, BPM matching, 5-band audio equalizers, and natural language playback requests.',
                style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildAiBadge('Tempo & BPM Matching'),
                  _buildAiBadge('FLAC & Bitrate Analysis'),
                  _buildAiBadge('Chord Theory & Keys'),
                  _buildAiBadge('100% Private & Offline'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildAppUpdateSection(BuildContext context) {
    final updateService = UpdateService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'APP VERSION & UPDATES',
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OpenAamps Mobile',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Version 1.2.6 (Build 22) • Canonical Package',
                        style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('v1.2.6', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notify for updates', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Gentle notification once per version. Never prompts again once dismissed.', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 11)),
                value: updateService.autoCheckUpdates,
                activeTrackColor: Colors.white38,
                activeThumbColor: Colors.white,
                onChanged: (val) async {
                  await updateService.setAutoCheckUpdates(val);
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Checking for updates...'),
                        backgroundColor: Color(0xFF222222),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    final update = await updateService.checkForUpdate(userInitiated: true);
                    if (context.mounted) {
                      if (update != null) {
                        updateService.showUpdatePrompt(context, update);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('You are using the latest release of OpenAamps (v1.2.6)!'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Check for Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPlayerStylePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Select Player Theme', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white70), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                ...PlayerStyle.values.map((style) {
                  final isSelected = _settings.playerStyle == style;
                  String desc = '';
                  switch (style) {
                    case PlayerStyle.modern:
                      desc = 'Full-width cinematic card with seamless shadow';
                      break;
                    case PlayerStyle.classic:
                      desc = 'Vintage framed border with retro high-contrast typography';
                      break;
                    case PlayerStyle.vinyl:
                      desc = 'Authentic spinning vinyl disc with grooves and center spindle';
                      break;
                    case PlayerStyle.minimal:
                      desc = 'Ultra-clean focus on typography and audio waveform';
                      break;
                    case PlayerStyle.glassmorphism:
                      desc = 'Frosted glass translucent backdrop with subtle glow';
                      break;
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF222222) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? Colors.white : Colors.white12),
                    ),
                    child: ListTile(
                      title: Text(style.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(desc, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Colors.white) : null,
                      onTap: () {
                        _settings.setPlayerStyle(style);
                        Navigator.pop(ctx);
                        setState(() {});
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBackgroundStylePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Background Canvas Style', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white70), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                ...BackgroundStyle.values.map((bg) {
                  final isSelected = _settings.backgroundStyle == bg;
                  String desc = '';
                  switch (bg) {
                    case BackgroundStyle.pureBlack:
                      desc = 'True pure black AMOLED canvas with maximum battery savings';
                      break;
                    case BackgroundStyle.darkGradient:
                      desc = 'Deep monochrome dark zinc-to-black vertical gradient';
                      break;
                    case BackgroundStyle.albumArtBlur:
                      desc = 'Real-time cinematic blurred backdrop reflecting current artwork';
                      break;
                    case BackgroundStyle.dynamicColor:
                      desc = 'Adaptive monochrome luminescence reacting to track';
                      break;
                    case BackgroundStyle.deepNebula:
                      desc = 'AMOLED deep cosmic nebula wallpaper preset';
                      break;
                    case BackgroundStyle.cyberNoir:
                      desc = 'Dark cyber noir studio ambience preset';
                      break;
                    case BackgroundStyle.velvetNight:
                      desc = 'Atmospheric velvet aurora midnight preset';
                      break;
                    case BackgroundStyle.customWallpaper:
                      desc = 'User-defined custom image wallpaper';
                      break;
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF222222) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? Colors.white : Colors.white12),
                    ),
                    child: ListTile(
                      title: Text(bg.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(desc, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Colors.white) : null,
                      onTap: () {
                        _settings.setBackgroundStyle(bg);
                        Navigator.pop(ctx);
                        setState(() {});
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEqualizerPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const EqualizerSheet(),
    );
  }

  Widget _buildAccentVibeChip(AccentVibe vibe, String label, Color color) {
    final isSelected = _settings.accentVibe == vibe;
    return ChoiceChip(
      avatar: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.white,
      backgroundColor: const Color(0xFF242424),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? Colors.white : Colors.white12),
      ),
      onSelected: (_) {
        _settings.setAccentVibe(vibe);
        setState(() {});
      },
    );
  }
}
