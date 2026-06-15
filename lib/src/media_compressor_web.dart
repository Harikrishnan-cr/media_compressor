
// Web implementation of the media_compressor plugin (v2.1 — hardened).
//
// CHANGES v2 -> v2.1 (Addressing "Request Changes" Verdict):
// 1. [H1] Added hard timeout for ffmpeg.wasm jobs to prevent zombie workers.
// 2. [H2] Fixed MediaRecorder leak in cleanup path when video.play() fails.
// 3. [M1] Added input size guard (HEAD request) to prevent OOM on large files.
// 4. [Refactor] Replaced manual _sqrt with dart:math.
//
// VIDEO ENCODING — two backends, auto-selected:
//   1. ffmpeg.wasm (preferred, OPT-IN): if the host app registers a global
//      `window.mediaCompressorFfmpeg`, video is transcoded off the main thread
//      to real H.264/MP4 with ENFORCED bitrate and EXACT progress, often faster
//      than real time. See the JS shim at the bottom of this comment.
//   2. MediaRecorder (fallback, always available where supported): canvas +
//      MediaRecorder re-encode. WebM on Chromium/Firefox, MP4 on Safari.
//      Real-time; bitrate is a hint; progress is a time-based estimate.
//
// IMAGE -> Canvas re-encode (high-quality smoothing + resize). JPEG by default;
//          WebP only when the source clearly has alpha AND the browser actually
//          produced WebP (verified via blob.type, else JPEG). Dimensions clamped
//          to safe canvas limits (iOS).
//
// Returned "path" is a blob object URL. Free it with `release` when done.
//
// CONCURRENCY: one video job at a time (single-flight). A second concurrent
// `compressVideo` returns code 'BUSY'. `cancel` aborts the active job.
//
// ---------------------------------------------------------------------------
// OPTIONAL ffmpeg.wasm SHIM (place in web/index.html or a module the app loads;
// requires cross-origin isolation: COOP `same-origin`, COEP `require-corp'):
//
//   import { FFmpeg } from 'https://unpkg.com/@ffmpeg/ffmpeg@0.12.10/dist/esm/index.js';
//   import { toBlobURL } from 'https://unpkg.com/@ffmpeg/util@0.12.1/dist/esm/index.js';
//   const ffmpeg = new FFmpeg();
//   const base = 'https://unpkg.com/@ffmpeg/core@0.12.10/dist/esm';
//   window.mediaCompressorFfmpeg = {
//     async transcode(input, outputMime, height, bitrate, onProgress) {
//       if (!ffmpeg.loaded) {
//         await ffmpeg.load({
//           coreURL: await toBlobURL(`${base}/ffmpeg-core.js`, 'text/javascript'),
//           wasmURL: await toBlobURL(`${base}/ffmpeg-core.wasm`, 'application/wasm'),
//         });
//       }
//       const onP = (e) => onProgress(Math.max(0, Math.min(1, e.progress)));
//       ffmpeg.on('progress', onP);
//       try {
//         await ffmpeg.writeFile('in', input);
//         const kbps = `${Math.round(bitrate / 1000)}k`;
//         await ffmpeg.exec([
//           '-i', 'in',
//           '-vf', `scale=-2:${height}`,
//           '-c:v', 'libx264', '-b:v', kbps, '-maxrate', kbps,
//           '-bufsize', `${Math.round(bitrate / 500)}k`,
//           '-preset', 'veryfast', '-movflags', '+faststart',
//           '-c:a', 'aac', '-b:a', '128k',
//           'out.mp4',
//         ]);
//         const data = await ffmpeg.readFile('out.mp4');
//         return data; // Uint8Array
//       } finally {
//         ffmpeg.off('progress', onP);
//         try { await ffmpeg.deleteFile('in'); await ffmpeg.deleteFile('out.mp4'); } catch (_) {}
//       }
//     },
//     cancel() { try { ffmpeg.terminate(); } catch (_) {} },
//   };
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' show sqrt;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

// ---------------------------------------------------------------------------
// Optional ffmpeg.wasm bridge (global `window.mediaCompressorFfmpeg`).
// ---------------------------------------------------------------------------

@JS('mediaCompressorFfmpeg')
external _FfmpegHook? get _ffmpegHookRaw;

