class PlaybackSource {
  final Uri uri;
  final String mimeType;
  final String codec; // OPUS, AAC, MP3, FLAC
  final int bitrate; // bits per second
  final int sampleRate; // Hz (44100, 48000, 96000)
  final int channelCount; // 1 (mono), 2 (stereo)
  final Duration duration;
  final Map<String, String> headers;
  final bool isSeekable;
  final bool isLive;
  final DateTime? expiresAt;
  final String providerId;

  PlaybackSource({
    required this.uri,
    this.mimeType = 'audio/webm; codecs=opus',
    this.codec = 'OPUS',
    this.bitrate = 160000,
    this.sampleRate = 48000,
    this.channelCount = 2,
    this.duration = Duration.zero,
    Map<String, String>? headers,
    this.isSeekable = true,
    this.isLive = false,
    this.expiresAt,
    this.providerId = 'default',
  }) : headers = headers ?? const {};

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  String get qualityDescriptor {
    if (codec == 'FLAC') return 'Lossless 24-bit';
    if (bitrate >= 256000) return 'Very High (${(bitrate / 1000).round()}kbps)';
    if (bitrate >= 160000) return 'High (${(bitrate / 1000).round()}kbps)';
    return 'Standard (${(bitrate / 1000).round()}kbps)';
  }
}
