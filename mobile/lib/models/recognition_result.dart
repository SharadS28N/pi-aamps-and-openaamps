import 'track.dart';

enum RecognitionSourceType {
  microphone,
  audioFile,
  systemAudio,
}

enum RecognitionMethod {
  hummingMelody,
  voiceSpeech,
  acousticFingerprint,
}

class MelodicContour {
  final List<double> pitchFrequencies;
  final List<int> intervals;
  final String parsonCode;
  final double estimatedBpm;
  final double meanEnergy;

  MelodicContour({
    required this.pitchFrequencies,
    required this.intervals,
    required this.parsonCode,
    this.estimatedBpm = 120.0,
    this.meanEnergy = 0.5,
  });

  Map<String, dynamic> toJson() => {
        'pitchFrequencies': pitchFrequencies,
        'intervals': intervals,
        'parsonCode': parsonCode,
        'estimatedBpm': estimatedBpm,
        'meanEnergy': meanEnergy,
      };
}

class AcousticFingerprint {
  final String hash;
  final List<int> peakFrequencies;
  final double durationSeconds;
  final double signalToNoiseRatio;

  AcousticFingerprint({
    required this.hash,
    required this.peakFrequencies,
    required this.durationSeconds,
    this.signalToNoiseRatio = 18.5,
  });

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'peakFrequencies': peakFrequencies,
        'durationSeconds': durationSeconds,
        'signalToNoiseRatio': signalToNoiseRatio,
      };
}

class RecognitionResult {
  final Track track;
  final double confidence; // 0.0 to 1.0
  final RecognitionMethod method;
  final RecognitionSourceType sourceType;
  final Duration? matchedAtOffset;
  final String providerName;
  final MelodicContour? contour;
  final AcousticFingerprint? fingerprint;
  final String? recognizedTranscript;
  final Map<String, dynamic> metadata;

  RecognitionResult({
    required this.track,
    required this.confidence,
    required this.method,
    this.sourceType = RecognitionSourceType.microphone,
    this.matchedAtOffset,
    this.providerName = 'OpenAAMPS Acoustic Core',
    this.contour,
    this.fingerprint,
    this.recognizedTranscript,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(0)}%';

  bool get isHighConfidence => confidence >= 0.75;
}
