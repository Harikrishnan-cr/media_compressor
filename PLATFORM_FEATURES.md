# Platform-Specific Features

This document details the platform-specific implementations, features, and capabilities of the Media Compressor plugin.

## Overview

While the Media Compressor plugin provides a unified API across all platforms, each platform uses its own native (or browser) libraries optimized for that ecosystem. This results in some differences in capabilities and behavior.

> **Web is currently in beta.** Image compression is stable; video compression is functional but limited (WebM output, real-time encoding). See the Web sections below.

## Video Compression

### Android Implementation

**Technology:** AndroidX Media3 Transformer

The Android implementation uses the powerful Media3 Transformer library for precise video compression control.

#### Features

✅ **Precise Bitrate Control**
- Exact bitrate targeting for video encoding
- Custom encoder settings via `DefaultEncoderFactory`

✅ **Resolution Scaling**
- Automatic scaling to target resolutions
- Maintains aspect ratio during scaling

✅ **Progress Tracking**
- Real-time compression progress via EventChannel
- Progress updates during encoding process

✅ **Advanced Encoder Settings**
- Hardware-accelerated H.264 encoding
- Fallback to software encoding if needed
- Configurable video encoder settings

#### Quality Preset Details

| Quality | Resolution | Bitrate | Use Case |
|---------|-----------|---------|----------|
| `low` | 480p (640x480) | 500 kbps | Quick sharing, minimal file size |
| `medium` | 720p (1280x720) | 1.5 Mbps | Social media, general sharing |
| `high` | 1080p (1920x1080) | 3 Mbps | High-quality archival |

#### Technical Details

- **Video Codec**: H.264 (MPEG-4 AVC)
- **Container Format**: MP4
- **Audio Handling**: Preserved without re-encoding
- **Scaling Method**: `ScaleAndRotateTransformation` with bilinear filtering
- **Processing**: Asynchronous with coroutines

#### Code Example (Progress Tracking)

```dart
// Android supports progress tracking via EventChannel
final eventChannel = EventChannel('native_compressor/progress');

eventChannel.receiveBroadcastStream().listen((event) {
  final progress = event['progress'] as double;
  final percentage = event['percentage'] as int;
  print('Compression progress: $percentage%');
});

final result = await MediaCompressor.compressVideo(
  VideoCompressionConfig(
    path: videoPath,
    quality: VideoQuality.medium,
  ),
);
```

### iOS Implementation

**Technology:** AVAssetExportSession

The iOS implementation uses Apple's built-in AVAssetExportSession for optimized video compression.

#### Features

✅ **System Presets**
- Leverages Apple's quality presets
- Optimized for iOS ecosystem

✅ **Network Optimization**
- `shouldOptimizeForNetworkUse` enabled
- Videos optimized for streaming

✅ **Native Integration**
- Seamless integration with iOS media frameworks
- Leverages Apple's hardware acceleration

#### Quality Preset Details

| Quality | iOS Preset | Characteristics |
|---------|-----------|-----------------|
| `low` | `AVAssetExportPresetLowQuality` | Smallest file size, lower quality |
| `medium` | `AVAssetExportPresetMediumQuality` | Balanced quality and size |
| `high` | `AVAssetExportPresetHighestQuality` | Best quality, larger file size |

#### Technical Details

- **Export Session**: AVAssetExportSession
- **Container Format**: MP4
- **Network Optimization**: Enabled
- **Audio Handling**: Preserved during export
- **Processing**: Asynchronous with completion handlers

#### Code Example

```dart
// iOS compression (no progress tracking yet)
final result = await MediaCompressor.compressVideo(
  VideoCompressionConfig(
    path: videoPath,
    quality: VideoQuality.medium,
  ),
);
```

### Web Implementation (Beta)

**Technology:** HTMLVideoElement + Canvas + MediaRecorder (+ WebAudio for audio)

The web implementation re-encodes video in the browser by drawing each frame onto a scaled canvas and recording the canvas stream with `MediaRecorder`. Audio is tapped from the video element through a WebAudio graph and muxed into the output when the browser allows it. No native binaries or external services are required.

