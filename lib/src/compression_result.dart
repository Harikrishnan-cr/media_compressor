/// Result of a compression operation.
class CompressionResult {
  /// Path/URL to the compressed file (null if compression failed).
  final String? path;

  /// Error information if compression failed (null if successful).
  final CompressionError? error;

  bool get isSuccess => path != null && error == null;
  bool get isFailure => !isSuccess;

  const CompressionResult({this.path, this.error});

  factory CompressionResult.success(String path) =>
      CompressionResult(path: path);

  factory CompressionResult.failure(CompressionError error) =>
      CompressionResult(error: error);

  @override
  String toString() => isSuccess
      ? 'CompressionResult.success(path: $path)'
      : 'CompressionResult.failure(error: $error)';
}

/// Error information for failed compression operations.
///
/// Common codes: `INVALID_ARGUMENT`, `FILE_NOT_FOUND`, `COMPRESSION_ERROR`,
/// `NULL_RESULT`, `TIMEOUT`, `CANCELLED`, `BUSY`, `UNSUPPORTED`,
/// `UNSUPPORTED_PLATFORM`, `LOAD_ERROR`, `PLAYBACK_ERROR`, `UNKNOWN_ERROR`.
class CompressionError {
  final String code;
  final String message;
  final dynamic details;

  const CompressionError({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => details != null
      ? 'CompressionError(code: $code, message: $message, details: $details)'
      : 'CompressionError(code: $code, message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompressionError &&
          other.code == code &&
          other.message == message &&
          other.details == details);

  @override
  int get hashCode => code.hashCode ^ message.hashCode ^ details.hashCode;
}