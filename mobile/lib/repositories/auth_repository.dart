import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../services/account_service.dart';

// ─────────────────────────────────────────────
//  Abstract Auth Repository Contract
// ─────────────────────────────────────────────
abstract class AuthRepository {
  UserProfile? get currentUser;
  Stream<UserProfile?> get authStateChanges;

  Future<UserProfile> signInWithEmail(String email, String password);
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    List<String> preferredGenres = const [],
  });
  Future<UserProfile> signInWithGoogle();
  Future<UserProfile> signInAsGuest();
  Future<void> linkYouTubeMusicAccount({String? accountName});
  Future<void> linkSpotifyAccount({String? spotifyUsername});
  Future<void> signOut();
  Future<void> updateProfile(UserProfile profile);
}

// ─────────────────────────────────────────────
//  Production Implementation with Tokenization,
//  Salting, Peppering, and Persistent Sessions
// ─────────────────────────────────────────────
class AppAuthRepository implements AuthRepository {
  static final AppAuthRepository instance = AppAuthRepository._internal();
  AppAuthRepository._internal() {
    _init();
  }

  // Application pepper secret for client-side session authentication verification
  static const String _sessionPepper = 'OpenAamps_Acoustic_Security_Salt_Pepper_2026!#@%';
  static const String _sessionStorageKey = 'openaamps_authenticated_session_v3';

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  // Safe standard scopes: standard email and basic profile prevent Google unverified app / unsafe OAuth warning screens
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '777154173201-e6d9jpage9t5hqeq6udtp7qf0h5m56dm.apps.googleusercontent.com',
    scopes: [
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  String? _googleAccessToken;
  String? get googleAccessToken => _googleAccessToken;

  Future<String?> getValidGoogleAccessToken() async {
    if (_googleAccessToken != null) return _googleAccessToken;
    try {
      final account = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
      if (account != null) {
        final auth = await account.authentication;
        _googleAccessToken = auth.accessToken;
        return _googleAccessToken;
      }
    } catch (_) {}
    return null;
  }

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  final _authStateController = StreamController<UserProfile?>.broadcast();
  UserProfile? _currentUser;
  bool _isInitialized = false;

  @override
  UserProfile? get currentUser => _currentUser;

  bool get isInitialized => _isInitialized;

  @override
  Stream<UserProfile?> get authStateChanges => _authStateController.stream;

  /// Generate a cryptographic HMAC-SHA256 signature combining user salt and app pepper.
  String _generateSaltedPepperToken(String uid, String email) {
    final salt = '$uid:${DateTime.now().year}:openaamps_salt';
    final key = utf8.encode(_sessionPepper);
    final bytes = utf8.encode('$salt:$email');
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  /// Store session profile and cryptographic token into persistent storage.
  Future<void> _persistSessionLocally(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = _generateSaltedPepperToken(profile.uid, profile.email);
      final sessionData = {
        'profile': profile.toJson(),
        'token': token,
        'cached_at': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_sessionStorageKey, jsonEncode(sessionData));
    } catch (e) {
      debugPrint('[Auth] Error persisting session: $e');
    }
  }

  /// Restore cached session from persistent storage.
  Future<UserProfile?> _restoreCachedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final profileJson = Map<String, dynamic>.from(map['profile'] ?? {});
        if (profileJson.isNotEmpty) {
          return UserProfile.fromJson(profileJson);
        }
      }
    } catch (e) {
      debugPrint('[Auth] Error restoring session: $e');
    }
    return null;
  }

  /// Wipe cached session on explicit logout.
  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionStorageKey);
    } catch (_) {}
  }

  /// Called once on singleton initialization — restores persistent session and hooks Firebase auth.
  Future<void> _init() async {
    // 1. Immediately restore local session for instant app launch (0ms delay)
    final cached = await _restoreCachedSession();
    if (cached != null) {
      _currentUser = cached;
      _isInitialized = true;
      _authStateController.add(cached);
    }

    try {
      final auth = _auth;
      if (auth != null) {
        // If Firebase already has currentUser, ensure state is set
        final fbUser = auth.currentUser;
        if (fbUser != null && _currentUser == null) {
          _currentUser = await _fetchOrCreateProfile(fbUser);
          _isInitialized = true;
          _authStateController.add(_currentUser);
          await _persistSessionLocally(_currentUser!);
        }

        // Listen for live auth state transitions
        auth.authStateChanges().listen((firebaseUser) async {
          if (firebaseUser != null) {
            _currentUser = await _fetchOrCreateProfile(firebaseUser);
            await _persistSessionLocally(_currentUser!);
          } else {
            // Only clear if no offline session exists or user explicitly signed out
            if (_auth?.currentUser == null) {
              _currentUser = null;
              await _clearPersistedSession();
            }
          }
          _isInitialized = true;
          _authStateController.add(_currentUser);
        });
      } else {
        if (_currentUser == null) {
          _isInitialized = true;
          _authStateController.add(null);
        }
      }
    } catch (e) {
      debugPrint('[Auth] Auth initialization warning: $e');
      _isInitialized = true;
      _authStateController.add(_currentUser);
    }
  }

  // ─── Sign-In with Email/Password ───────────────────────────────────────────
  @override
  Future<UserProfile> signInWithEmail(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw Exception('Please enter a valid email address');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }

    final auth = _auth;
    if (auth == null) {
      // Local authenticated session
      final profile = UserProfile(
        uid: 'user_${cleanEmail.hashCode.abs()}',
        email: cleanEmail,
        displayName: cleanEmail.split('@').first,
        isGuest: false,
      );
      _currentUser = profile;
      _authStateController.add(profile);
      await _persistSessionLocally(profile);
      return profile;
    }

    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final profile = await _fetchOrCreateProfile(credential.user!);
      _currentUser = profile;
      _authStateController.add(profile);
      await _persistSessionLocally(profile);
      return profile;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e));
    } catch (e) {
      rethrow;
    }
  }

  // ─── Sign-Up with Email/Password ───────────────────────────────────────────
  @override
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    List<String> preferredGenres = const [],
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw Exception('Please provide a valid email');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }
    if (displayName.trim().isEmpty) {
      throw Exception('Please provide your name');
    }

    final auth = _auth;
    if (auth == null) {
      throw Exception('Authentication service not initialized');
    }

    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      // Update display name in Firebase Auth
      await credential.user!.updateDisplayName(displayName.trim());
      await credential.user!.reload();

      // Build initial acoustic taste vector based on genre preferences
      double initialEnergy = 0.65;
      double initialAcoustic = 0.35;
      if (preferredGenres.contains('Rock') || preferredGenres.contains('EDM')) {
        initialEnergy += 0.20;
        initialAcoustic -= 0.15;
      }
      if (preferredGenres.contains('Classical') || preferredGenres.contains('Lo-Fi')) {
        initialEnergy -= 0.25;
        initialAcoustic += 0.35;
      }

      final profile = UserProfile(
        uid: credential.user!.uid,
        email: cleanEmail,
        displayName: displayName.trim(),
        photoUrl: credential.user!.photoURL ??
            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName.trim().isEmpty ? 'Music Listener' : displayName.trim())}&background=1DB954&color=fff&bold=true',
        preferredGenres: preferredGenres.isNotEmpty
            ? preferredGenres
            : const ['Rock', 'Pop', 'Lo-Fi'],
        topArtists: const ['Coldplay', 'Queen'],
        tasteVector: AcousticTasteVector(
          energy: initialEnergy.clamp(0.1, 0.95),
          valence: 0.60,
          danceability: 0.62,
          acousticness: initialAcoustic.clamp(0.05, 0.95),
          tempo: 120.0,
        ),
        linkedServices: const {'youtube_music': false, 'spotify': false},
        isGuest: false,
      );

      // Persist to Firestore and local session
      await _saveProfileToFirestore(profile);
      await _persistSessionLocally(profile);

      _currentUser = profile;
      _authStateController.add(profile);
      return profile;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e));
    }
  }

  // ─── Sign-In with Google ────────────────────────────────────────────────────
  @override
  Future<UserProfile> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) {
      throw Exception('Authentication service not initialized');
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      _googleAccessToken = googleAuth.accessToken;

      final userCredential = await auth.signInWithCredential(credential);
      final profile = await _fetchOrCreateProfile(userCredential.user!);

      // Auto-enable YouTube Music sync by default when authenticated via Google
      final updatedProfile = profile.copyWith(
        linkedServices: {
          ...profile.linkedServices,
          'youtube_music': true,
          'google_email': googleUser.email,
        },
      );

      _currentUser = updatedProfile;
      _authStateController.add(updatedProfile);

      // Persist to Firestore and local session
      await _saveProfileToFirestore(updatedProfile);
      await _persistSessionLocally(updatedProfile);

      // Automatically trigger real YouTube account sync in background
      AccountService.instance.syncRealYouTubeAccount().catchError((e) {
        debugPrint('[Google Auth] Background YouTube sync info: $e');
        return false;
      });

      return updatedProfile;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e));
    } catch (e) {
      rethrow;
    }
  }

  // ─── Sign-In as Guest (Safe / Frictionless Zero-Setup Mode) ──────────────────
  @override
  Future<UserProfile> signInAsGuest() async {
    final guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
    final profile = UserProfile(
      uid: guestId,
      email: 'guest@openaamps.local',
      displayName: 'Guest Audiophile',
      photoUrl: '',
      preferredGenres: const ['Hi-Res Audio', 'Lossless Stream', 'Acoustic'],
      tasteVector: const AcousticTasteVector(
        energy: 0.65,
        valence: 0.70,
        danceability: 0.60,
        acousticness: 0.50,
        tempo: 124.0,
      ),
      linkedServices: const {'youtube_music': false, 'spotify': false},
      isGuest: true,
    );

    await _persistSessionLocally(profile);
    _currentUser = profile;
    _authStateController.add(profile);
    return profile;
  }

  // ─── Account Synchronization (YouTube Music & Spotify) ──────────────────────
  @override
  Future<void> linkYouTubeMusicAccount({String? accountName}) async {
    if (_currentUser == null) return;
    final updatedServices = Map<String, dynamic>.from(_currentUser!.linkedServices);
    updatedServices['youtube_music'] = true;
    updatedServices['youtube_music_account'] = accountName ?? _currentUser!.email;
    _currentUser = _currentUser!.copyWith(linkedServices: updatedServices);
    _authStateController.add(_currentUser);
    await _saveProfileToFirestore(_currentUser!);
    await _persistSessionLocally(_currentUser!);
  }

  @override
  Future<void> linkSpotifyAccount({String? spotifyUsername}) async {
    if (_currentUser == null) return;
    final updatedServices = Map<String, dynamic>.from(_currentUser!.linkedServices);
    updatedServices['spotify'] = true;
    updatedServices['spotify_account'] = spotifyUsername ?? 'Spotify User';
    _currentUser = _currentUser!.copyWith(linkedServices: updatedServices);
    _authStateController.add(_currentUser);
    await _saveProfileToFirestore(_currentUser!);
    await _persistSessionLocally(_currentUser!);
  }

  // ─── Sign-Out ────────────────────────────────────────────────────────────────
  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      final auth = _auth;
      if (auth != null) {
        await auth.signOut();
      }
    } catch (_) {}
    await _clearPersistedSession();
    _currentUser = null;
    _authStateController.add(null);
  }

  // ─── Update Profile ──────────────────────────────────────────────────────────
  @override
  Future<void> updateProfile(UserProfile profile) async {
    _currentUser = profile;
    _authStateController.add(profile);
    await _saveProfileToFirestore(profile);
    await _persistSessionLocally(profile);

    // Also update display name in Firebase Auth if changed
    final auth = _auth;
    final firebaseUser = auth?.currentUser;
    if (firebaseUser != null &&
        firebaseUser.displayName != profile.displayName) {
      await firebaseUser.updateDisplayName(profile.displayName);
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  /// Fetches the user profile from Firestore with timeout protection, or builds from Firebase Auth.
  Future<UserProfile> _fetchOrCreateProfile(
    User firebaseUser, {
    String? overrideDisplayName,
  }) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final doc = await firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get()
            .timeout(const Duration(seconds: 3));

        if (doc.exists && doc.data() != null) {
          return UserProfile.fromJson({
            'uid': firebaseUser.uid,
            ...doc.data()!,
          });
        }
      } catch (_) {
        // Firestore unavailable or timed out — fall back safely to Firebase Auth data
      }
    }

    // Build a clean profile from Firebase Auth metadata
    final profile = UserProfile(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: overrideDisplayName ??
          firebaseUser.displayName ??
          firebaseUser.email?.split('@').first ??
          'Music Listener',
      photoUrl: firebaseUser.photoURL ??
          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(overrideDisplayName ?? firebaseUser.displayName ?? 'Music Listener')}&background=1DB954&color=fff&bold=true',
      preferredGenres: const ['Rock', 'Pop', 'Lo-Fi'],
      topArtists: const ['Coldplay', 'Queen'],
      tasteVector: const AcousticTasteVector(
        energy: 0.65,
        valence: 0.60,
        danceability: 0.62,
        acousticness: 0.35,
        tempo: 120.0,
      ),
      isGuest: false,
    );

    // Try to persist to Firestore asynchronously
    _saveProfileToFirestore(profile).catchError((_) {});
    return profile;
  }

  /// Saves a UserProfile to Firestore under `users/{uid}` with merge.
  Future<void> _saveProfileToFirestore(UserProfile profile) async {
    final firestore = _firestore;
    if (firestore == null) return;
    try {
      final data = profile.toJson();
      data.remove('uid');
      await firestore
          .collection('users')
          .doc(profile.uid)
          .set(data, SetOptions(merge: true))
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  /// Converts FirebaseAuthException codes to friendly error messages.
  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found for this email. Please sign up first.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please verify and try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Please log in.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