#### Features

✅ **Resolution Scaling**
- Scales down to target height (480p / 720p / 1080p)
- Maintains aspect ratio (dimensions forced to even values)

✅ **Bitrate Control**
- `videoBitsPerSecond` set on `MediaRecorder` (matches Android presets)

✅ **Progress Tracking**
- Real-time progress via the same `native_compressor/progress` EventChannel
- Derived from `video.currentTime / video.duration`

✅ **Best-Effort Audio**
- Captured via `AudioContext` + `MediaStreamAudioDestinationNode`
- Falls back to silent (video-only) output if the audio graph is blocked

⚠️ **Codec Negotiation**
- Picks the first supported WebM codec: VP9+Opus → VP8+Opus → VP9 → VP8 → WebM default

✅ **Memory Release**
- `release(path)` revokes the blob object URL to free browser memory

#### Quality Preset Details

| Quality | Target Height | Bitrate | Use Case |
|---------|--------------|---------|----------|
| `low` | 480p | 500 kbps | Quick sharing, minimal file size |
| `medium` | 720p | 1.5 Mbps | Social media, general sharing |
| `high` | 1080p | 3 Mbps | High-quality playback |

#### Technical Details

- **Video Codec**: VP9 / VP8 (browser-dependent)
- **Audio Codec**: Opus (best-effort)
- **Container Format**: **WebM** (not MP4)
- **Scaling Method**: Canvas `drawImageScaled` (per-frame), 30 fps capture
- **Processing**: Asynchronous; runs for the playback duration of the source video
- **Output**: Blob object URL (e.g. `blob:http://...`), **not** a filesystem path

#### Code Example

```dart
// Web compression — same API, progress supported
final eventChannel = EventChannel('native_compressor/progress');
eventChannel.receiveBroadcastStream().listen((event) {
  print('Progress: ${event['percentage']}%');
});

final result = await MediaCompressor.compressVideo(
  VideoCompressionConfig(
    path: blobUrl, // from image_picker web (a blob: URL)
    quality: VideoQuality.medium,
  ),
);

if (result.isSuccess) {
  final url = result.path!; // a blob URL — use a network video source, not File()
  // ... after you are done with it:
  await MediaCompressor.release(url);
}
```

> **Need guaranteed MP4 output?** Use an `ffmpeg.wasm`-based pipeline instead. The built-in browser `MediaRecorder` produces WebM across most browsers.

### Platform Comparison

| Feature | Android | iOS | Web (Beta) |
|---------|---------|-----|------------|
| Precise Bitrate Control | ✅ Yes | ❌ No (presets) | ✅ Yes |
| Resolution Targeting | ✅ Yes (480p/720p/1080p) | ❌ No (preset-based) | ✅ Yes (480p/720p/1080p) |
| Progress Tracking | ✅ Yes (EventChannel) | 🚧 Under Development | ✅ Yes (EventChannel) |
| Network Optimization | 🚧 Under Development | ✅ Yes | ➖ N/A |
| Hardware Acceleration | ✅ Yes (with fallback) | ✅ Yes (automatic) | ⚠️ Browser-dependent |
| Custom Encoder Settings | ✅ Yes | ❌ No | ⚠️ Limited (bitrate only) |
| Output Container | MP4 | MP4 | WebM |
| Audio Preserved | ✅ Yes | ✅ Yes | ⚠️ Best-effort |
| Output Type | File path | File path | Blob URL |
| Resource Release | `release` (file delete*) | `release` (file delete*) | `release` (revoke URL) |

\* Native `release` handler optional; safe no-op if not added.

## Image Compression

### Android Implementation

**Technology:** Android Bitmap + ExifInterface

#### Features

✅ **EXIF Orientation Handling**
- Reads EXIF orientation data
- Automatically rotates/flips images

✅ **Memory Management**
- RGB_565 color format for reduced memory
- Bitmap recycling after compression

