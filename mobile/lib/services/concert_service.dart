import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import 'audio_player_service.dart';
import 'equalizer_service.dart';

enum StagePerspective {
  frontRow,
  vipSoundboard,
  stadiumBleachers,
}

extension StagePerspectiveExtension on StagePerspective {
  String get title {
    switch (this) {
      case StagePerspective.frontRow:
        return 'Front Row Pit';
      case StagePerspective.vipSoundboard:
        return 'VIP Soundboard';
      case StagePerspective.stadiumBleachers:
        return 'Stadium Bleachers';
    }
  }

  String get description {
    switch (this) {
      case StagePerspective.frontRow:
        return 'Direct acoustic punch, proximity vocals & high energy';
      case StagePerspective.vipSoundboard:
        return 'Optimal binaural stereo balance & acoustic reference';
      case StagePerspective.stadiumBleachers:
        return 'Expansive atmospheric stadium reverb & crowd immersion';
    }
  }

  IconData get icon {
    switch (this) {
      case StagePerspective.frontRow:
        return Icons.record_voice_over_rounded;
      case StagePerspective.vipSoundboard:
        return Icons.tune_rounded;
      case StagePerspective.stadiumBleachers:
        return Icons.stadium_rounded;
    }
  }
}

class ConcertVenue {
  final String id;
  final String name;
  final String city;
  final String capacity;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final String eqPreset;
  final double bassBoost;
  final double virtualizer;
  final double reverbLevel;
  final bool enable16d;

  const ConcertVenue({
    required this.id,
    required this.name,
    required this.city,
    required this.capacity,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.eqPreset,
    required this.bassBoost,
    required this.virtualizer,
    required this.reverbLevel,
    this.enable16d = false,
  });
}

class LiveConcert {
  final String id;
  final String title;
  final String artist;
  final String tourName;
  final String venueName;
  final String artworkUrl;
  final String bannerUrl;
  final int baseAudience;
  final String status;
  final bool isLiveNow;
  final bool isPaid;
  final double ticketPrice;
  final String scheduledTime;
  final int totalSeats;
  int bookedSeats;
  final List<Track> setlist;
  final List<String> highlights;

  LiveConcert({
    required this.id,
    required this.title,
    required this.artist,
    required this.tourName,
    required this.venueName,
    required this.artworkUrl,
    required this.bannerUrl,
    required this.baseAudience,
    required this.status,
    required this.isLiveNow,
    this.isPaid = false,
    this.ticketPrice = 0.0,
    this.scheduledTime = 'Scheduled',
    this.totalSeats = 50000,
    this.bookedSeats = 38400,
    required this.setlist,
    required this.highlights,
  });
}

class ConcertBookingPass {
  final String id;
  final String concertId;
  final String concertTitle;
  final String artist;
  final String venueName;
  final String tier; // "General Admission", "VIP Front Row Pit", "Backstage Pass"
  final String seatNumber; // "Section A • Row 4 • Seat 12"
  final double price;
  final bool isPaid;
  final DateTime bookedAt;
  final String passCode;

  const ConcertBookingPass({
    required this.id,
    required this.concertId,
    required this.concertTitle,
    required this.artist,
    required this.venueName,
    required this.tier,
    required this.seatNumber,
    required this.price,
    required this.isPaid,
    required this.bookedAt,
    required this.passCode,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'concert_id': concertId,
    'concert_title': concertTitle,
    'artist': artist,
    'venue_name': venueName,
    'tier': tier,
    'seat_number': seatNumber,
    'price': price,
    'is_paid': isPaid,
    'booked_at': bookedAt.toIso8601String(),
    'pass_code': passCode,
  };

  factory ConcertBookingPass.fromJson(Map<String, dynamic> json) => ConcertBookingPass(
    id: json['id'] ?? '',
    concertId: json['concert_id'] ?? '',
    concertTitle: json['concert_title'] ?? '',
    artist: json['artist'] ?? '',
    venueName: json['venue_name'] ?? '',
    tier: json['tier'] ?? 'General Admission',
    seatNumber: json['seat_number'] ?? 'Open Stand',
    price: (json['price'] as num?)?.toDouble() ?? 0.0,
    isPaid: json['is_paid'] ?? false,
    bookedAt: DateTime.tryParse(json['booked_at'] ?? '') ?? DateTime.now(),
    passCode: json['pass_code'] ?? 'PASS-1000',
  );
}

class FanShoutout {
  final String id;
  final String userName;
  final String city;
  final String message;
  final String? badge;
  final Color avatarColor;
  final DateTime timestamp;