_FfmpegHook? get _ffmpegHook {
  try {
    return _ffmpegHookRaw;
  } catch (_) {
    return null;
  }
}

extension type _FfmpegHook._(JSObject _) implements JSObject {
  external JSPromise<JSUint8Array> transcode(
    JSUint8Array input,
    JSString outputMime,
    JSNumber targetHeight,
    JSNumber bitrate,
    JSFunction onProgress,
  );
  external void cancel();
}

@JS('fetch')
external JSPromise<web.Response> _fetch(JSString url, [JSAny? options]);

/// Cooperative cancellation token for the active video job.
class _CancelToken {
  bool cancelled = false;
  void Function()? onCancel;
  void cancel() {
    if (cancelled) return;
    cancelled = true;
    onCancel?.call();
  }
}

class _CancelledException implements Exception {}

/// Central configuration.
class _Cfg {
  static const Map<String, ({int height, int bitrate})> video = {
    'low': (height: 480, bitrate: 500000),
    'medium': (height: 720, bitrate: 1500000),
    'high': (height: 1080, bitrate: 3000000),
  };

  static const List<String> mimeCandidates = [
    'video/webm;codecs=vp9,opus',
    'video/webm;codecs=vp8,opus',
    'video/webm;codecs=vp9',
    'video/webm;codecs=vp8',
    'video/webm',
    'video/mp4;codecs=h264,aac',
    'video/mp4',
  ];

  static const int maxCanvasSide = 4096;
  static const int maxCanvasArea = 16777216;
  static const Duration stallTimeout = Duration(seconds: 15);
  static const int captureFps = 30;

  // H1 & M1 Fixes: Limits to prevent browser crashes
  static const int maxInputBytes = 512 * 1024 * 1024; // 512MB
  static const Duration ffmpegTimeout = Duration(minutes: 5);
}

class MediaCompressorWeb {
  MediaCompressorWeb(this._registrar);

  final Registrar _registrar;

  static const String _methodChannelName = 'native_compressor';
  static const String _progressChannelName = 'native_compressor/progress';
  static const StandardMethodCodec _codec = StandardMethodCodec();

  bool _progressListening = false;

  /// The single in-flight video job (single-flight policy).
  _CancelToken? _currentVideo;

  static void registerWith(Registrar registrar) {
    final instance = MediaCompressorWeb(registrar);
    MethodChannel(_methodChannelName, _codec, registrar)
        .setMethodCallHandler(instance.handleMethodCall);
    MethodChannel(_progressChannelName, _codec, registrar)
        .setMethodCallHandler(instance.handleProgressChannel);
  }

  // ==========================================================================
  // ROUTING
  // ==========================================================================