✅ **Quality Control**
- JPEG compression with quality 0-100
- Configurable resolution limits

#### Technical Details

- **Format**: JPEG output
- **Color Space**: RGB_565 (optimized)
- **Orientation**: Full EXIF support (8 orientations)
- **Scaling**: Bilinear interpolation

### iOS Implementation

**Technology:** UIKit + UIImage

#### Features

✅ **EXIF Orientation Handling**
- UIImage orientation detection
- CGContext-based rotation/flipping

✅ **High-Quality Rendering**
- UIGraphicsImageRenderer for modern rendering
- Maintains color accuracy

✅ **Quality Control**
- JPEG compression with quality 0-100
- Configurable resolution limits

#### Technical Details

- **Format**: JPEG output
- **Rendering**: UIGraphicsImageRenderer
- **Orientation**: Full UIImage orientation support
- **Scaling**: UIKit's high-quality scaling

### Web Implementation (Beta)

**Technology:** HTML Canvas + `HTMLImageElement`

#### Features

✅ **Quality Control**
- JPEG re-encode with quality 0-100 (mapped to canvas `toBlob` quality 0.0–1.0)

✅ **Resolution Limiting**
- Scales down when both `maxWidth` and `maxHeight` are provided (mirrors Android)
- Maintains aspect ratio

⚠️ **Orientation**
- Relies on the browser's built-in image orientation handling during `decode()`

#### Technical Details

- **Format**: JPEG output
- **Decoding**: `HTMLImageElement.decode()`
- **Scaling**: Canvas `drawImageScaled`
- **Output**: Blob object URL, **not** a filesystem path

### Platform Comparison (Images)

| Feature | Android | iOS | Web (Beta) |
|---------|---------|-----|------------|
| EXIF Orientation | ✅ Yes (8 types) | ✅ Yes (8 types) | ⚠️ Browser-handled |
| Quality Control | ✅ 0-100 | ✅ 0-100 | ✅ 0-100 |
| Resolution Limiting | ✅ Yes | ✅ Yes | ✅ Yes (both dims) |
| Memory Optimization | ✅ RGB_565 | ✅ Automatic | ⚠️ Browser-managed |
| Format Support | JPEG | JPEG | JPEG |
| Output Type | File path | File path | Blob URL |

## Error Codes

### Cross-Platform Error Codes

These error codes are used across platforms:

- `INVALID_ARGUMENT` - Invalid arguments (quality out of range, invalid dimensions)
- `COMPRESSION_ERROR` - Native/browser compression failed
- `FILE_NOT_FOUND` - Input file doesn't exist
- `NULL_RESULT` - Compression returned null/empty result
- `TIMEOUT` - Video compression exceeded timeout
- `UNKNOWN_ERROR` - Unexpected error occurred

### iOS-Specific Error Codes

Additional error codes only thrown on iOS:

- `LOAD_ERROR` - Failed to load image file (UIImage creation failed)
- `EXPORT_ERROR` - Failed to create AVAssetExportSession
- `EXPORT_FAILED` - AVAssetExportSession export failed
- `EXPORT_CANCELLED` - Video export was cancelled by system

### Web-Specific Error Codes

Additional error codes only thrown on web:

- `LOAD_ERROR` - Failed to load/decode the source image or video
- `UNSUPPORTED` - Browser cannot record video (`MediaRecorder` unavailable)
- `UNIMPLEMENTED` - Method not implemented on web

## Future Roadmap

### Planned for Web

🚧 **MP4 + Guaranteed Audio**
- Optional `ffmpeg.wasm` pipeline for MP4 output

🚧 **EXIF Orientation**
- Explicit orientation correction for browsers that do not auto-apply it

🚧 **Stability**
- Promote web support from beta to stable after field testing

### Planned for iOS

🚧 **Progress Tracking**
- Event-based progress updates during video compression
- Similar to Android implementation

🚧 **Precise Bitrate Control**
- Custom bitrate settings beyond Apple's presets
- Resolution targeting similar to Android

### Planned for Android