  const FanShoutout({
    required this.id,
    required this.userName,
    required this.city,
    required this.message,
    this.badge,
    required this.avatarColor,
    required this.timestamp,
  });
}

class FloatingReaction {
  final String id;
  final String reactionType;
  final double xOffset;
  final Color color;
  final DateTime createdAt;

  FloatingReaction({
    required this.id,
    required this.reactionType,
    required this.xOffset,
    required this.color,
    required this.createdAt,
  });
}

class ConcertService extends ChangeNotifier {
  static final ConcertService instance = ConcertService._internal();
  factory ConcertService() => instance;

  final math.Random _random = math.Random();
  Timer? _audienceTimer;
  Timer? _shoutoutTimer;
  AudioPlayer? _sfxPlayer;

  // Active Venue configuration
  static const List<ConcertVenue> availableVenues = [
    ConcertVenue(
      id: 'wembley',
      name: 'Wembley Stadium Arena',
      city: 'London, UK',
      capacity: '90,000 Fans',
      description: 'Stadium acoustic reflections, roaring sub-bass and wide binaural stereo dispersion',
      icon: Icons.stadium_rounded,
      primaryColor: Color(0xFF1DB954),
      secondaryColor: Color(0xFF1ED760),
      eqPreset: 'Wembley Stadium',
      bassBoost: 0.55,
      virtualizer: 0.85,
      reverbLevel: 0.80,
    ),
    ConcertVenue(
      id: 'red_rocks',
      name: 'Red Rocks Amphitheatre',
      city: 'Morrison, Colorado',
      capacity: '9,525 Fans',
      description: 'Open-air mountain canyon acoustics with natural delay echo & vocal clarity',
      icon: Icons.terrain_rounded,
      primaryColor: Color(0xFFEF4444),
      secondaryColor: Color(0xFFF87171),
      eqPreset: 'Red Rocks Amphitheatre',
      bassBoost: 0.28,
      virtualizer: 0.65,
      reverbLevel: 0.60,
    ),
    ConcertVenue(
      id: 'tokyo_dome',
      name: 'Tokyo Dome 360',
      city: 'Tokyo, Japan',
      capacity: '55,000 Fans',
      description: '16D spatial orbital immersion with pulsating dome resonance & holographic sound',
      icon: Icons.lens_blur_rounded,
      primaryColor: Color(0xFF00F2FE),
      secondaryColor: Color(0xFF38BDF8),
      eqPreset: 'Tokyo Dome 360',
      bassBoost: 0.40,
      virtualizer: 0.95,
      reverbLevel: 0.85,
      enable16d: true,
    ),
    ConcertVenue(
      id: 'acoustic_pit',
      name: 'The Roxy Club & Pit',
      city: 'West Hollywood, CA',
      capacity: '500 VIPs',
      description: 'Intimate front-row stereo, warm punchy mids & crisp direct live acoustic presence',
      icon: Icons.nightlife_rounded,
      primaryColor: Color(0xFFFFB800),
      secondaryColor: Color(0xFFFBBF24),
      eqPreset: 'Acoustic VIP Pit',
      bassBoost: 0.22,
      virtualizer: 0.35,
      reverbLevel: 0.25,
    ),
  ];

  ConcertVenue _currentVenue = availableVenues[0];
  StagePerspective _currentPerspective = StagePerspective.vipSoundboard;

  // Active concert selection
  late LiveConcert _currentConcert;
  int _liveAudienceCount = 38450;
  bool _isStageLive = false; // Default: OFF / Dark Arena unless hosted or active!
  bool _isConcertAcousticsActive = true;
  bool _isCrowdAmbienceEnabled = true;
  bool _isPiBroadcastEnabled = false;

