/// Configuration for image compression
class ImageCompressionConfig {
  /// Path to the image file
  final String path;

  /// Quality of compression (0-100)
  /// Higher value means better quality but larger file size
  final int quality;

  /// Maximum width of the output image
  /// If null, original width is used
  final int? maxWidth;

  /// Maximum height of the output image
  /// If null, original height is used
  final int? maxHeight;

  const ImageCompressionConfig({
    required this.path,
    this.quality = 80,
    this.maxWidth,
    this.maxHeight,
  }) : assert(quality >= 0 && quality <= 100, 'Quality must be between 0 and 100');

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'quality': quality,
      if (maxWidth != null) 'maxWidth': maxWidth,
      if (maxHeight != null) 'maxHeight': maxHeight,
    };
  }
}

/// Configuration for video compression
class VideoCompressionConfig {
  /// Path to the video file
  final String path;

  /// Quality preset for compression
  final VideoQuality quality;

  const VideoCompressionConfig({
    required this.path,
    this.quality = VideoQuality.medium,
  });

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'quality': quality.value,
    };
  }
}

/// Video quality presets
enum VideoQuality {
  low('low'),
  medium('medium'),
  high('high');

  final String value;
  const VideoQuality(this.value);
}