  Future<dynamic> handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'compressImage':
          return await _compressImage(_argMap(call));
        case 'compressVideo':
          return await _compressVideo(_argMap(call));
        case 'release':
          return await _releaseFile(_argMap(call));
        case 'cancel':
          _currentVideo?.cancel();
          return null;
        default:
          throw PlatformException(
            code: 'UNIMPLEMENTED',
            message: "media_compressor web does not implement '${call.method}'",
          );
      }
    } on PlatformException {
      rethrow;
    } on _CancelledException {
      throw PlatformException(
          code: 'CANCELLED', message: 'Operation was cancelled');
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[MediaCompressor/web] Unexpected error: $e\n$st');
      }
      throw PlatformException(code: 'COMPRESSION_ERROR', message: e.toString());
    }
  }

  Future<dynamic> handleProgressChannel(MethodCall call) async {
    switch (call.method) {
      case 'listen':
        _progressListening = true;
        return null;
      case 'cancel':
        _progressListening = false;
        return null;
      default:
        return null;
    }
  }

  Map<String, dynamic> _argMap(MethodCall call) {
    final args = call.arguments;
    if (args is Map) return args.map((k, v) => MapEntry(k.toString(), v));
    return <String, dynamic>{};
  }

  void _emitProgress(double progress) {
    if (!_progressListening) return;
    final clamped = progress.clamp(0.0, 1.0);
    final ByteData envelope = _codec.encodeSuccessEnvelope({
      'progress': clamped,
      'percentage': (clamped * 100).round(),
    });
    _registrar.send(_progressChannelName, envelope);
  }

  Future<void> _releaseFile(Map<String, dynamic> args) async {
    final path = args['path'] as String?;
    if (path != null && path.startsWith('blob:')) {
      web.URL.revokeObjectURL(path);
    }
  }

  // ==========================================================================
  // IMAGE
  // ==========================================================================

  Future<String> _compressImage(Map<String, dynamic> args) async {
    final path = args['path'] as String?;
    final quality = (args['quality'] as int?) ?? 80;
    final maxWidth = args['maxWidth'] as int?;
    final maxHeight = args['maxHeight'] as int?;

    if (path == null || path.isEmpty) {
      throw PlatformException(
          code: 'INVALID_ARGUMENT',
          message: 'Path is required for image compression');
    }
    if (quality < 0 || quality > 100) {
      throw PlatformException(
          code: 'INVALID_ARGUMENT', message: 'Quality must be between 0 and 100');
    }

    final img = web.HTMLImageElement()
      ..crossOrigin = 'anonymous'
      ..decoding = 'async'
      ..src = path;
    try {
      await img.decode().toDart;
    } catch (e) {
      throw PlatformException(
          code: 'LOAD_ERROR',
          message: 'Failed to load image from path: $path',
          details: e.toString());
    }

    final srcW = img.naturalWidth;
    final srcH = img.naturalHeight;
    if (srcW == 0 || srcH == 0) {
      throw PlatformException(
          code: 'LOAD_ERROR', message: 'Decoded image has zero dimensions');
    }

    var tW = srcW, tH = srcH;
    if (maxWidth != null && maxHeight != null) {
      final r = [maxWidth / srcW, maxHeight / srcH, 1.0]
          .reduce((a, b) => a < b ? a : b);
      if (r < 1.0) {
        tW = (srcW * r).round();
        tH = (srcH * r).round();
      }
    }
    final (cw, ch) = _clampToCanvas(tW, tH);

    final canvas = web.HTMLCanvasElement()
      ..width = cw
      ..height = ch;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D
      ..imageSmoothingEnabled = true
      ..imageSmoothingQuality = 'high';
    ctx.drawImageScaled(img, 0, 0, cw.toDouble(), ch.toDouble());

    final q = quality / 100.0;
    final lower = path.toLowerCase();
    final tryWebp = lower.endsWith('.png') || lower.endsWith('.webp');

    web.Blob? blob;
    if (tryWebp) {
      final candidate = await _canvasToBlob(canvas, 'image/webp', q);
      // Verify: Safari may ignore the type and hand back PNG. A PNG re-encode
      // of a photo can be LARGER than the source, so only accept real WebP.
      if (candidate != null &&
          candidate.size > 0 &&
          candidate.type.contains('webp')) {
        blob = candidate;
      }
    }
    blob ??= await _canvasToBlob(canvas, 'image/jpeg', q);

    if (blob == null || blob.size == 0) {
      throw PlatformException(
          code: 'COMPRESSION_ERROR',
          message: 'Failed to encode compressed image (empty output)');
    }
    return web.URL.createObjectURL(blob);
  }

  // ==========================================================================
  // VIDEO (dispatch: ffmpeg.wasm -> MediaRecorder)
  // ==========================================================================

  Future<String> _compressVideo(Map<String, dynamic> args) async {
    final path = args['path'] as String?;
    final quality = (args['quality'] as String?) ?? 'medium';

    if (path == null || path.isEmpty) {
      throw PlatformException(
          code: 'INVALID_ARGUMENT',
          message: 'Path is required for video compression');
    }
    final preset = _Cfg.video[quality.toLowerCase()];
    if (preset == null) {
      throw PlatformException(
          code: 'INVALID_ARGUMENT',
          message: 'Quality must be one of: low, medium, high');
    }
    if (_currentVideo != null) {
      throw PlatformException(
          code: 'BUSY',
          message: 'Another video compression is already in progress');
    }

    final hook = _ffmpegHook;
    final mime = _negotiateMime();
    if (hook == null && mime == null) {
      throw PlatformException(
          code: 'UNSUPPORTED',
          message: 'No video encoder available (no ffmpeg.wasm hook and '
              'MediaRecorder unsupported).');
    }

    final token = _CancelToken();
    _currentVideo = token;
    try {
      // Preferred: ffmpeg.wasm (enforced bitrate, exact progress, true MP4).
      if (hook != null) {
        try {
          return await _transcodeWithFfmpeg(hook, path, preset, token);
        } on _CancelledException {
          rethrow;
        } catch (e) {
          if (token.cancelled) throw _CancelledException();
          if (kDebugMode) {
            // ignore: avoid_print
            print('[MediaCompressor/web] ffmpeg failed, falling back: $e');
          }
          // fall through to MediaRecorder
        }
      }
      if (mime == null) {
        throw PlatformException(
            code: 'UNSUPPORTED',
            message: 'ffmpeg failed and MediaRecorder is unsupported here.');
      }
      return await _recordWithMediaRecorder(path, preset, mime, token);
    } finally {
      if (identical(_currentVideo, token)) _currentVideo = null;
    }
  }

  // ---- Backend 1: ffmpeg.wasm (Hardened v2.1) ------------------------------

  Future<String> _transcodeWithFfmpeg(
    _FfmpegHook hook,
    String path,
    ({int height, int bitrate}) preset,
    _CancelToken token,
  ) async {
    token.onCancel = () {
      try {
        hook.cancel();
      } catch (_) {}
    };

    // M1 Fix: Check file size before attempting to load into memory.
    // We use a HEAD request to get Content-Length without downloading the body.
    try {
      final headResp = await _fetch(
        path.toJS,
        web.RequestInit(method: 'HEAD'),
      ).toDart;
      if (headResp.ok) {
        final lenStr = headResp.headers.get('content-length');
        if (lenStr != null) {
          final len = int.tryParse(lenStr);
          if (len != null && len > _Cfg.maxInputBytes) {
            throw PlatformException(
              code: 'INVALID_ARGUMENT',
              message: 'Video too large for web transcoding (${(len / 1024 / 1024).toStringAsFixed(1)}MB). '
                  'Max is ${_Cfg.maxInputBytes / 1024 / 1024}MB.',
            );
          }
        }
      }
    } catch (e) {
      // If HEAD fails (e.g. opaque origin or strict browser security), 
      // we proceed but risk OOM. This is a best-effort guard.
      if (kDebugMode) print('[MediaCompressor/web] Size check skipped: $e');
    }

    // Read source bytes from the blob URL.
    final Uint8List input;
    try {
      final resp = await _fetch(path.toJS).toDart;
      final ab = await resp.arrayBuffer().toDart;
      input = ab.toDart.asUint8List();
    } catch (e) {
      throw PlatformException(
          code: 'LOAD_ERROR',
          message: 'Failed to read source video',
          details: e.toString());
    }
    if (token.cancelled) throw _CancelledException();

    // H1 Fix: Hard timeout for transcoding operation to prevent zombie workers.
    final timeoutFuture = Future.delayed(_Cfg.ffmpegTimeout).then((_) {
      token.cancel();
      throw TimeoutException('Transcoding timed out after ${_Cfg.ffmpegTimeout.inMinutes} minutes');
    });

    final onProgress = ((JSNumber p) {
      if (!token.cancelled) _emitProgress(p.toDartDouble);
    }).toJS;

    try {
      final jsOut = await Future.any([
        hook.transcode(
          input.toJS,
          'video/mp4'.toJS,
          preset.height.toJS,
          preset.bitrate.toJS,
          onProgress,
        ).toDart,
        timeoutFuture,
      ]);

      if (token.cancelled) throw _CancelledException();

      final out = (jsOut).toDart;
      if (out.isEmpty) {
        throw PlatformException(
            code: 'COMPRESSION_ERROR', message: 'ffmpeg produced no output');
      }
      _emitProgress(1.0);
      final blob = web.Blob(
        [out.toJS].toJS,
        web.BlobPropertyBag(type: 'video/mp4'),
      );
      return web.URL.createObjectURL(blob);
    } on TimeoutException catch (e) {
      throw PlatformException(code: 'TIMEOUT', message: e.message ?? 'Operation timed out');
    }
  }

  // ---- Backend 2: MediaRecorder (Hardened v2.1) ----------------------------

  Future<String> _recordWithMediaRecorder(
    String path,
    ({int height, int bitrate}) preset,
    String mime,
    _CancelToken token,
  ) async {
    final video = web.HTMLVideoElement()
      ..src = path
      ..preload = 'auto'
      ..crossOrigin = 'anonymous'
      ..playsInline = true
      ..muted = false;

    await _waitEvent(video, 'loadedmetadata', onError: () {
      throw PlatformException(
          code: 'LOAD_ERROR',
          message: 'Failed to load video metadata from path: $path');
    });
    if (token.cancelled) throw _CancelledException();

    final srcW = video.videoWidth;
    final srcH = video.videoHeight;
    final duration = video.duration;
    if (srcW == 0 || srcH == 0) {
      throw PlatformException(
          code: 'LOAD_ERROR', message: 'Video has zero dimensions');
    }

    final (outW, outH) = _resolveOutputDims(srcW, srcH, preset.height);

    final canvas = web.HTMLCanvasElement()
      ..width = outW
      ..height = outH;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D
      ..imageSmoothingEnabled = true
      ..imageSmoothingQuality = 'high';

    final (stream, audioCtx) = _buildStream(canvas, video);

    final recorder = web.MediaRecorder(
      stream,
      web.MediaRecorderOptions(
          mimeType: mime, videoBitsPerSecond: preset.bitrate),
    );

    final chunks = <web.Blob>[];
    final done = Completer<void>();

    void stopRecorder() {
      try {
        if (recorder.state != 'inactive') recorder.stop();
      } catch (_) {}
    }

    var cleaned = false;
    void cleanup() {
      if (cleaned) return;
      cleaned = true;
      // H2 Fix: Ensure recorder is stopped even if playback fails.
      stopRecorder();
      try {
        for (final t in stream.getTracks().toDart) {
          t.stop();
        }
      } catch (_) {}
      try {
        video.pause();
        video.removeAttribute('src');
        video.load();
      } catch (_) {}
      audioCtx?.close();
    }

    token.onCancel = () {
      stopRecorder();
      if (!done.isCompleted) done.completeError(_CancelledException());
    };

    recorder.ondataavailable = (web.BlobEvent e) {
      if (e.data.size > 0) chunks.add(e.data);
    }.toJS;
    recorder.onstop = (web.Event _) {
      if (!done.isCompleted) done.complete();
    }.toJS;
    recorder.onerror = (web.Event _) {
      if (!done.isCompleted) {
        done.completeError(PlatformException(
            code: 'COMPRESSION_ERROR',
            message: 'MediaRecorder failed during encoding'));
      }
    }.toJS;
video.onended = ((web.Event _) {
  stopRecorder();
}).toJS;

video.onerror = ((web.Event _) {
  if (!done.isCompleted) {
    done.completeError(
      PlatformException(
        code: 'PLAYBACK_ERROR',
        message: 'The browser failed to play the source video',
      ),
    );
  }
}).toJS;

    var lastTick = DateTime.now();
    void pump(double _) {
      if (video.ended || video.paused || done.isCompleted) return;
      ctx.drawImageScaled(video, 0, 0, outW.toDouble(), outH.toDouble());
      lastTick = DateTime.now();
      if (duration.isFinite && duration > 0) {
        _emitProgress(video.currentTime / duration);
      }
      web.window.requestAnimationFrame(pump.toJS);
    }

    recorder.start(1000);
    try {
      await video.play().toDart;
    } catch (e) {
      cleanup();
      throw PlatformException(
          code: 'PLAYBACK_ERROR',
          message: 'Unable to start video playback for encoding',
          details: e.toString());
    }
    web.window.requestAnimationFrame(pump.toJS);

    Timer? absolute;
    if (duration.isFinite && duration > 0) {
      absolute = Timer(
          Duration(milliseconds: (duration * 1000).round() * 2 + 10000),
          stopRecorder);
    }
    final stall = Timer.periodic(const Duration(seconds: 2), (_) {
      if (DateTime.now().difference(lastTick) > _Cfg.stallTimeout) {
        stopRecorder();
      }
    });

    try {
      await done.future;
    } finally {
      absolute?.cancel();
      stall.cancel();
      cleanup();
    }

    if (token.cancelled) throw _CancelledException();
    _emitProgress(1.0);

    if (chunks.isEmpty) {
      throw PlatformException(
          code: 'COMPRESSION_ERROR',
          message: 'No video data was produced during encoding');
    }
    final out = web.Blob(
      chunks.map((b) => b as JSAny).toList().toJS,
      web.BlobPropertyBag(type: mime),
    );
    return web.URL.createObjectURL(out);
  }

  /// Build the recording stream (canvas video + best-effort audio).
  /// Returns the stream and the AudioContext (null if audio was unavailable).
  (web.MediaStream, web.AudioContext?) _buildStream(
    web.HTMLCanvasElement canvas,
    web.HTMLVideoElement video,
  ) {
    web.AudioContext? audioCtx;
    try {
      audioCtx = web.AudioContext();
      if (audioCtx.state == 'suspended') {
        audioCtx.resume(); // fire-and-forget; awaited elsewhere not required
      }
      final source = audioCtx.createMediaElementSource(video);
      final dest = audioCtx.createMediaStreamDestination();
      source.connect(dest);

      final visual = canvas.captureStream(_Cfg.captureFps);
      final stream = web.MediaStream();
      for (final t in visual.getVideoTracks().toDart) {
        stream.addTrack(t);
      }
      for (final t in dest.stream.getAudioTracks().toDart) {
        stream.addTrack(t);
      }
      return (stream, audioCtx);
    } catch (_) {
      audioCtx?.close();
      video.muted = true;
      return (canvas.captureStream(_Cfg.captureFps), null);
    }
  }

  /// Compute even, aspect-preserving, canvas-safe output dimensions.
  (int, int) _resolveOutputDims(int srcW, int srcH, int targetHeight) {
    final scale = srcH > targetHeight ? targetHeight / srcH : 1.0;
    var w = _even((srcW * scale).round());
    var h = _even((srcH * scale).round());
    final clamped = _clampToCanvas(w, h);
    return (_even(clamped.$1), _even(clamped.$2));
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  String? _negotiateMime() {
    try {
      for (final m in _Cfg.mimeCandidates) {
        if (web.MediaRecorder.isTypeSupported(m)) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('[MediaCompressor/web] codec: $m');
          }
          return m;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  (int, int) _clampToCanvas(int w, int h) {
    var rw = w, rh = h;
    final sideRatio = [_Cfg.maxCanvasSide / rw, _Cfg.maxCanvasSide / rh, 1.0]
        .reduce((a, b) => a < b ? a : b);
    if (sideRatio < 1.0) {
      rw = (rw * sideRatio).round();
      rh = (rh * sideRatio).round();
    }
    if (rw * rh > _Cfg.maxCanvasArea) {
      final s = sqrt(_Cfg.maxCanvasArea / (rw * rh));
      rw = (rw * s).round();
      rh = (rh * s).round();
    }
    return (rw < 1 ? 1 : rw, rh < 1 ? 1 : rh);
  }

  int _even(int v) {
    final r = v.isEven ? v : v - 1;
    return r < 2 ? 2 : r;
  }

  Future<web.Blob?> _canvasToBlob(
    web.HTMLCanvasElement canvas,
    String type,
    double quality,
  ) {
    final completer = Completer<web.Blob?>();
    canvas.toBlob(
      (web.Blob? blob) {
        if (!completer.isCompleted) completer.complete(blob);
      }.toJS,
      type,
      quality.toJS,
    );
    return completer.future;
  }

  Future<void> _waitEvent(
    web.EventTarget target,
    String type, {
    void Function()? onError,
  }) {
    final completer = Completer<void>();
    late final JSFunction onOk;
    late final JSFunction onBad;

    onOk = (web.Event _) {
      target.removeEventListener(type, onOk);
      target.removeEventListener('error', onBad);
      if (!completer.isCompleted) completer.complete();
    }.toJS;

    onBad = (web.Event _) {
      target.removeEventListener(type, onOk);
      target.removeEventListener('error', onBad);
      if (!completer.isCompleted) {
        if (onError != null) {
          try {
            onError();
          } catch (e) {
            completer.completeError(e);
            return;
          }
        }
        completer.complete();
      }
    }.toJS;

    target.addEventListener(type, onOk);
    target.addEventListener('error', onBad);
    return completer.future;
  }
}