  // User booking passes
  final List<ConcertBookingPass> _userPasses = [];

  // Lightstick state
  bool _isLightstickActive = false;
  Color _lightstickColor = const Color(0xFF00F2FE);
  double _lightstickPulseSpeed = 1.0;
  bool _isStrobeMode = false;

  // Live crowd interactions
  final List<FanShoutout> _shoutouts = [];
  final List<FloatingReaction> _reactions = [];

  // Getters
  ConcertVenue get currentVenue => _currentVenue;
  StagePerspective get currentPerspective => _currentPerspective;
  LiveConcert get currentConcert => _currentConcert;
  int get liveAudienceCount => _liveAudienceCount;
  bool get isStageLive => _isStageLive;
  bool get isConcertAcousticsActive => _isConcertAcousticsActive;
  bool get isCrowdAmbienceEnabled => _isCrowdAmbienceEnabled;
  bool get isPiBroadcastEnabled => _isPiBroadcastEnabled;
  bool get isLightstickActive => _isLightstickActive;
  Color get lightstickColor => _lightstickColor;
  double get lightstickPulseSpeed => _lightstickPulseSpeed;
  bool get isStrobeMode => _isStrobeMode;
  List<FanShoutout> get shoutouts => List.unmodifiable(_shoutouts);
  List<FloatingReaction> get reactions => List.unmodifiable(_reactions);
  List<ConcertBookingPass> get userPasses => List.unmodifiable(_userPasses);

  final List<LiveConcert> _hostedConcerts = [];
  List<LiveConcert> get allConcerts => [..._hostedConcerts, ...curatedConcerts];