🚧 **Network Optimization**
- Optimize MP4 file structure for streaming
- Similar to iOS `shouldOptimizeForNetworkUse`

### Planned for All Platforms

🔮 **Batch Compression**
- Compress multiple files in one call
- Progress tracking per file

🔮 **Format Support**
- PNG output for images
- WebP support
- Additional video codecs (H.265/HEVC)

🔮 **Advanced Options**
- Frame rate control
- Audio bitrate settings
- Custom encoder profiles

## Performance Characteristics

### Android

**Image Compression:**
- Small images (<2MB): 50-200ms
- Large images (5-10MB): 200-500ms
- Very large images (>10MB): 500ms-2s

**Video Compression:**
- 30s video @ 720p medium: 10-30s
- 1min video @ 720p medium: 20-60s
- Highly dependent on device hardware

### iOS

**Image Compression:**
- Small images (<2MB): 50-150ms
- Large images (5-10MB): 150-400ms
- Very large images (>10MB): 400ms-1.5s

**Video Compression:**
- 30s video @ medium preset: 15-45s
- 1min video @ medium preset: 30-90s
- Generally faster than Android on newer devices

### Web (Beta)

**Image Compression:**
- Generally fast; depends on image size and browser

**Video Compression:**
- Runs for roughly the playback duration of the source video
  (a 30s clip takes ~30s+), since frames are captured in real time
- Highly dependent on browser and device

## Best Practices by Platform

### Android

1. **Use Progress Tracking**: Display progress for better UX
2. **Handle Timeouts**: Large videos may need extended timeouts
3. **Test Hardware**: Performance varies significantly by device
4. **Consider Quality**: `medium` preset (720p) is optimal for most cases

### iOS

1. **Network Optimization**: Already enabled, great for sharing
2. **System Presets**: Trust Apple's presets - they're well-optimized
3. **Handle All Export States**: Check for cancelled/failed states
4. **File Management**: Clean up temp files after upload/share

### Web

1. **Use Blob URLs Correctly**: `result.path` is a blob URL — use `Image.network` and network video sources, never `File()`
2. **Release When Done**: Call `MediaCompressor.release(result.path!)` after upload/preview to free memory
3. **Set Expectations on Video**: Output is WebM; use `ffmpeg.wasm` if MP4 is required
4. **Expect Real-Time Encoding**: Video processing takes about the clip's duration

## Support and Issues

For platform-specific issues:

**Android Issues:**
- Media3 Transformer errors
- Bitrate/resolution problems
- Progress tracking issues

**iOS Issues:**
- AVAssetExportSession failures
- Preset-related questions
- Export state handling

**Web Issues:**
- MediaRecorder / codec support
- Blob URL handling
- Missing audio or MP4 requirements

