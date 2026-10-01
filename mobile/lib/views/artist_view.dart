import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/artist_metadata_service.dart';
import '../services/youtube_service.dart';

class ArtistView extends StatefulWidget {
  final String artistName;
  final String avatarUrl;
  final AudioPlayerService audioService;
  final Function(Track) onPlayTrack;

  const ArtistView({
    super.key,
    required this.artistName,
    required this.avatarUrl,
    required this.audioService,
    required this.onPlayTrack,
  });

  @override
  State<ArtistView> createState() => _ArtistViewState();
}

class _ArtistViewState extends State<ArtistView> {
  List<Track> _topSongs = [];
  bool _isLoading = true;
  String? _heroPortraitUrl;
  int _fansCount = 0;
  int _albumsCount = 0;
  String _latestReleaseTitle = 'Top Hits & Singles';
  String _latestReleaseCover = '';

  @override
  void initState() {
    super.initState();
    _heroPortraitUrl = widget.avatarUrl.isNotEmpty && !widget.avatarUrl.contains('unsplash.com')
        ? widget.avatarUrl
        : null;
    _loadArtistData();
  }

  Future<void> _loadArtistData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Fetch official artist metadata and top tracks from Deezer
      final details = await ArtistMetadataService.instance.getArtistDetails(widget.artistName);
      if (details != null) {
        if (_heroPortraitUrl == null || _heroPortraitUrl!.isEmpty) {
          _heroPortraitUrl = details.imageUrl;
        }
        _fansCount = details.fansCount;
        _albumsCount = details.albumsCount;
        if (details.topTracks.isNotEmpty) {
          _topSongs = List.from(details.topTracks);
          _latestReleaseTitle = details.topTracks.first.album;
          _latestReleaseCover = details.topTracks.first.artworkUrl;
        }
      }

      // 2. Fetch full playable YouTube Music streams for this artist
      final ytTracks = await YoutubeService().searchTracks('${widget.artistName} greatest hits audio');
      if (ytTracks.isNotEmpty) {
        if (_topSongs.isEmpty) {
          _topSongs = ytTracks;
          if (_latestReleaseCover.isEmpty) {
            _latestReleaseCover = ytTracks.first.artworkUrl;
            _latestReleaseTitle = ytTracks.first.title;
          }
        } else {
          // Replace preview tracks with full playable YouTube tracks matching titles
          final merged = <Track>[];
          for (final yt in ytTracks) {
            merged.add(Track(
              id: yt.id,
              title: yt.title,
              artist: widget.artistName,
              album: yt.album.isNotEmpty ? yt.album : widget.artistName,
              duration: yt.duration,
              artworkUrl: yt.artworkUrl,
              streamUrl: '',
              codec: 'AAC 320kbps',
            ));
            if (merged.length >= 15) break;
          }
          _topSongs = merged;
        }
      }

      // If portrait still missing, query artist metadata image
      if (_heroPortraitUrl == null || _heroPortraitUrl!.isEmpty) {
        _heroPortraitUrl = await ArtistMetadataService.instance.getArtistImageUrl(widget.artistName);
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _formatFans(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M fans';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(0)}K fans';
    } else if (count > 0) {
      return '$count fans';
    }
    return 'Verified Artist';
  }

  @override
  Widget build(BuildContext context) {
    final portrait = _heroPortraitUrl ?? widget.avatarUrl;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: CustomScrollView(
        slivers: [
          // Hero Header Image & Artist Info
          SliverAppBar(
            expandedHeight: 380,
            pinned: true,
            backgroundColor: const Color(0xFF000000),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  portrait.isNotEmpty
                      ? Image.network(
                          portrait,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFF1E1E24),
                            child: Center(
                              child: Text(
                                widget.artistName.isNotEmpty
                                    ? widget.artistName.substring(0, 1).toUpperCase()
                                    : 'A',
                                style: const TextStyle(fontSize: 72, color: Colors.white24, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        )
                      : Container(color: const Color(0xFF1A1A22)),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                          const Color(0xFF000000),
                        ],
                        stops: const [0.0, 0.4, 0.85, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      children: [
                        Text(
                          widget.artistName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_formatFans(_fansCount)} • ${_albumsCount > 0 ? "$_albumsCount Albums • " : ""}${_topSongs.length} Songs',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Actions Row (Shuffle, Play, Follow Check, Radio)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white12,
                              child: IconButton(
                                icon: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 22),
                                onPressed: () {
                                  if (_topSongs.isNotEmpty) {
                                    final shuffled = List<Track>.from(_topSongs)..shuffle();
                                    widget.onPlayTrack(shuffled.first);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
                              label: const Text('Play', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                if (_topSongs.isNotEmpty) {
                                  widget.onPlayTrack(_topSongs.first);
                                }
                              },
                            ),
                            const SizedBox(width: 16),
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white12,
                              child: IconButton(
                                icon: const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 22),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Added ${widget.artistName} to your followed artists!')),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Latest Release Section
                  if (_latestReleaseCover.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              _latestReleaseCover,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 72,
                                height: 72,
                                color: Colors.white10,
                                child: const Icon(Icons.album_rounded, color: Colors.white54),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FEATURED RELEASE',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _latestReleaseTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Official release by ${widget.artistName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Top Songs Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Top songs',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Top Songs List
                  if (_topSongs.isEmpty && _isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  else if (_topSongs.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text(
                          'No tracks found for ${widget.artistName}',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _topSongs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final track = _topSongs[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              track.artworkUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 50,
                                height: 50,
                                color: Colors.white12,
                                child: const Icon(Icons.music_note_rounded, color: Colors.white),
                              ),
                            ),
                          ),
                          title: Text(
                            track.title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${track.artist} • ${track.album}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${track.duration.inMinutes}:${(track.duration.inSeconds % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
                                onPressed: () => widget.onPlayTrack(track),
                              ),
                            ],
                          ),
                          onTap: () => widget.onPlayTrack(track),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