  // Curated Concert Lineup with Booking & Seat Availability
  final List<LiveConcert> curatedConcerts = [
    LiveConcert(
      id: 'coldplay_buenos_aires',
      title: 'Music of the Spheres (Live in River Plate)',
      artist: 'Coldplay',
      tourName: 'Music of the Spheres World Stadium Tour',
      venueName: 'Estadio River Plate Arena',
      artworkUrl: 'https://i.scdn.co/image/ab6761610000e5eb989ed050d2364ec46505a43d',
      bannerUrl: 'https://i.ytimg.com/vi/bZ_6mJbB_pY/hqdefault.jpg',
      baseAudience: 72480,
      status: 'SCHEDULED BROADCAST',
      isLiveNow: false,
      isPaid: false,
      ticketPrice: 0.0,
      scheduledTime: 'Tonight at 8:30 PM EST',
      totalSeats: 75000,
      bookedSeats: 72480,
      highlights: ['Synchronized Xylobands', 'Stadium Firework Finale', 'Binaural 8D Audio'],
      setlist: [
        Track(
          id: 'yKNxeF4KMsY',
          title: 'Yellow (Live Stadium Reverb)',
          artist: 'Coldplay',
          album: 'Live in Buenos Aires',
          duration: const Duration(minutes: 5, seconds: 12),
          artworkUrl: 'https://i.ytimg.com/vi/yKNxeF4KMsY/hqdefault.jpg',
          streamUrl: '',
          codec: 'FLAC 24-bit 96kHz',
        ),
        Track(
          id: 'dvgZkm1xWPE',
          title: 'Viva La Vida (Crowd Chants Edition)',
          artist: 'Coldplay',
          album: 'Live in Buenos Aires',
          duration: const Duration(minutes: 4, seconds: 40),
          artworkUrl: 'https://i.ytimg.com/vi/dvgZkm1xWPE/hqdefault.jpg',
          streamUrl: '',
          codec: 'AAC 320kbps',
        ),
        Track(
          id: 'k4V3Mo61fJM',
          title: 'Fix You (Live Sing-Along)',
          artist: 'Coldplay',
          album: 'Live in Buenos Aires',
          duration: const Duration(minutes: 5, seconds: 28),
          artworkUrl: 'https://i.ytimg.com/vi/k4V3Mo61fJM/hqdefault.jpg',
          streamUrl: '',
          codec: 'AAC 320kbps',
        ),
        Track(
          id: 'VPRjCeoBqrI',
          title: 'A Sky Full of Stars (Confetti Blast)',
          artist: 'Coldplay',
          album: 'Live in Buenos Aires',
          duration: const Duration(minutes: 4, seconds: 35),
          artworkUrl: 'https://i.ytimg.com/vi/VPRjCeoBqrI/hqdefault.jpg',
          streamUrl: '',
          codec: 'AAC 320kbps',
        ),
      ],
    ),
    LiveConcert(
      id: 'the_weeknd_sofi',
      title: 'After Hours Til Dawn (Live at SoFi)',
      artist: 'The Weeknd',
      tourName: 'After Hours Til Dawn Global Stadium Tour',
      venueName: 'SoFi Stadium Arena',
      artworkUrl: 'https://i.scdn.co/image/ab6761610000e5eb214f3cf1cbe713969e06e271',
      bannerUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
      baseAudience: 68900,
      status: 'UPCOMING TICKETED SHOW',
      isLiveNow: false,
      isPaid: true,
      ticketPrice: 9.99,
      scheduledTime: 'Tomorrow at 9:00 PM EST',
      totalSeats: 70000,
      bookedSeats: 68900,
      highlights: ['Full Moon Center Stage', 'Pyrotechnics Laser Show', 'Synthwave Reverb'],
      setlist: [
        Track(
          id: '4NRXx6U8ABQ',
          title: 'Blinding Lights (Live Arena Synth)',
          artist: 'The Weeknd',
          album: 'Live at SoFi Stadium',
          duration: const Duration(minutes: 4, seconds: 15),
          artworkUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
          streamUrl: '',
          codec: 'FLAC 24-bit 96kHz',
        ),
        Track(
          id: '34Na4j8AVgA',
          title: 'Starboy (Stadium Bass Drop)',
          artist: 'The Weeknd',
          album: 'Live at SoFi Stadium',
          duration: const Duration(minutes: 3, seconds: 55),
          artworkUrl: 'https://i.ytimg.com/vi/34Na4j8AVgA/hqdefault.jpg',
          streamUrl: '',
          codec: 'AAC 320kbps',
        ),
        Track(
          id: 'XXYlFuWEuKI',
          title: 'Save Your Tears (Acoustic Echo)',
          artist: 'The Weeknd',
          album: 'Live at SoFi Stadium',
          duration: const Duration(minutes: 3, seconds: 40),
          artworkUrl: 'https://i.ytimg.com/vi/XXYlFuWEuKI/hqdefault.jpg',
          streamUrl: '',
          codec: 'AAC 320kbps',
        ),
      ],
    ),
    LiveConcert(
      id: 'taylor_eras_tour',
      title: 'The Eras Tour (Live Acoustic Pit)',
      artist: 'Taylor Swift',
      tourName: 'The Eras Stadium Tour',
      venueName: 'Wembley Stadium Arena',
      artworkUrl: 'https://i.scdn.co/image/ab6761610000e5eb5a00969a4698c3132a15fbb0',
      bannerUrl: 'https://i.ytimg.com/vi/KudedLV0tP0/hqdefault.jpg',
      baseAudience: 88500,
      status: 'RESERVED ACCESS ONLY',
      isLiveNow: false,
      isPaid: true,
      ticketPrice: 14.99,
      scheduledTime: 'Saturday at 7:00 PM GMT',
      totalSeats: 90000,
      bookedSeats: 88500,
      highlights: ['Lightband LED Wave', '3.5-Hour Epic Set', 'Acoustic Guitar Direct'],
      setlist: [
        Track(
          id: 'ic8j13U_610',
          title: 'Cruel Summer (Live Bridge Roar)',
          artist: 'Taylor Swift',
          album: 'The Eras Tour Live',
          duration: const Duration(minutes: 3, seconds: 58),
          artworkUrl: 'https://i.ytimg.com/vi/ic8j13U_610/hqdefault.jpg',
          streamUrl: '',
          codec: 'FLAC 24-bit 96kHz',
        ),
        Track(
          id: 'b1kbLwvqugk',
          title: 'Anti-Hero (Stadium Sing-Along)',
          artist: 'Taylor Swift',
          album: 'The Eras Tour Live',
          duration: const Duration(minutes: 3, seconds: 20),
          artworkUrl: 'https://i.ytimg.com/vi/b1kbLwvqugk/hqdefault.jpg',
          streamUrl: '',
          codec: 'AAC 320kbps',
        ),
        Track(
          id: '-BjZmE2gtdo',
          title: 'Lover (Live Piano Acoustic)',
          artist: 'Taylor Swift',
          album: 'The Eras Tour Live',
          duration: const Duration(minutes: 3, seconds: 50),
          artworkUrl: 'https://i.ytimg.com/vi/-BjZmE2gtdo/hqdefault.jpg',
          streamUrl: '',
          codec: 'AAC 320kbps',
        ),
      ],
    ),
    LiveConcert(
      id: 'queen_live_aid',
      title: 'Queen at Live Aid 1985 (Remastered)',
      artist: 'Queen',
      tourName: 'Live Aid Historic Broadcast',
      venueName: 'Wembley Stadium 1985',
      artworkUrl: 'https://i.scdn.co/image/ab6761610000e5ebce4f3d2f924e24cf7e7216a6',
      bannerUrl: 'https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
      baseAudience: 92000,
      status: 'FREE ENCORE ARCHIVE',
      isLiveNow: false,
      isPaid: false,
      ticketPrice: 0.0,
      scheduledTime: 'Sunday at 6:00 PM GMT',
      totalSeats: 100000,
      bookedSeats: 92000,
      highlights: ['Freddie Mercury Vocal Call', 'Radio Ga Ga Claps', 'Historic Stadium Roar'],
      setlist: [
        Track(
          id: 'fJ9rUzIMcZQ',
          title: 'Bohemian Rhapsody (Live Aid 1985)',
          artist: 'Queen',
          album: 'Live Aid 1985 Remaster',
          duration: const Duration(minutes: 5, seconds: 55),
          artworkUrl: 'https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
          streamUrl: '',
          codec: 'FLAC 24-bit 96kHz',
        ),
        Track(
          id: 't63_dQzug5g',
          title: 'Radio Ga Ga (Live Aid Clap Sync)',
          artist: 'Queen',
          album: 'Live Aid 1985 Remaster',
          duration: const Duration(minutes: 4, seconds: 30),
          artworkUrl: 'https://i.ytimg.com/vi/t63_dQzug5g/hqdefault.jpg',
          streamUrl: '',
          codec: 'AAC 320kbps',
        ),
        Track(
          id: '04854XqcfCY',
          title: 'We Are The Champions (Stadium Anthem)',
          artist: 'Queen',
          album: 'Live Aid 1985 Remaster',
          duration: const Duration(minutes: 4, seconds: 05),
          artworkUrl: 'https://i.ytimg.com/vi/04854XqcfCY/hqdefault.jpg',
          streamUrl: '',
          codec: 'AAC 320kbps',
        ),
      ],
    ),
  ];

