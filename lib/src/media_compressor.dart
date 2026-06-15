import 'dart:async';
import 'package:flutter/services.dart';
import 'package:media_compressor/media_compressor.dart';

/// Entry point for compressing images and videos across Android, iOS, and Web.
///
/// All methods are static, return a [CompressionResult] (never throw), and on
/// web return a blob object URL as `path`.
abstract final class MediaCompressor {
  static const MethodChannel _channel = MethodChannel('native_compressor');

  static CompressionResult _mapError(Object e, {required String context}) {
    if (e is PlatformException) {
      return CompressionResult.failure(CompressionError(
        code: e.code,
        message: e.message ?? 'Platform error during $context',
        details: e.details,
      ));
    }
    if (e is MissingPluginException) {
      return CompressionResult.failure(CompressionError(
        code: 'UNSUPPORTED_PLATFORM',
        message: 'No $context implementation on this platform.',
      ));
    }
    if (e is TimeoutException) {
      return CompressionResult.failure(CompressionError(
        code: 'TIMEOUT',
        message: e.message ?? '$context timed out',
      ));
    }
    return CompressionResult.failure(CompressionError(
      code: 'UNKNOWN_ERROR',
      message: 'Unexpected error during $context: $e',
    ));
  }

  static CompressionResult? _validatePath(String path) {
    if (path.trim().isEmpty) {
      return CompressionResult.failure(const CompressionError(
        code: 'INVALID_ARGUMENT',
        message: 'A non-empty file path is required',
      ));
    }
    return null;
  }

  /// Compress an image. Returns a [CompressionResult].
  static Future<CompressionResult> compressImage(
    ImageCompressionConfig config,
  ) async {
    final invalid = _validatePath(config.path);
    if (invalid != null) return invalid;
    try {
      final result =
          await _channel.invokeMethod<String>('compressImage', config.toMap());
      if (result != null && result.isNotEmpty) {
        return CompressionResult.success(result);
      }
      return CompressionResult.failure(const CompressionError(
        code: 'NULL_RESULT',
        message: 'Compression returned a null or empty result',
      ));
    } catch (e) {
      return _mapError(e, context: 'image compression');
    }
  }

  /// Compress a video. [timeout] defaults to 5 minutes. Only one video job runs
  /// at a time on every platform; a concurrent call fails with code `BUSY`.
  static Future<CompressionResult> compressVideo(
    VideoCompressionConfig config, {
    Duration? timeout,
  }) async {
    final invalid = _validatePath(config.path);
    if (invalid != null) return invalid;
    try {
      final effectiveTimeout = timeout ?? const Duration(minutes: 5);
      final result = await _channel
          .invokeMethod<String>('compressVideo', config.toMap())
          .timeout(
        effectiveTimeout,
        onTimeout: () {
          cancel(); // ask the platform to abort the (single) in-flight job
          throw TimeoutException(
            'Video compression timed out',
            effectiveTimeout,
          );
        },
      );
      if (result != null && result.isNotEmpty) {
        return CompressionResult.success(result);
      }
      return CompressionResult.failure(const CompressionError(
        code: 'NULL_RESULT',
        message: 'Compression returned a null or empty result',
      ));
    } catch (e) {
      return _mapError(e, context: 'video compression');
    }
  }

  /// Abort the in-flight video compression, if any. Safe no-op otherwise.
  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // not implemented on this platform
    } on PlatformException {
      // ignore
    } catch (_) {}
  }

  /// Release resources for a compressed [path] (revokes the blob URL on web;
  /// deletes the temp file on Android/iOS — only within the plugin cache).
  /// Never throws.
  static Future<void> release(String path) async {
    if (path.trim().isEmpty) return;
    try {
      await _channel.invokeMethod<void>('release', {'path': path});
    } on MissingPluginException {
      // nothing to release
    } on PlatformException {
      // best-effort
    } catch (_) {}
  }

  /// Convenience: release [result] if it succeeded.
  static Future<void> releaseResult(CompressionResult result) async {
    final path = result.path;
    if (path != null && path.isNotEmpty) await release(path);
  }
}