Please report platform-specific issues on the [GitHub repository](https://github.com/Harikrishnan-cr/media_compressor/issues) with the platform label.

---

**Last Updated:** June 2026  
**Plugin Version:** 1.1.0-beta.1




<!-- # Platform-Specific Features

This document details the platform-specific implementations, features, and capabilities of the Media Compressor plugin.

## Overview

While the Media Compressor plugin provides a unified API across both platforms, each platform uses its own native libraries optimized for that ecosystem. This results in some differences in capabilities and behavior.

## Video Compression

### Android Implementation

**Technology:** AndroidX Media3 Transformer

The Android implementation uses the powerful Media3 Transformer library for precise video compression control.

#### Features

✅ **Precise Bitrate Control**
- Exact bitrate targeting for video encoding
- Custom encoder settings via `DefaultEncoderFactory`

✅ **Resolution Scaling**
- Automatic scaling to target resolutions
- Maintains aspect ratio during scaling

✅ **Progress Tracking**
- Real-time compression progress via EventChannel
- Progress updates during encoding process

✅ **Advanced Encoder Settings**
- Hardware-accelerated H.264 encoding
- Fallback to software encoding if needed
- Configurable video encoder settings

#### Quality Preset Details

| Quality | Resolution | Bitrate | Use Case |
|---------|-----------|---------|----------|
| `low` | 480p (640x480) | 500 kbps | Quick sharing, minimal file size |
| `medium` | 720p (1280x720) | 1.5 Mbps | Social media, general sharing |
| `high` | 1080p (1920x1080) | 3 Mbps | High-quality archival |

#### Technical Details

- **Video Codec**: H.264 (MPEG-4 AVC)
- **Container Format**: MP4
- **Audio Handling**: Preserved without re-encoding
- **Scaling Method**: `ScaleAndRotateTransformation` with bilinear filtering
- **Processing**: Asynchronous with coroutines

#### Code Example (Progress Tracking)

```dart
// Android supports progress tracking via EventChannel
final eventChannel = EventChannel('native_compressor/progress');

eventChannel.receiveBroadcastStream().listen((event) {
  final progress = event['progress'] as double;
  final percentage = event['percentage'] as int;
  print('Compression progress: $percentage%');
});

final result = await MediaCompressor.compressVideo(
  VideoCompressionConfig(
    path: videoPath,
    quality: VideoQuality.medium,
  ),
);
```

### iOS Implementation

**Technology:** AVAssetExportSession

The iOS implementation uses Apple's built-in AVAssetExportSession for optimized video compression.

#### Features

✅ **System Presets**
- Leverages Apple's quality presets
- Optimized for iOS ecosystem

✅ **Network Optimization**
- `shouldOptimizeForNetworkUse` enabled
- Videos optimized for streaming

✅ **Native Integration**
- Seamless integration with iOS media frameworks
- Leverages Apple's hardware acceleration

#### Quality Preset Details

| Quality | iOS Preset | Characteristics |
|---------|-----------|-----------------|
| `low` | `AVAssetExportPresetLowQuality` | Smallest file size, lower quality |
| `medium` | `AVAssetExportPresetMediumQuality` | Balanced quality and size |
| `high` | `AVAssetExportPresetHighestQuality` | Best quality, larger file size |

#### Technical Details

- **Export Session**: AVAssetExportSession
- **Container Format**: MP4
- **Network Optimization**: Enabled
- **Audio Handling**: Preserved during export
- **Processing**: Asynchronous with completion handlers

#### Code Example

```dart
// iOS compression (no progress tracking yet)
final result = await MediaCompressor.compressVideo(
  VideoCompressionConfig(
    path: videoPath,
    quality: VideoQuality.medium,
  ),
);
```

### Platform Comparison

| Feature | Android | iOS |
|---------|---------|-----|
| Precise Bitrate Control | ✅ Yes | ❌ No (uses presets) |
| Resolution Targeting | ✅ Yes (480p/720p/1080p) | ❌ No (preset-based) |
| Progress Tracking | ✅ Yes (EventChannel) | 🚧 Under Development |
| Network Optimization | 🚧 Under Development | ✅ Yes |
| Hardware Acceleration | ✅ Yes (with fallback) | ✅ Yes (automatic) |
| Custom Encoder Settings | ✅ Yes | ❌ No |

## Image Compression

### Android Implementation

**Technology:** Android Bitmap + ExifInterface

#### Features

✅ **EXIF Orientation Handling**
- Reads EXIF orientation data
- Automatically rotates/flips images

✅ **Memory Management**
- RGB_565 color format for reduced memory
- Bitmap recycling after compression

✅ **Quality Control**
- JPEG compression with quality 0-100
- Configurable resolution limits

#### Technical Details

- **Format**: JPEG output
- **Color Space**: RGB_565 (optimized)
- **Orientation**: Full EXIF support (8 orientations)
- **Scaling**: Bilinear interpolation

### iOS Implementation

**Technology:** UIKit + UIImage

#### Features

✅ **EXIF Orientation Handling**
- UIImage orientation detection
- CGContext-based rotation/flipping

✅ **High-Quality Rendering**
- UIGraphicsImageRenderer for modern rendering
- Maintains color accuracy

✅ **Quality Control**
- JPEG compression with quality 0-100
- Configurable resolution limits

#### Technical Details

- **Format**: JPEG output
- **Rendering**: UIGraphicsImageRenderer
- **Orientation**: Full UIImage orientation support
- **Scaling**: UIKit's high-quality scaling

### Platform Comparison (Images)

| Feature | Android | iOS |
|---------|---------|-----|
| EXIF Orientation | ✅ Yes (8 types) | ✅ Yes (8 types) |
| Quality Control | ✅ 0-100 | ✅ 0-100 |
| Resolution Limiting | ✅ Yes | ✅ Yes |
| Memory Optimization | ✅ RGB_565 | ✅ Automatic |
| Format Support | JPEG | JPEG |

## Error Codes

### Cross-Platform Error Codes

These error codes are used by both platforms:

- `INVALID_ARGUMENT` - Invalid arguments (quality out of range, invalid dimensions)
- `COMPRESSION_ERROR` - Native compression failed
- `FILE_NOT_FOUND` - Input file doesn't exist
- `NULL_RESULT` - Compression returned null/empty result
- `TIMEOUT` - Video compression exceeded timeout
- `UNKNOWN_ERROR` - Unexpected error occurred

### iOS-Specific Error Codes

Additional error codes only thrown on iOS:

- `LOAD_ERROR` - Failed to load image file (UIImage creation failed)
- `EXPORT_ERROR` - Failed to create AVAssetExportSession
- `EXPORT_FAILED` - AVAssetExportSession export failed
- `EXPORT_CANCELLED` - Video export was cancelled by system

## Future Roadmap

### Planned for iOS

🚧 **Progress Tracking**
- Event-based progress updates during video compression
- Similar to Android implementation

🚧 **Precise Bitrate Control**
- Custom bitrate settings beyond Apple's presets
- Resolution targeting similar to Android

### Planned for Android

🚧 **Network Optimization**
- Optimize MP4 file structure for streaming
- Similar to iOS `shouldOptimizeForNetworkUse`

### Planned for Both Platforms

🔮 **Batch Compression**
- Compress multiple files in one call
- Progress tracking per file

🔮 **Format Support**
- PNG output for images
- WebP support
- Additional video codecs (H.265/HEVC)

🔮 **Advanced Options**
- Frame rate control
- Audio bitrate settings
- Custom encoder profiles

## Performance Characteristics

### Android

**Image Compression:**
- Small images (<2MB): 50-200ms
- Large images (5-10MB): 200-500ms
- Very large images (>10MB): 500ms-2s

**Video Compression:**
- 30s video @ 720p medium: 10-30s
- 1min video @ 720p medium: 20-60s
- Highly dependent on device hardware

### iOS

**Image Compression:**
- Small images (<2MB): 50-150ms
- Large images (5-10MB): 150-400ms
- Very large images (>10MB): 400ms-1.5s

**Video Compression:**
- 30s video @ medium preset: 15-45s
- 1min video @ medium preset: 30-90s
- Generally faster than Android on newer devices

## Best Practices by Platform

### Android

1. **Use Progress Tracking**: Display progress for better UX
2. **Handle Timeouts**: Large videos may need extended timeouts
3. **Test Hardware**: Performance varies significantly by device
4. **Consider Quality**: `medium` preset (720p) is optimal for most cases

### iOS

1. **Network Optimization**: Already enabled, great for sharing
2. **System Presets**: Trust Apple's presets - they're well-optimized
3. **Handle All Export States**: Check for cancelled/failed states
4. **File Management**: Clean up temp files after upload/share

## Support and Issues

For platform-specific issues:

**Android Issues:**
- Media3 Transformer errors
- Bitrate/resolution problems
- Progress tracking issues

**iOS Issues:**
- AVAssetExportSession failures
- Preset-related questions
- Export state handling

Please report platform-specific issues on the [GitHub repository](https://github.com/yourusername/media_compressor/issues) with the platform label.

---

**Last Updated:** November 2025  
**Plugin Version:** 1.0.0 -->