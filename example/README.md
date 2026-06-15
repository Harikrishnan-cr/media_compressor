# Media Compressor

A Flutter plugin for compressing images and videos efficiently using native platform implementations — now on **Android, iOS, and Web**.

## Demo

See the plugin in action:

| Image Compression Demo | Video Compression Demo |
| ---------------------- | ---------------------- |
| <img src="https://raw.githubusercontent.com/Harikrishnan-cr/media_compressor/v1-stable/example/lib/demo/image_compression.gif" width="250"/> | <img src="https://raw.githubusercontent.com/Harikrishnan-cr/media_compressor/v1-stable/example/lib/demo/video_compression_gif.gif" width="250"/> |

## Latest Updates

### v1.1.0-beta.1
- 🌐 **Web support (beta)** — image (Canvas) and video (ffmpeg.wasm or MediaRecorder) compression in the browser
- 🛑 **`cancel()`** — abort an in-flight video compression on every platform
- 🧹 **`release()` / `releaseResult()`** — free a compressed result (revokes blob URL on web, deletes temp file on mobile)
- 🔒 Hardened: cache-scoped file deletion, single-flight video, managed native lifecycle
- No breaking changes to the existing Dart API

### v1.0.1
- 🐛 Fixed iOS compilation error by adding the missing Flutter framework import
- ✅ All functionality working as expected on Android and iOS

## Features

✅ **Image Compression** — quality and dimension control  
✅ **Video Compression** — quality presets (low / medium / high)  
✅ **Native Performance** — platform-specific compression for optimal results  
✅ **Web Support (beta)** — in-browser compression via Canvas + ffmpeg.wasm / MediaRecorder  
✅ **Progress Tracking** — real-time video progress on Android and Web  
✅ **Cancel & Release** — abort jobs and free outputs  
✅ **Error Handling** — comprehensive, typed error codes  
✅ **Cross-platform** — Android, iOS, and Web  
✅ **EXIF Orientation** — automatic image orientation correction  

## Platform Support

| Feature | Android | iOS | Web (beta) |
|---------|---------|-----|------------|
| Image compression | ✅ | ✅ | ✅ |
| Video compression | ✅ Media3 (bitrate + resolution) | ✅ AVAssetExportSession (presets) | ✅ ffmpeg.wasm* or MediaRecorder |
| Progress | ✅ | 🚧 | ✅ |
| Cancel | ✅ | ✅ | ✅ |
| Output | MP4 / JPEG (file path) | MP4 / JPEG (file path) | MP4 / WebM / JPEG (blob URL) |

