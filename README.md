# Media Compressor

A Flutter plugin for compressing images and videos efficiently using native platform implementations.

## Demo

See the plugin in action:

| Image Compression Demo | Video Compression Demo |
| ---------------------- | ---------------------- |
| ![Image Compression Demo](https://raw.githubusercontent.com/flutter/packages/refs/heads/main/packages/video_player/video_player/doc/demo_ipod.gif) | ![Video Compression Demo](https://raw.githubusercontent.com/flutter/packages/refs/heads/main/packages/video_player/video_player/doc/demo_ipod.gif) |


<!-- ### Image Compression Demo   |   Video Compression Demo

[![Image Compression Demo](https://raw.githubusercontent.com/flutter/packages/refs/heads/main/packages/video_player/video_player/doc/demo_ipod.gif) [![Video Compression Demo](https://raw.githubusercontent.com/flutter/packages/refs/heads/main/packages/video_player/video_player/doc/demo_ipod.gif)]] -->

## Features

✅ **Image Compression** - Compress images with quality and dimension control  
✅ **Video Compression** - Compress videos with quality presets  
✅ **Native Performance** - Uses platform-specific compression for optimal results  
✅ **Error Handling** - Comprehensive error handling with detailed error messages  
✅ **Cross-platform** - Supports both Android and iOS  
✅ **EXIF Orientation** - Automatic correction of image orientation  

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  media_compressor: ^1.0.0
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
    path: '/path/to/image.jpg',
    quality: 80,           // 0-100, where 100 is best quality
    maxWidth: 1920,        // Optional: max width in pixels
    maxHeight: 1080,       // Optional: max height in pixels
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
    path: '/path/to/video.mp4',
    quality: VideoQuality.medium,  // low, medium, high
  ),
);

if (result.isSuccess) {
  print('Compressed video saved at: ${result.path}');
} else {
  print('Compression failed: ${result.error?.message}');
}
```

### Video Quality Presets

The `VideoQuality` enum provides three quality levels:

```dart
enum VideoQuality {
  low,     // Lower bitrate, smaller file size
  medium,  // Balanced quality and size (recommended)
  high,    // Higher quality, larger file size
}

// Usage examples:
VideoCompressionConfig(
  path: '/path/to/video.mp4',
  quality: VideoQuality.low,     // For quick sharing, previews
)

VideoCompressionConfig(
  path: '/path/to/video.mp4',
  quality: VideoQuality.medium,  // Default - best for most cases
)

VideoCompressionConfig(
  path: '/path/to/video.mp4',
  quality: VideoQuality.high,    // For high-quality archival
)
```

### Compression Result

All compression methods return a `CompressionResult` object:

```dart
class CompressionResult {
  final bool isSuccess;
  final String? path;              // Path to compressed file
  final CompressionError? error;   // Error details if failed
  
  // Helper getters
  bool get isFailure => !isSuccess;
}
```

### Error Handling

```dart
class CompressionError {
  final String code;      // Error code for programmatic handling
  final String message;   // Human-readable error message
  final dynamic details;  // Additional error details
}
```

Common error codes:
- `INVALID_ARGUMENT` - Invalid arguments provided (e.g., missing path, quality out of range, invalid dimensions)
- `COMPRESSION_ERROR` - Native compression failed
- `FILE_NOT_FOUND` - Input file doesn't exist at the specified path
- `NULL_RESULT` - Compression returned null or empty result
- `TIMEOUT` - Video compression exceeded timeout
- `UNKNOWN_ERROR` - Unexpected error occurred

## Platform-specific Setup

### Android

Add the following permissions to your `AndroidManifest.xml`:

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

## API Reference

### MediaCompressor

The main singleton class for compression operations.

#### Methods

##### `compressImage(ImageCompressionConfig config)`

Compresses an image file with the specified configuration.

**Parameters:**
- `config` - Image compression configuration

**Returns:** `Future<CompressionResult>`

##### `compressVideo(VideoCompressionConfig config, {Duration? timeout})`

Compresses a video file with the specified configuration.

**Parameters:**
- `config` - Video compression configuration
- `timeout` - Optional timeout duration (default: 5 minutes)

**Returns:** `Future<CompressionResult>`

### ImageCompressionConfig

Configuration for image compression.

```dart
ImageCompressionConfig({
  required String path,      // Path to the image file
  int quality = 80,          // Quality 0-100 (default: 80)
  int? maxWidth,             // Optional max width
  int? maxHeight,            // Optional max height
})
```

### VideoCompressionConfig

Configuration for video compression.

```dart
VideoCompressionConfig({
  required String path,              // Path to the video file
  VideoQuality quality = VideoQuality.medium,  // Quality preset
})
```

#### Video Compression Details

When you compress a video, the plugin uses native platform implementations to:

- **Reduce Bitrate**: Videos are re-encoded with lower bitrates based on quality preset
- **Optimize Format**: Output in MP4 container with H.264 video codec
- **Maintain Quality**: Balance between file size and visual quality
- **Preserve Audio**: Audio track is maintained during compression

**Quality Levels:**

| Quality | Use Case |
|---------|----------|
| `low` | Quick sharing, minimal file size |
| `medium` | General sharing, social media (recommended) |
| `high` | High-quality archival, professional use |

**Note:** Compression results depend on the original video's characteristics. Videos already heavily compressed may not see significant file size reduction.

## Examples

### Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:media_compressor/media_compressor.dart';
import 'package:image_picker/image_picker.dart';

class CompressionExample extends StatefulWidget {
  @override
  _CompressionExampleState createState() => _CompressionExampleState();
}

class _CompressionExampleState extends State<CompressionExample> {
  String? _result;

  Future<void> _compressImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;

    final result = await MediaCompressor.compressImage(
      ImageCompressionConfig(
        path: image.path,
        quality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      ),
    );

    setState(() {
      if (result.isSuccess) {
        _result = 'Image compressed: ${result.path}';
      } else {
        _result = 'Error: ${result.error?.message}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Media Compressor')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _compressImage,
              child: Text('Compress Image'),
            ),
            if (_result != null)
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(_result!),
              ),
          ],
        ),
      ),
    );
  }
}
```

## Best Practices

1. **Quality Settings**: Start with quality 80-85 for images - it provides good compression with minimal quality loss
2. **Dimension Limits**: Set maxWidth/maxHeight to prevent memory issues with very large images
3. **Error Handling**: Always check `result.isSuccess` before using the compressed file
4. **File Cleanup**: Delete temporary compressed files when no longer needed
5. **Timeout**: For large videos, consider increasing the timeout duration

## Performance Tips

- Image compression is fast and typically completes in milliseconds
- Video compression can take several seconds to minutes depending on file size
- Compressing multiple files? Do it sequentially to avoid memory issues
- Consider showing a loading indicator during video compression

## Troubleshooting

### Common Issues

**"File not found" error**
- Verify the file path is correct and the file exists
- Check that the app has necessary permissions

**Video compression timeout**
- Increase timeout duration for large videos
- Use lower quality settings for faster compression
- Check available device storage

**Out of memory errors**
- Reduce maxWidth/maxHeight for images
- Process files sequentially, not in parallel
- Close other memory-intensive operations

## Platform-Specific Features

Both Android and iOS provide full-featured compression with their own native optimizations.

**Core Features (Both Platforms):**
- ✅ Image compression with quality control (0-100)
- ✅ Image resolution limiting (maxWidth/maxHeight)
- ✅ Video compression with quality presets (low/medium/high)
- ✅ EXIF orientation handling
- ✅ Memory-efficient processing

For detailed information about platform-specific implementations, advanced features, bitrates, resolutions, and capabilities, see **[PLATFORM_FEATURES.md](PLATFORM_FEATURES.md)**.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues, feature requests, or questions, please file an issue on the [GitHub repository](https://github.com/yourusername/media_compressor).

---

**Made with ❤️ for the Flutter community**