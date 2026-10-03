import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/track.dart';
import 'services/audio_player_service.dart';
import 'services/account_service.dart';
import 'services/local_audio_service.dart';
import 'services/firebase_service.dart';
import 'services/ai_music_service.dart';
import 'services/settings_service.dart';
import 'services/update_service.dart';
import 'views/auth/auth_gate.dart';
import 'views/home_view.dart';
import 'views/search_view.dart';
import 'views/player_view.dart';
import 'views/library_view.dart';
import 'widgets/now_playing_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with generated options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseService.instance.initialize();
  } catch (e) {
    debugPrint('[Firebase] Initialization skipped or error: $e');
  }

  // Initialize non-intrusive Update Service
  await UpdateService.instance.init();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.aamps.openaamps.channel.audio',
    androidNotificationChannelName: 'OpenAamps Playback',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
    androidNotificationIcon: 'drawable/ic_bg_service_small',
  );
  runApp(const OpenAampsApp());
}

class OpenAampsApp extends StatelessWidget {
  const OpenAampsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        final accent = SettingsService.instance.accentColor;
        return MaterialApp(
          title: 'OpenAamps',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF000000),
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
            colorScheme: ColorScheme.dark(
              primary: accent,
              secondary: Colors.white70,
              surface: const Color(0xFF121212),
            ),
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final AudioPlayerService _audioService = AudioPlayerService();

  Track? _activeTrack;

  bool _isPlaying = false;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Track?>? _trackChangeSub;

  @override
  void initState() {
    super.initState();
    _activeTrack = _audioService.currentTrack;
    _isPlaying = _audioService.player.playing;
    _requestNotificationPermission();
    _checkUpdateOnLaunch();
    _playerStateSub = _audioService.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
      if (state.processingState == ProcessingState.completed) {
        if (_activeTrack != null) {
          AiMusicService.instance.onTrackCompleted(
            _activeTrack!,
            _activeTrack!.duration.inSeconds > 0
                ? _activeTrack!.duration.inSeconds.toDouble()
                : 180.0,
          );
        }
      }
    });

    // Listen for track changes (notification controls, autoplay, queue advancement)
    _trackChangeSub = _audioService.currentTrackStream.listen((track) {
      if (mounted) {
        setState(() {
          _activeTrack = track;
        });
      }
    });
  }

  void _requestNotificationPermission() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      } catch (e) {
        debugPrint('Notification permission request error: $e');
      }
    });
  }

  Future<void> _checkUpdateOnLaunch() async {
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    if (!UpdateService.instance.autoCheckUpdates) return;
    final update = await UpdateService.instance.checkForUpdate(userInitiated: false);
    if (update != null && mounted) {
      UpdateService.instance.showUpdatePrompt(context, update);
    }
  }

  void _onPlayTrack(Track track) {
    setState(() {
      _activeTrack = track;
      _isPlaying = true;
    });
    _audioService.playTrack(track);
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _trackChangeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeView(
        onPlayTrack: _onPlayTrack,
        audioService: _audioService,
      ),
      SearchView(onPlayTrack: _onPlayTrack),
      LibraryView(
        accountService: AccountService.instance,
        localAudioService: LocalAudioService(),
        onPlayTrack: _onPlayTrack,
        audioService: _audioService,
      ),
    ];

    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        final accent = SettingsService.instance.accentColor;
        return Scaffold(
          backgroundColor: const Color(0xFF000000),
          body: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: _activeTrack != null ? 82.0 : 0.0),
                child: IndexedStack(
                  index: _currentIndex.clamp(0, 2),
                  children: screens,
                ),
              ),
              if (_activeTrack != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: NowPlayingBar(
                    track: _activeTrack!,
                    audioService: _audioService,
                    isPlaying: _isPlaying,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlayerView(
                            track: _activeTrack!,
                            audioService: _audioService,
                          ),
                        ),
                      );
                    },
                    onPlayPause: () {
                      if (_isPlaying) {
                        _audioService.pause();
                      } else {
                        _audioService.resume(fallbackTrack: _activeTrack);
                      }
                    },
                  ),
                ),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF000000),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.8)),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex.clamp(0, 2),
              backgroundColor: const Color(0xFF000000),
              indicatorColor: accent == Colors.white
                  ? Colors.white.withValues(alpha: 0.14)
                  : accent.withValues(alpha: 0.22),
              elevation: 0,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined, color: Colors.white60),
                  selectedIcon: Icon(Icons.home_rounded, color: accent == Colors.white ? Colors.white : accent),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.search_outlined, color: Colors.white60),
                  selectedIcon: Icon(Icons.search_rounded, color: accent == Colors.white ? Colors.white : accent),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.bookmarks_outlined, color: Colors.white60),
                  selectedIcon: Icon(Icons.bookmarks_rounded, color: accent == Colors.white ? Colors.white : accent),
                  label: 'Library',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
