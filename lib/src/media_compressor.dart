import 'package:flutter/services.dart';
import 'compression_config.dart';
import 'compression_result.dart';

/// Main class for media compression operations
class MediaCompressor {
  static const MethodChannel _channel = MethodChannel('native_compressor');

  /// Compress an image file
  ///
  /// Returns a [CompressionResult] containing the path to the compressed image
  /// or an error if compression failed.
  ///
  /// Example:
  /// ```dart
  /// final result = await MediaCompressor.compressImage(
  ///   ImageCompressionConfig(
  ///     path: '/path/to/image.jpg',
  ///     quality: 80,
  ///     maxWidth: 1920,
  ///     maxHeight: 1080,
  ///   ),
  /// );
  ///
  /// if (result.isSuccess) {
  ///   print('Compressed image: ${result.path}');
  /// } else {
  ///   print('Error: ${result.error}');
  /// }
  /// ```
  static Future<CompressionResult> compressImage(
    ImageCompressionConfig config,
  ) async {
    try {
      final String? result = await _channel.invokeMethod(
        'compressImage',
        config.toMap(),
      );

      if (result != null) {
        return CompressionResult.success(result);
      } else {
        return CompressionResult.failure(
          const CompressionError(
            code: 'NULL_RESULT',
            message: 'Compression returned null result',
          ),
        );
      }
    } on PlatformException catch (e) {
      return CompressionResult.failure(
        CompressionError(
          code: e.code,
          message: e.message ?? 'Unknown error',
          details: e.details,
        ),
      );
    } catch (e) {
      return CompressionResult.failure(
        CompressionError(
          code: 'UNKNOWN_ERROR',
          message: e.toString(),
        ),
      );
    }
  }

  /// Compress a video file
  ///
  /// Returns a [CompressionResult] containing the path to the compressed video
  /// or an error if compression failed.
  ///
  /// Example:
  /// ```dart
  /// final result = await MediaCompressor.compressVideo(
  ///   VideoCompressionConfig(
  ///     path: '/path/to/video.mp4',
  ///     quality: VideoQuality.medium,
  ///   ),
  /// );
  ///
  /// if (result.isSuccess) {
  ///   print('Compressed video: ${result.path}');
  /// } else {
  ///   print('Error: ${result.error}');
  /// }
  /// ```
 static Future<CompressionResult> compressVideo(
    VideoCompressionConfig config,
  ) async {
    try {
      final String? result = await _channel.invokeMethod(
        'compressVideo',
        config.toMap(),
      );

      if (result != null) {
        return CompressionResult.success(result);
      } else {
        return CompressionResult.failure(
          const CompressionError(
            code: 'NULL_RESULT',
            message: 'Compression returned null result',
          ),
        );
      }
    } on PlatformException catch (e) {
      return CompressionResult.failure(
        CompressionError(
          code: e.code,
          message: e.message ?? 'Unknown error',
          details: e.details,
        ),
      );
    } catch (e) {
      return CompressionResult.failure(
        CompressionError(
          code: 'UNKNOWN_ERROR',
          message: e.toString(),
        ),
      );
    }
  }
}