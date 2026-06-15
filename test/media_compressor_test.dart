import 'package:flutter_test/flutter_test.dart';
import 'package:media_compressor/media_compressor.dart';

void main() {
  group('ImageCompressionConfig', () {
    test('toMap includes only provided optional fields', () {
      final c = ImageCompressionConfig(path: 'a.jpg', quality: 70);
      expect(c.toMap(), {'path': 'a.jpg', 'quality': 70});

      final c2 = ImageCompressionConfig(
          path: 'a.jpg', quality: 70, maxWidth: 100, maxHeight: 200);
      expect(c2.toMap(),
          {'path': 'a.jpg', 'quality': 70, 'maxWidth': 100, 'maxHeight': 200});
    });

    test('asserts quality range', () {
      expect(() => ImageCompressionConfig(path: 'a.jpg', quality: 101),
          throwsA(isA<AssertionError>()));
      expect(() => ImageCompressionConfig(path: 'a.jpg', quality: -1),
          throwsA(isA<AssertionError>()));
    });
  });

  group('VideoCompressionConfig / VideoQuality', () {
    test('maps quality value', () {
      expect(
          VideoCompressionConfig(path: 'v.mp4', quality: VideoQuality.high)
              .toMap(),
          {'path': 'v.mp4', 'quality': 'high'});
    });

    test('quality string values', () {
      expect(VideoQuality.low.value, 'low');
      expect(VideoQuality.medium.value, 'medium');
      expect(VideoQuality.high.value, 'high');
    });
  });

  group('CompressionResult', () {
    test('success/failure flags', () {
      final ok = CompressionResult.success('/tmp/out.jpg');
      expect(ok.isSuccess, isTrue);
      expect(ok.isFailure, isFalse);
      expect(ok.path, '/tmp/out.jpg');

      final fail = CompressionResult.failure(
          const CompressionError(code: 'X', message: 'm'));
      expect(fail.isSuccess, isFalse);
      expect(fail.isFailure, isTrue);
      expect(fail.error?.code, 'X');
    });
  });

  group('CompressionError', () {
    test('equality and hashCode', () {
      const a = CompressionError(code: 'A', message: 'm');
      const b = CompressionError(code: 'A', message: 'm');
      const c = CompressionError(code: 'B', message: 'm');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}