  ConcertService._internal() {
    _currentConcert = curatedConcerts[0];
    _isStageLive = false; // Arena is OFF by default until an event is broadcasted!
    _liveAudienceCount = _currentConcert.baseAudience + _random.nextInt(350);
    _populateInitialShoutouts();
    _loadUserPasses();
    _initSfx();
  }

  void _initSfx() {
    try {
      _sfxPlayer = AudioPlayer();
    } catch (_) {}
  }

  Future<void> _loadUserPasses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('openaamps_concert_passes') ?? [];
      _userPasses.clear();
      for (final item in list) {
        final map = jsonDecode(item) as Map<String, dynamic>;
        _userPasses.add(ConcertBookingPass.fromJson(map));
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveUserPasses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _userPasses.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList('openaamps_concert_passes', list);
    } catch (_) {}
  }

  bool hasPass(String concertId) {
    return _userPasses.any((p) => p.concertId == concertId);
  }

  Future<ConcertBookingPass> bookSeat({
    required LiveConcert concert,
    required String tier,
    required String seatNumber,
    required double price,
  }) async {
    final passCode = 'PASS-${_random.nextInt(90000) + 10000}';
    final pass = ConcertBookingPass(
      id: 'pass_${DateTime.now().millisecondsSinceEpoch}',
      concertId: concert.id,
      concertTitle: concert.title,
      artist: concert.artist,
      venueName: concert.venueName,
      tier: tier,
      seatNumber: seatNumber,
      price: price,
      isPaid: price > 0,
      bookedAt: DateTime.now(),
      passCode: passCode,
    );

    _userPasses.insert(0, pass);
    concert.bookedSeats = math.min(concert.totalSeats, concert.bookedSeats + 1);
    await _saveUserPasses();
    notifyListeners();
    return pass;
  }

