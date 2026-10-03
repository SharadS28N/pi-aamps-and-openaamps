import 'package:flutter/material.dart';
import '../services/artist_metadata_service.dart';

class ArtistPortrait extends StatefulWidget {
  final String artistName;
  final String? fallbackUrl;
  final double size;
  final bool isCircle;
  final double borderRadius;
  final BoxBorder? border;

  const ArtistPortrait({
    super.key,
    required this.artistName,
    this.fallbackUrl,
    this.size = 60,
    this.isCircle = true,
    this.borderRadius = 14,
    this.border,
  });

  @override
  State<ArtistPortrait> createState() => _ArtistPortraitState();
}

class _ArtistPortraitState extends State<ArtistPortrait> {
  String? _resolvedUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resolvePortrait();
  }

  @override
  void didUpdateWidget(covariant ArtistPortrait oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistName != widget.artistName || oldWidget.fallbackUrl != widget.fallbackUrl) {
      _resolvePortrait();
    }
  }

  Future<void> _resolvePortrait() async {
    final name = widget.artistName.trim();
    if (name.isNotEmpty) {
      final verified = await ArtistMetadataService.instance.getArtistImageUrl(name);
      if (verified != null && verified.isNotEmpty) {
        if (mounted) setState(() => _resolvedUrl = verified);
        return;
      }
    }

    final directUrl = widget.fallbackUrl;
    if (directUrl != null &&
        directUrl.isNotEmpty &&
        !directUrl.contains('unsplash.com') &&
        !directUrl.contains('ytimg.com') &&
        !directUrl.contains('googleusercontent.com') &&
        directUrl.startsWith('http')) {
      if (mounted) setState(() => _resolvedUrl = directUrl);
      return;
    }

    if (name.isEmpty) return;

    if (mounted) setState(() => _isLoading = true);
    final url = await ArtistMetadataService.instance.getArtistImageUrl(name);
    if (mounted) {
      setState(() {
        _resolvedUrl = url;
        _isLoading = false;
      });
    }
  }

  String _getInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'A';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.isCircle ? BorderRadius.circular(widget.size / 2) : BorderRadius.circular(widget.borderRadius);

    Widget imageContent;

    if (_resolvedUrl != null && _resolvedUrl!.isNotEmpty) {
      imageContent = Image.network(
        _resolvedUrl!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildInitialsFallback(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingPlaceholder();
        },
      );
    } else if (_isLoading) {
      imageContent = _buildLoadingPlaceholder();
    } else {
      imageContent = _buildInitialsFallback();
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: widget.border,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: imageContent,
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: widget.size,
      height: widget.size,
      color: const Color(0xFF1E1E24),
      child: Center(
        child: SizedBox(
          width: widget.size * 0.35,
          height: widget.size * 0.35,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white24,
          ),
        ),
      ),
    );
  }

  Widget _buildInitialsFallback() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A2A32),
            Color(0xFF15151A),
          ],
        ),
      ),
      child: Center(
        child: Text(
          _getInitials(widget.artistName),
          style: TextStyle(
            color: Colors.white70,
            fontSize: widget.size * 0.36,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
