import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/track.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_data_repository.dart';
import 'party_service.dart';
import 'pi_aamps_service.dart';
import 'youtube_service.dart';
import 'integration_service.dart';

class ConnectedDevice {
  final String id;
  final String name;
  final String type; // "phone", "speaker", "desktop", "car"
  final bool isCurrent;
  final bool isOnline;
  final String subtitle;

  ConnectedDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.isCurrent,
    required this.isOnline,
    required this.subtitle,
  });

  bool get isPhone => type == 'phone';
  bool get isPi => type == 'speaker' || type == 'pi';
  bool get isDesktop => type == 'desktop';
  bool get isActive => isCurrent || isOnline;
}

class AccountService extends ChangeNotifier {
  static final AccountService instance = AccountService._internal();

  late Account _activeAccount;
  final List<Account> _availableAccounts = [];
  bool _isSyncing = false;

  Account get activeAccount => _activeAccount;
  List<Account> get availableAccounts => List.unmodifiable(_availableAccounts);
  bool get isSyncing => _isSyncing;

  AccountService._internal() {
    _initDynamicAccount();
  }

  void _initDynamicAccount() {
    final user = AppAuthRepository.instance.currentUser;
    _activeAccount = _buildAccountFromUser(user);
    _availableAccounts.clear();
    _availableAccounts.add(_activeAccount);

    // Listen to real-time auth state changes
    AppAuthRepository.instance.authStateChanges.listen((updatedUser) {
      _activeAccount = _buildAccountFromUser(updatedUser);
      _availableAccounts.clear();
      _availableAccounts.add(_activeAccount);
      notifyListeners();

      // Automatically sync real YouTube playlists if signed in via Google
      if (updatedUser != null && updatedUser.linkedServices['youtube_music'] == true) {
        syncRealYouTubeAccount();
      }
    });

    // Also auto-sync on launch if already authenticated with Google
    if (user != null && user.linkedServices['youtube_music'] == true) {
      syncRealYouTubeAccount();
    }
  }

  Account _buildAccountFromUser(dynamic user) {
    final spotifyUser = IntegrationService.instance.spotifyUserProfile;
    final fallbackAvatar = 'https://api.dicebear.com/7.x/identicon/png?seed=${user?.uid ?? "openaamps"}';

    if (user == null) {
      return Account(
        id: 'guest',
        name: spotifyUser != null ? spotifyUser.displayName : 'Guest User',
        email: spotifyUser != null ? spotifyUser.email : 'Sign in with Google / Email',
        avatarUrl: (spotifyUser?.avatarUrl.isNotEmpty ?? false)
            ? spotifyUser!.avatarUrl
            : 'https://api.dicebear.com/7.x/identicon/png?seed=guest',
        isPremium: spotifyUser?.product == 'premium',
        playlistsCount: 0,
        likedSongsCount: 0,
        subscriptionsCount: 0,
        isCoupleProfile: false,
      );
    }

    final playlists = UserDataRepository.instance.playlists;
    final favorites = UserDataRepository.instance.favorites;

    final userPhoto = (user.photoUrl as String? ?? '').isNotEmpty
        ? (user.photoUrl as String)
        : (spotifyUser?.avatarUrl.isNotEmpty ?? false
            ? spotifyUser!.avatarUrl
            : fallbackAvatar);

    return Account(
      id: user.uid as String? ?? 'user',
      name: (user.displayName as String? ?? '').isNotEmpty
          ? user.displayName as String
          : (spotifyUser?.displayName.isNotEmpty ?? false
              ? spotifyUser!.displayName
              : (user.email as String? ?? 'OpenAamps User').split('@').first),
      email: (user.email as String? ?? '').isNotEmpty
          ? (user.email as String)
          : (spotifyUser?.email ?? 'user@openaamps.ai'),
      avatarUrl: userPhoto,
      isPremium: true,
      playlistsCount: playlists.length,
      likedSongsCount: favorites.length,
      subscriptionsCount: playlists.where((p) => p.id.startsWith('yt_') || p.id.startsWith('spotify_')).length,
      isCoupleProfile: false,
    );
  }

  /// Syncs real playlists and liked tracks from the user's actual YouTube account
  Future<bool> syncRealYouTubeAccount() async {
    if (_isSyncing) return false;
    _isSyncing = true;
    notifyListeners();

    try {
      final token = await AppAuthRepository.instance.getValidGoogleAccessToken();
      if (token != null && token.isNotEmpty) {
        final yt = YoutubeService();
        final playlists = await yt.fetchUserPlaylists(token);
        final liked = await yt.fetchUserLikedSongs(token);

        if (playlists.isNotEmpty) {
          await UserDataRepository.instance.setSyncedPlaylists(playlists);
        }
        if (liked.isNotEmpty) {
          await UserDataRepository.instance.setSyncedFavorites(liked);
        }

        _activeAccount = _buildAccountFromUser(AppAuthRepository.instance.currentUser);
        _availableAccounts.clear();
        _availableAccounts.add(_activeAccount);
        _isSyncing = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('syncRealYouTubeAccount error: $e');
    }

    _isSyncing = false;
    notifyListeners();
    return false;
  }

  void switchAccount(Account account) {
    _activeAccount = account;
    notifyListeners();
  }

  void updateActiveAccount({
    required String name,
    required String email,
    String? avatarUrl,
  }) {
    _activeAccount = Account(
      id: _activeAccount.id,
      name: name,
      email: email,
      avatarUrl: avatarUrl ?? _activeAccount.avatarUrl,
      isPremium: _activeAccount.isPremium,
      playlistsCount: _activeAccount.playlistsCount,
      likedSongsCount: _activeAccount.likedSongsCount,
      subscriptionsCount: _activeAccount.subscriptionsCount,
      isCoupleProfile: false,
    );
    notifyListeners();
  }

  // --- Spotify Connect Style Device Presence ---
  List<ConnectedDevice> get connectedDevices {
    final pi = PiAampsService.instance;
    final isPiOnline = pi.currentState.isConnected;

    return [
      ConnectedDevice(
        id: 'device_phone_current',
        name: 'This Device (Galaxy A16)',
        type: 'phone',
        isCurrent: true,
        isOnline: true,
        subtitle: 'Local playback • High-res audio engine',
      ),
      ConnectedDevice(
        id: 'device_pi_streamer',
        name: 'pi-aamps (Raspberry Pi 4)',
        type: 'speaker',
        isCurrent: false,
        isOnline: isPiOnline,
        subtitle: isPiOnline
            ? '${pi.ipAddress}:${pi.port} • Bit-perfect ALSA DAC Hub'
            : 'Offline at ${pi.ipAddress}:${pi.port}',
      ),
      ConnectedDevice(
        id: 'device_desktop_web',
        name: 'Desktop Web Player',
        type: 'desktop',
        isCurrent: false,
        isOnline: isPiOnline,
        subtitle: 'Spotify-style web interface in browser',
      ),
    ];
  }

  Future<bool> startCoupleListenTogether({Track? track}) async {
    final party = PartyService.instance;
    if (!party.isInParty) {
      final success = await party.createParty(initialTrack: track);
      return success;
    }
    return true;
  }
}