  void startBroadcast(LiveConcert concert) {
    _currentConcert = concert;
    _isStageLive = true;
    _startAudienceSimulation();
    _startShoutoutSimulation();
    applyCurrentAcoustics();
    notifyListeners();
  }

  void stopBroadcast() {
    _isStageLive = false;
    _audienceTimer?.cancel();
    _shoutoutTimer?.cancel();
    notifyListeners();
  }

  void enterStage(LiveConcert concert, AudioPlayerService audioService) {
    _currentConcert = concert;
    _isStageLive = true;
    _startAudienceSimulation();
    _startShoutoutSimulation();
    if (concert.setlist.isNotEmpty) {
      audioService.playTrack(concert.setlist.first);
      applyCurrentAcoustics();
    }
    notifyListeners();
  }

  void leaveStage() {
    _isStageLive = false;
    _audienceTimer?.cancel();
    _shoutoutTimer?.cancel();
    notifyListeners();
  }

  void hostNewConcert({
    required String title,
    required String artist,
    required String venueId,
    required List<Track> setlist,
    String? bannerUrl,
    String? tourName,
    bool isPaid = false,
    double ticketPrice = 0.0,
    int totalSeats = 5000,
    String scheduledTime = 'Live Now',
    bool goLiveNow = true,
  }) {
    final venue = availableVenues.firstWhere(
      (v) => v.id == venueId,
      orElse: () => availableVenues[0],
    );
    final concert = LiveConcert(
      id: 'hosted_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      artist: artist,
      tourName: tourName ?? '$artist Live Stage Arena',
      venueName: venue.name,
      artworkUrl: setlist.isNotEmpty && setlist.first.artworkUrl.isNotEmpty
          ? setlist.first.artworkUrl
          : 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500',
      bannerUrl: bannerUrl ?? 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=1000',
      baseAudience: 1450 + _random.nextInt(600),
      status: goLiveNow ? 'ON STAGE NOW' : 'SCHEDULED ONLINE EVENT',
      isLiveNow: goLiveNow,
      isPaid: isPaid,
      ticketPrice: ticketPrice,
      scheduledTime: scheduledTime,
      totalSeats: totalSeats,
      bookedSeats: 1,
      highlights: ['Artist Direct Broadcast', 'DSP Binaural Spatialization', 'Crowd Interactive Wave'],
      setlist: setlist,
    );
    _hostedConcerts.insert(0, concert);
    _currentConcert = concert;
    _currentVenue = venue;
    _liveAudienceCount = concert.baseAudience;

    if (goLiveNow) {
      _isStageLive = true;
      _startAudienceSimulation();
      _startShoutoutSimulation();
      applyCurrentAcoustics();
    }
    notifyListeners();
  }