\* ffmpeg.wasm is opt-in — see [Web video backends](#web-video-backends).

## Installation

**Stable** (Android + iOS):

```yaml
dependencies:
  media_compressor: ^1.0.1
```

**Beta** (adds Web support):

```yaml
dependencies:
  media_compressor: 1.1.0-beta.1
```

Then run:

```bash
flutter pub get
```

## Usage

### Import the Package

```dart
import 'package:media_compressor/media_compressor.dart';
```

### Compress an Image

```dart
final result = await MediaCompressor.compressImage(
  ImageCompressionConfig(
    path: '/path/to/image.jpg', // a blob URL on web (from image_picker)
    quality: 80,                // 0-100, where 100 is best quality
    maxWidth: 1920,             // Optional: max width in pixels
    maxHeight: 1080,            // Optional: max height in pixels
  ),
);

if (result.isSuccess) {
  print('Compressed image saved at: ${result.path}');
} else {
  print('Compression failed: ${result.error?.message}');
}
```

### Compress a Video

```dart
final result = await MediaCompressor.compressVideo(
  VideoCompressionConfig(
    path: '/path/to/video.mp4', // a blob URL on web
    quality: VideoQuality.medium,  // low, medium, high
  ),
);

if (result.isSuccess) {
  print('Compressed video saved at: ${result.path}');
} else {
  print('Compression failed: ${result.error?.message}');
}
```

> Only **one** video compression runs at a time on every platform. A concurrent
> call returns the error code `BUSY`.

### Cancel & Release

```dart
// Abort the in-flight video compression (safe no-op if none).
await MediaCompressor.cancel();

// Free a result when you no longer need it
// (revokes the blob URL on web, deletes the temp file on mobile).
await MediaCompressor.release(result.path!);
await MediaCompressor.releaseResult(result);
```

> ⚠️ Don't release a result that's still in use — a revoked blob URL will no
> longer load in `Image.network` or a video player.

### Progress Tracking (Android & Web)

```dart
final eventChannel = EventChannel('native_compressor/progress');

eventChannel.receiveBroadcastStream().listen((event) {
  final percentage = event['percentage'] as int;
  print('Compression progress: $percentage%');
});
```

### Video Quality Presets

```dart
enum VideoQuality {
  low,     // 480p — smaller file
  medium,  // 720p — balanced (recommended)
  high,    // 1080p — higher quality
}
```

### Compression Result

```dart
class CompressionResult {
  final bool isSuccess;
  final String? path;              // file path (mobile) or blob URL (web)
  final CompressionError? error;
  bool get isFailure => !isSuccess;
}
```

### Error Handling

```dart
class CompressionError {
  final String code;      // programmatic code
  final String message;   // human-readable message
  final dynamic details;  // optional platform details
}
```

Common error codes:
- `INVALID_ARGUMENT` — invalid arguments (missing path, quality out of range, bad dimensions)
- `FILE_NOT_FOUND` — input file doesn't exist
- `COMPRESSION_ERROR` — native/browser compression failed
- `NULL_RESULT` — compression returned null/empty
- `TIMEOUT` — exceeded the timeout
- `CANCELLED` — aborted via `cancel()`
- `BUSY` — another video compression is already in progress
- `UNSUPPORTED` / `UNSUPPORTED_PLATFORM` — no encoder available on this platform
- `LOAD_ERROR` / `PLAYBACK_ERROR` — web: failed to load/play the source
- `INPUT_TOO_LARGE` — web: source exceeds the in-browser size limit
- `UNKNOWN_ERROR` — unexpected error

## Working with Results on Web

On web, `result.path` is a **blob object URL** (e.g. `blob:http://...`), not a
filesystem path. Use network/blob-aware APIs:

```dart
// Preview an image
Image.network(result.path!);

// Read bytes / size cross-platform (works for mobile paths AND web blob URLs)
final xfile = XFile(result.path!);
final bytes = await xfile.readAsBytes();
final size  = await xfile.length();
```

`File(result.path)` does **not** work on web — avoid `dart:io` in shared code.

## Web video backends

- **MediaRecorder (default, zero setup):** canvas re-encode. WebM on
  Chromium/Firefox, MP4 on Safari/iOS, best-effort audio. Real-time; bitrate is
  a hint; progress is a time estimate.
- **ffmpeg.wasm (opt-in, recommended for production):** register a global
  `window.mediaCompressorFfmpeg` (shim provided in the header of
  `media_compressor_web.dart`) for off-thread H.264/MP4 with **enforced bitrate**
  and **exact progress**. Requires cross-origin isolation in `web/index.html`
  (`COOP: same-origin`, `COEP: require-corp`) and a review of the libx264
  (LGPL/GPL) licensing for your use case.

## Platform-specific Setup

### Android

Add the following permissions to your `AndroidManifest.xml` (only if reading
shared storage on API ≤ 32):

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
</manifest>
```

**Note:** For Android 13+ (API 33+), no storage permissions are needed for app-specific directories.

### iOS

Add the following to your `Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to compress photos and videos.</string>
```

### Web

No setup is required for the default MediaRecorder backend. For the ffmpeg.wasm
backend, add the COOP/COEP headers and the shim (see
[Web video backends](#web-video-backends)).

## API Reference

### MediaCompressor

Static entry point for all compression operations.

| Method | Returns | Description |
|--------|---------|-------------|
| `compressImage(ImageCompressionConfig)` | `Future<CompressionResult>` | Compress an image |
| `compressVideo(VideoCompressionConfig, {Duration? timeout})` | `Future<CompressionResult>` | Compress a video (default timeout 5 min) |
| `cancel()` | `Future<void>` | Abort the in-flight video job |
| `release(String path)` | `Future<void>` | Free a compressed result |
| `releaseResult(CompressionResult)` | `Future<void>` | Release `result.path` if successful |

### ImageCompressionConfig

```dart
ImageCompressionConfig({
  required String path,
  int quality = 80,   // 0-100
  int? maxWidth,
  int? maxHeight,
})
```

### VideoCompressionConfig

```dart
VideoCompressionConfig({
  required String path,
  VideoQuality quality = VideoQuality.medium,
})
```

#### Video Compression Details

- **Android:** AndroidX Media3 Transformer — H.264/MP4, target resolution and
  bitrate per preset, audio preserved, progress events.
- **iOS:** AVAssetExportSession — system presets (low/medium/high), MP4, audio
  preserved, network-optimized.
- **Web:** ffmpeg.wasm (H.264/MP4, enforced bitrate) when available; otherwise
  MediaRecorder (WebM/MP4, best-effort audio, real-time).

| Quality | Resolution | Use Case |
|---------|-----------|----------|
| `low` | 480p | Quick sharing, minimal size |
| `medium` | 720p | General sharing (recommended) |
| `high` | 1080p | High-quality archival |

## Complete Example

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_compressor/media_compressor.dart';

class CompressionExample extends StatefulWidget {
  const CompressionExample({super.key});
  @override
  State<CompressionExample> createState() => _CompressionExampleState();
}

class _CompressionExampleState extends State<CompressionExample> {
  Uint8List? _bytes;
  String? _status;

  Future<void> _compressImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final result = await MediaCompressor.compressImage(
      ImageCompressionConfig(
        path: image.path,
        quality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      ),
    );

    if (result.isSuccess) {
      // Cross-platform read (file path on mobile, blob URL on web).
      final bytes = await XFile(result.path!).readAsBytes();
      setState(() {
        _bytes = bytes;
        _status = 'Compressed: ${(bytes.length / 1024).toStringAsFixed(1)} KB';
      });
      await MediaCompressor.release(result.path!);
    } else {
      setState(() => _status = 'Error: ${result.error?.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Media Compressor')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_bytes != null) SizedBox(height: 240, child: Image.memory(_bytes!)),
            if (_status != null)
              Padding(padding: const EdgeInsets.all(16), child: Text(_status!)),
            ElevatedButton(
              onPressed: _compressImage,
              child: const Text('Compress Image'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Best Practices

1. **Quality Settings** — start with 80-85 for images: good compression, minimal loss.
2. **Dimension Limits** — set `maxWidth`/`maxHeight` to avoid memory spikes on large images.
3. **Error Handling** — always check `result.isSuccess` before using the output.
4. **Release Outputs** — call `release()` when done, especially on web.
5. **Timeout** — increase the timeout for large videos.
6. **Web Video** — output may be WebM on the fallback path; encoding runs in real time. Use the ffmpeg.wasm backend for MP4 + faster-than-realtime + exact progress.

## Performance Tips

- Image compression is fast (typically milliseconds).
- Video compression can take seconds to minutes depending on file size.
- Compress files **sequentially** — concurrent video calls return `BUSY`.
- Show a progress indicator during video compression.

## Troubleshooting

**"File not found" error** — verify the path and permissions.

**Video compression timeout** — increase the timeout, lower the quality, check storage.

**Out-of-memory errors** — reduce `maxWidth`/`maxHeight`; process sequentially; on web, keep source videos within the in-browser size limit.

**Web: `result.path` won't load** — it's a blob URL; use `Image.network` / a network video source, not `File(...)`.

## Platform-Specific Features

For detailed bitrates, resolutions, codecs, and per-platform behavior, see
**[PLATFORM_FEATURES.md](https://github.com/Harikrishnan-cr/media_compressor/blob/main/PLATFORM_FEATURES.md)**.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## Support

For issues, feature requests, or questions, please file an issue on the
[GitHub repository](https://github.com/Harikrishnan-cr/media_compressor).

## Media Credits

The demo uses sample media for showcasing compression features.

### 📷 Image Credit
Photo by [Zhen Yao](https://unsplash.com/@zhenyao_photo?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)  
from [Unsplash](https://unsplash.com/photos/a-purple-double-decker-tram-drives-down-a-city-street-rkh4MD-kSRI?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)

### 🎥 Video Credit
Video by [tham nguyen](https://pixabay.com/users/tham_ms-51941956/?utm_source=link-attribution&utm_medium=referral&utm_campaign=video&utm_content=305657)  
from [Pixabay](https://pixabay.com/?utm_source=link-attribution&utm_medium=referral&utm_campaign=video&utm_content=305657)

---

**Made with ❤️ for the Flutter community**