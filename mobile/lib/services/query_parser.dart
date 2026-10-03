class ParsedMusicQuery {
  final String rawQuery;
  final String cleanSearchTerm;
  final String? artistFilter;
  final String? albumFilter;
  final String? genreFilter;
  final int? releaseYear;
  final Duration? minDuration;
  final Duration? maxDuration;
  final bool filterDownloadedOnly;
  final bool filterFavoritesOnly;
  final bool isNaturalLanguage;
  final String? correctedTerm;

  ParsedMusicQuery({
    required this.rawQuery,
    required this.cleanSearchTerm,
    this.artistFilter,
    this.albumFilter,
    this.genreFilter,
    this.releaseYear,
    this.minDuration,
    this.maxDuration,
    this.filterDownloadedOnly = false,
    this.filterFavoritesOnly = false,
    this.isNaturalLanguage = false,
    this.correctedTerm,
  });

  bool get hasFilters =>
      artistFilter != null ||
      albumFilter != null ||
      genreFilter != null ||
      releaseYear != null ||
      minDuration != null ||
      maxDuration != null ||
      filterDownloadedOnly ||
      filterFavoritesOnly;

  @override
  String toString() {
    return 'ParsedMusicQuery(term: "$cleanSearchTerm", artist: $artistFilter, genre: $genreFilter, year: $releaseYear)';
  }
}

class NaturalQueryParser {
  static final NaturalQueryParser instance = NaturalQueryParser._internal();
  NaturalQueryParser._internal();

  // Known typo and phonetic normalization dictionary
  static final Map<String, String> _phoneticCorrections = {
    'blinding lites': 'Blinding Lights',
    'blinding light': 'Blinding Lights',
    'blnding lights': 'Blinding Lights',
    'star boy': 'Starboy',
    'daft punk': 'Daft Punk',
    'yellow coldplay': 'Yellow Coldplay',
    'as it was': 'As It Was',
    'as it was harry': 'As It Was Harry Styles',
    'levitating': 'Levitating Dua Lipa',
    'levtating': 'Levitating',
    'flowers miley': 'Flowers Miley Cyrus',
    'bohemian rhapsody': 'Bohemian Rhapsody Queen',
    'smells like teen spirit': 'Smells Like Teen Spirit Nirvana',
    'sajan raj': 'Sajjan Raj Vaidya',
    'sajjan raj': 'Sajjan Raj Vaidya',
    'the weekend': 'The Weeknd',
    'weekend': 'The Weeknd',
  };

  ParsedMusicQuery parse(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      return ParsedMusicQuery(rawQuery: '', cleanSearchTerm: '');
    }

    String working = raw.toLowerCase();
    String? artist;
    String? album;
    String? genre;
    int? releaseYear;
    Duration? minDuration;
    Duration? maxDuration;
    bool filterDownloaded = false;
    bool filterFavorites = false;
    bool isNatural = false;

    // Check for "downloaded songs" or "offline"
    if (working.contains('downloaded') || working.contains('offline')) {
      filterDownloaded = true;
      isNatural = true;
      working = working.replaceAll('downloaded', '').replaceAll('offline', '').trim();
    }

    // Check for "favorite songs" / "five-star" / "liked"
    if (working.contains('favorite') || working.contains('five-star') || working.contains('liked')) {
      filterFavorites = true;
      isNatural = true;
      working = working
          .replaceAll('favorite', '')
          .replaceAll('five-star', '')
          .replaceAll('liked', '')
          .trim();
    }

    // Check for duration: "longer than X minutes" or "shorter than X minutes"
    final longerRegex = RegExp(r'longer than (\d+)\s*(?:min|minute|minutes)?');
    final longerMatch = longerRegex.firstMatch(working);
    if (longerMatch != null) {
      final mins = int.tryParse(longerMatch.group(1) ?? '0');
      if (mins != null && mins > 0) {
        minDuration = Duration(minutes: mins);
        isNatural = true;
        working = working.replaceAll(longerMatch.group(0)!, '').trim();
      }
    }

    final shorterRegex = RegExp(r'shorter than (\d+)\s*(?:min|minute|minutes)?');
    final shorterMatch = shorterRegex.firstMatch(working);
    if (shorterMatch != null) {
      final mins = int.tryParse(shorterMatch.group(1) ?? '0');
      if (mins != null && mins > 0) {
        maxDuration = Duration(minutes: mins);
        isNatural = true;
        working = working.replaceAll(shorterMatch.group(0)!, '').trim();
      }
    }

    // Check for release year: "released in 2013", "from 2013", "in 1999"
    final yearRegex = RegExp(r'(?:released in|from|in)\s+(\b19\d{2}\b|\b20\d{2}\b)');
    final yearMatch = yearRegex.firstMatch(working);
    if (yearMatch != null) {
      final y = int.tryParse(yearMatch.group(1) ?? '');
      if (y != null) {
        releaseYear = y;
        isNatural = true;
        working = working.replaceAll(yearMatch.group(0)!, '').trim();
      }
    }

    // Check for "songs by [Artist]" / "tracks by [Artist]" / "by [Artist]"
    final byArtistRegex = RegExp(r'(?:songs by|tracks by|music by|by)\s+([a-zA-Z0-9\s]+)$');
    final byArtistMatch = byArtistRegex.firstMatch(working);
    if (byArtistMatch != null) {
      artist = byArtistMatch.group(1)?.trim();
      isNatural = true;
      working = working.substring(0, byArtistMatch.start).trim();
    }

    // Check for "albums released in..." or "album [AlbumName]"
    final albumRegex = RegExp(r'(?:album|album by)\s+([a-zA-Z0-9\s]+)');
    final albumMatch = albumRegex.firstMatch(working);
    if (albumMatch != null) {
      album = albumMatch.group(1)?.trim();
      isNatural = true;
      working = working.replaceAll(albumMatch.group(0)!, '').trim();
    }

    // Check for genre: "rock songs", "pop music", "acoustic songs", "lofi beats"
    const knownGenres = [
      'rock',
      'pop',
      'lo-fi',
      'lofi',
      'synthwave',
      'acoustic',
      'jazz',
      'classical',
      'hip hop',
      'r&b',
      'electronic',
      'metal',
      'ambient',
    ];
    for (final g in knownGenres) {
      final gRegex = RegExp('\\b$g\\s+(?:songs|music|tracks|beats)\\b');
      if (gRegex.hasMatch(working)) {
        genre = g.toUpperCase();
        isNatural = true;
        working = working.replaceAll(gRegex, '').trim();
        break;
      }
    }

    // Clean remaining search phrase
    working = working
        .replaceAll(RegExp(r'\b(songs|tracks|music)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Check phonetic/typo dictionary
    String cleanTerm = working.isNotEmpty ? working : (artist ?? genre ?? raw);
    String? correction;
    for (final entry in _phoneticCorrections.entries) {
      if (cleanTerm.toLowerCase().contains(entry.key)) {
        correction = entry.value;
        break;
      }
    }

    return ParsedMusicQuery(
      rawQuery: raw,
      cleanSearchTerm: correction ?? (cleanTerm.isNotEmpty ? cleanTerm : raw),
      artistFilter: artist,
      albumFilter: album,
      genreFilter: genre,
      releaseYear: releaseYear,
      minDuration: minDuration,
      maxDuration: maxDuration,
      filterDownloadedOnly: filterDownloaded,
      filterFavoritesOnly: filterFavorites,
      isNaturalLanguage: isNatural,
      correctedTerm: correction,
    );
  }
}
