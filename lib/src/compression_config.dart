/// Configuration for image compression operations.
class ImageCompressionConfig {
  /// Path to the image file to compress (a blob URL on web).
  final String path;

  /// Compression quality (0-100). Default: 80.
  final int quality;

  /// Optional maximum width in pixels (scales down if larger).
  final int? maxWidth;

  /// Optional maximum height in pixels (scales down if larger).
  final int? maxHeight;

  const ImageCompressionConfig({
    required this.path,
    this.quality = 80,
    this.maxWidth,
    this.maxHeight,
  }) : assert(
          quality >= 0 && quality <= 100,
          'Quality must be between 0 and 100',
        );

  Map<String, dynamic> toMap() => {
        'path': path,
        'quality': quality,
        if (maxWidth != null) 'maxWidth': maxWidth,
        if (maxHeight != null) 'maxHeight': maxHeight,
      };

  @override
  String toString() =>
      'ImageCompressionConfig(path: $path, quality: $quality, '
      'maxWidth: $maxWidth, maxHeight: $maxHeight)';
}

/// Configuration for video compression operations.
class VideoCompressionConfig {
  /// Path to the video file to compress (a blob URL on web).
  final String path;

  /// Quality preset for compression. Default: [VideoQuality.medium].
  final VideoQuality quality;

  const VideoCompressionConfig({
    required this.path,
    this.quality = VideoQuality.medium,
  });

  Map<String, dynamic> toMap() => {'path': path, 'quality': quality.value};

  @override
  String toString() =>
      'VideoCompressionConfig(path: $path, quality: ${quality.value})';
}

/// Video quality presets for compression.
enum VideoQuality {
  /// 480p — smaller file, lower quality.
  low('low'),

  /// 720p — balanced (recommended).
  medium('medium'),

  /// 1080p — larger file, higher quality.
  high('high');

  final String value;
  const VideoQuality(this.value);
}