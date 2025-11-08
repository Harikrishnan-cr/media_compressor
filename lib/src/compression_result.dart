/// Result of a compression operation
class CompressionResult {
  /// Path to the compressed file
  final String? path;

  /// Error information if compression failed
  final CompressionError? error;

  /// Whether the compression was successful
  bool get isSuccess => path != null && error == null;

  const CompressionResult({
    this.path,
    this.error,
  });

  factory CompressionResult.success(String path) {
    return CompressionResult(path: path);
  }

  factory CompressionResult.failure(CompressionError error) {
    return CompressionResult(error: error);
  }
}

/// Error information for failed compression
class CompressionError {
  /// Error code
  final String code;

  /// Error message
  final String message;

  /// Additional error details
  final dynamic details;

  const CompressionError({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() {
    return 'CompressionError(code: $code, message: $message, details: $details)';
  }
}