  void _populateInitialShoutouts() {
    final seedShoutouts = [
      FanShoutout(
        id: '1',
        userName: 'Aria_Sound',
        city: 'London, UK',
        message: 'The Wembley stadium reverb feels like standing right at the barricade.',
        badge: 'VIP',
        avatarColor: const Color(0xFF1DB954),
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
      FanShoutout(
        id: '2',
        userName: 'Kenji_Tokyo',
        city: 'Tokyo, JP',
        message: 'Switching to Tokyo Dome 16D spatial mode. The acoustic panning is crisp and wide.',
        badge: 'FAN CLUB',
        avatarColor: const Color(0xFF00F2FE),
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
      FanShoutout(
        id: '3',
        userName: 'Mateo_BUE',
        city: 'Buenos Aires, AR',
        message: 'Everyone wave your lightsticks for the chorus.',
        badge: 'TOUR CREW',
        avatarColor: const Color(0xFFFFB800),
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
      FanShoutout(
        id: '4',
        userName: 'Sarah_Swiftie',
        city: 'Nashville, US',
        message: 'Sent the audio to our living room Raspberry Pi speaker, stadium surround is real.',
        badge: 'VIP',
        avatarColor: const Color(0xFFEF4444),
        timestamp: DateTime.now().subtract(const Duration(seconds: 40)),
      ),
    ];
    _shoutouts.addAll(seedShoutouts);
  }

  void _startAudienceSimulation() {
    _audienceTimer?.cancel();
    _audienceTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final delta = _random.nextInt(15) - 6; // -6 to +8 variation
      _liveAudienceCount = math.max(1000, _liveAudienceCount + delta);
      notifyListeners();
    });
  }

  void _startShoutoutSimulation() {
    _shoutoutTimer?.cancel();
    final pool = [
      ('Liam_C', 'Manchester, UK', 'Best live acoustics ever engineered.', 'FAN CLUB', const Color(0xFF1DB954)),
      ('Elena_M', 'Berlin, DE', 'The bass drop through the virtualizer is kicking so hard.', null, const Color(0xFFEF4444)),
      ('Carlos_R', 'Madrid, ES', 'Cheering from Spain! Sing it out loud.', 'VIP', const Color(0xFF00F2FE)),
      ('Chloe_K', 'Seoul, KR', 'My lightstick is in sync with the beat. Look at the arena glow.', 'FAN CLUB', const Color(0xFF1DB954)),
      ('Marcus_LA', 'Los Angeles, US', 'Just switched to VIP Soundboard mode, pure master audio.', 'TOUR CREW', const Color(0xFFFFB800)),
      ('Priya_D', 'Mumbai, IN', 'Fix You coming up next. Chills everywhere.', null, const Color(0xFFFFFFFF)),
    ];

    _shoutoutTimer = Timer.periodic(const Duration(seconds: 14), (_) {
      final item = pool[_random.nextInt(pool.length)];
      final shoutout = FanShoutout(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userName: item.$1,
        city: item.$2,
        message: item.$3,
        badge: item.$4,
        avatarColor: item.$5,
        timestamp: DateTime.now(),
      );
      _shoutouts.insert(0, shoutout);
      if (_shoutouts.length > 20) {
        _shoutouts.removeLast();
      }
      notifyListeners();
    });
  }

  // --- Venue & Acoustic Controls ---
  void setVenue(ConcertVenue venue) {
    _currentVenue = venue;
    applyCurrentAcoustics();
    notifyListeners();
  }

  void setPerspective(StagePerspective perspective) {
    _currentPerspective = perspective;
    applyCurrentAcoustics();
    notifyListeners();
  }

  void toggleConcertAcoustics(bool enabled) {
    _isConcertAcousticsActive = enabled;
    if (enabled) {
      applyCurrentAcoustics();
    } else {
      EqualizerService.instance.reset();
    }
    notifyListeners();
  }

  void toggleCrowdAmbience(bool enabled) {
    _isCrowdAmbienceEnabled = enabled;
    notifyListeners();
  }

  void togglePiBroadcast(bool enabled) {
    _isPiBroadcastEnabled = enabled;
    if (enabled) {
      AudioPlayerService.instance.setAudioTarget(AudioTarget.piSpeaker);
    } else {
      AudioPlayerService.instance.setAudioTarget(AudioTarget.phoneLocal);
    }
    notifyListeners();
  }

  /// Calculates dynamic gain offsets based on Venue + Perspective and pushes to EqualizerService
  void applyCurrentAcoustics() {
    if (!_isConcertAcousticsActive) return;

    final eq = EqualizerService.instance;
    eq.setEnabled(true);

    // Apply Venue EQ Base
    if (_currentVenue.enable16d) {
      eq.set16dAudio(true);
    } else if (_currentVenue.virtualizer >= 0.7) {
      eq.set8dAudio(true);
    } else {
      eq.setPreset(_currentVenue.eqPreset);
    }

    switch (_currentPerspective) {
      case StagePerspective.frontRow:
        eq.setBassBoost((_currentVenue.bassBoost * 1.25).clamp(0.0, 1.0));
        eq.setVirtualizer((_currentVenue.virtualizer * 0.85).clamp(0.0, 1.0));
        break;
      case StagePerspective.vipSoundboard:
        eq.setBassBoost(_currentVenue.bassBoost);
        eq.setVirtualizer(_currentVenue.virtualizer);
        break;
      case StagePerspective.stadiumBleachers:
        eq.setBassBoost((_currentVenue.bassBoost * 1.35).clamp(0.0, 1.0));
        eq.setVirtualizer(math.min(1.0, _currentVenue.virtualizer * 1.2));
        break;
    }
  }

  // --- Concert Switcher ---
  void selectConcert(LiveConcert concert, AudioPlayerService audioService) {
    _currentConcert = concert;
    _liveAudienceCount = concert.baseAudience + _random.nextInt(500);
    if (concert.setlist.isNotEmpty) {
      audioService.playTrack(concert.setlist.first);
      applyCurrentAcoustics();
    }
    notifyListeners();
  }

  /// Converts any regular track currently playing into a live stadium concert performance
  void convertTrackToConcertPerformance(Track track, AudioPlayerService audioService) {
    final liveTrack = track.copyWith(
      title: '${track.title} (Live at ${_currentVenue.name})',
      album: 'OpenAAMPS Live Arena Stage',
      codec: 'FLAC 24-bit 96kHz Arena Reverb',
    );
    audioService.playTrack(liveTrack);
    applyCurrentAcoustics();
    triggerReaction('spark');
    triggerReaction('cheer');
    notifyListeners();
  }

  // --- Fan Interaction & Lightstick ---
  void toggleLightstick(bool active) {
    _isLightstickActive = active;
    notifyListeners();
  }

  void setLightstickColor(Color color) {
    _lightstickColor = color;
    notifyListeners();
  }

  void setLightstickPulseSpeed(double speed) {
    _lightstickPulseSpeed = speed.clamp(0.2, 3.0);
    notifyListeners();
  }

  void toggleStrobeMode(bool enabled) {
    _isStrobeMode = enabled;
    notifyListeners();
  }

  void postShoutout(String message, {String userName = 'You (VIP Listener)'}) {
    if (message.trim().isEmpty) return;
    final shoutout = FanShoutout(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userName: userName,
      city: 'Concert Pit VIP',
      message: message.trim(),
      badge: 'VIP PIT',
      avatarColor: _currentVenue.primaryColor,
      timestamp: DateTime.now(),
    );
    _shoutouts.insert(0, shoutout);
    notifyListeners();
  }

  void triggerReaction(String reactionType) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final x = 0.15 + (_random.nextDouble() * 0.70);
    final reaction = FloatingReaction(
      id: id,
      reactionType: reactionType,
      xOffset: x,
      color: _currentVenue.primaryColor,
      createdAt: DateTime.now(),
    );
    _reactions.add(reaction);
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 3500), () {
      _reactions.removeWhere((r) => r.id == id);
      notifyListeners();
    });
  }

  /// Plays synthesized stadium cheer burst / crowd applause effect
  Future<void> triggerCrowdCheer() async {
    triggerReaction('cheer');
    triggerReaction('fire');
    triggerReaction('spark');
    _liveAudienceCount += _random.nextInt(30) + 10;
    notifyListeners();
  }

  @override
  void dispose() {
    _audienceTimer?.cancel();
    _shoutoutTimer?.cancel();
    _sfxPlayer?.dispose();
    super.dispose();
  }
}
