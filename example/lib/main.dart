import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_compressor/media_compressor.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media Compressor Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MediaCompressorDemo(),
    );
  }
}

class MediaCompressorDemo extends StatefulWidget {
  const MediaCompressorDemo({super.key});

  @override
  State<MediaCompressorDemo> createState() => _MediaCompressorDemoState();
}

class _MediaCompressorDemoState extends State<MediaCompressorDemo> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Compressor Demo'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.image), text: 'Images'),
            Tab(icon: Icon(Icons.video_library), text: 'Videos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ImageCompressorTab(picker: _picker),
          VideoCompressorTab(picker: _picker),
        ],
      ),
    );
  }
}

// ============================================================================
// IMAGE COMPRESSOR TAB
// ============================================================================

class ImageCompressorTab extends StatefulWidget {
  final ImagePicker picker;

  const ImageCompressorTab({super.key, required this.picker});

  @override
  State<ImageCompressorTab> createState() => _ImageCompressorTabState();
}

class _ImageCompressorTabState extends State<ImageCompressorTab> {
  File? _originalImage;
  File? _compressedImage;
  int _quality = 80;
  int _maxWidth = 1920;
  int _maxHeight = 1080;
  bool _isCompressing = false;
  String? _statusMessage;
  CompressionResult? _lastResult;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await widget.picker.pickImage(source: source);

      if (image == null) return;

      setState(() {
        _originalImage = File(image.path);
        _compressedImage = null;
        _statusMessage = null;
        _lastResult = null;
      });

      await _compressImage();
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _compressImage() async {
    if (_originalImage == null) return;

    setState(() {
      _isCompressing = true;
      _statusMessage = 'Compressing...';
    });

    try {
      final result = await MediaCompressor.compressImage(
        ImageCompressionConfig(
          path: _originalImage!.path,
          quality: _quality,
          maxWidth: _maxWidth,
          maxHeight: _maxHeight,
    
        ),
      );

      if (result.isSuccess) {
        final originalFile = File(_originalImage!.path);
        final compressedFile = File(result.path!);

        final originalSize = await originalFile.length();
        final compressedSize = await compressedFile.length();
        final savedPercentage = ((1 - (compressedSize / originalSize)) * 100).toStringAsFixed(1);

        setState(() {
          _compressedImage = compressedFile;
          _lastResult = result;
          _statusMessage = 'Compression Successful!\n'
              'Original: ${_formatBytes(originalSize)}\n'
              'Compressed: ${_formatBytes(compressedSize)}\n'
              'Saved: $savedPercentage%\n';

          _isCompressing = false;
        });
      } else {
        setState(() {
          _statusMessage = 'Error: ${result.error!.message}';
          _isCompressing = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isCompressing = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Source Selection Buttons
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Select Image Source',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isCompressing ? null : () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isCompressing ? null : () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Compression Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Compression Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text('Quality: $_quality%'),
                  Slider(
                    value: _quality.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: _quality.toString(),
                    onChanged: (value) {
                      setState(() {
                        _quality = value.toInt();
                      });
                    },
                    onChangeEnd: (value) {
                      if (_originalImage != null) {
                        _compressImage();
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Max Width: $_maxWidth px'),
                  Slider(
                    value: _maxWidth.toDouble(),
                    min: 480,
                    max: 3840,
                    divisions: 10,
                    label: _maxWidth.toString(),
                    onChanged: (value) {
                      setState(() {
                        _maxWidth = value.toInt();
                      });
                    },
                    onChangeEnd: (value) {
                      if (_originalImage != null) {
                        _compressImage();
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Max Height: $_maxHeight px'),
                  Slider(
                    value: _maxHeight.toDouble(),
                    min: 480,
                    max: 2160,
                    divisions: 10,
                    label: _maxHeight.toString(),
                    onChanged: (value) {
                      setState(() {
                        _maxHeight = value.toInt();
                      });
                    },
                    onChangeEnd: (value) {
                      if (_originalImage != null) {
                        _compressImage();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Card(
              color: _statusMessage!.contains('Error')
                  ? Colors.red.shade50
                  : Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _statusMessage!.contains('Error')
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          color: _statusMessage!.contains('Error')
                              ? Colors.red.shade900
                              : Colors.green.shade900,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Status',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: _statusMessage!.contains('Error')
                            ? Colors.red.shade900
                            : Colors.green.shade900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (_originalImage != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Comparison',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Original',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _originalImage!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Compressed',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _isCompressing
                          ? Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _compressedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _compressedImage!,
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text('No compressed image'),
                                  ),
                                ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// VIDEO COMPRESSOR TAB
// ============================================================================

class VideoCompressorTab extends StatefulWidget {
  final ImagePicker picker;

  const VideoCompressorTab({super.key, required this.picker});

  @override
  State<VideoCompressorTab> createState() => _VideoCompressorTabState();
}

class _VideoCompressorTabState extends State<VideoCompressorTab> {
  File? _originalVideo;
  File? _compressedVideo;
  VideoQuality _quality = VideoQuality.medium;
  bool _isCompressing = false;
  String? _statusMessage;
  CompressionResult? _lastResult;

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? video = await widget.picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5), // Limit to 5 minutes
      );

      if (video == null) return;

      setState(() {
        _originalVideo = File(video.path);
        _compressedVideo = null;
        _statusMessage = null;
        _lastResult = null;
      });

      await _compressVideo();
    } catch (e) {
      _showError('Failed to pick video: $e');
    }
  }

  Future<void> _compressVideo() async {
    if (_originalVideo == null) return;

    setState(() {
      _isCompressing = true;
      _statusMessage = 'Compressing video...\nThis may take a while.';
    });

    try {
      final result = await MediaCompressor.compressVideo(
        VideoCompressionConfig(
          path: _originalVideo!.path,
          quality: _quality,
       
        ),
      );

      if (result.isSuccess) {
        final originalFile = File(_originalVideo!.path);
        final compressedFile = File(result.path!);

        final originalSize = await originalFile.length();
        final compressedSize = await compressedFile.length();
        final savedPercentage = ((1 - (compressedSize / originalSize)) * 100).toStringAsFixed(1);

        setState(() {
          _compressedVideo = compressedFile;
          _lastResult = result;
          _statusMessage = 'Compression Successful!\n'
              'Original: ${_formatBytes(originalSize)}\n'
              'Compressed: ${_formatBytes(compressedSize)}\n'
              'Saved: $savedPercentage%\n';
          _isCompressing = false;
        });
      } else {
        setState(() {
          _statusMessage = 'Error: ${result.error!.message}\n\n'
              'Note: Video compression is currently only supported on iOS.';
          _isCompressing = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e\n\n'
            'Note: Video compression is currently only supported on iOS.';
        _isCompressing = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    if (seconds < 60) return '${seconds}s';
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Platform Support Warning
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade900),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Video compression is currently supported on iOS only. Android support coming soon!',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Source Selection Buttons
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Select Video Source',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isCompressing ? null : () => _pickVideo(ImageSource.camera),
                          icon: const Icon(Icons.videocam),
                          label: const Text('Record'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isCompressing ? null : () => _pickVideo(ImageSource.gallery),
                          icon: const Icon(Icons.video_library),
                          label: const Text('Gallery'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quality Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Compression Quality',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<VideoQuality>(
                    segments: const [
                      ButtonSegment(
                        value: VideoQuality.low,
                        label: Text('Low'),
                        icon: Icon(Icons.battery_saver),
                      ),
                      ButtonSegment(
                        value: VideoQuality.medium,
                        label: Text('Medium'),
                        icon: Icon(Icons.balance),
                      ),
                      ButtonSegment(
                        value: VideoQuality.high,
                        label: Text('High'),
                        icon: Icon(Icons.high_quality),
                      ),
                    ],
                    selected: {_quality},
                    onSelectionChanged: (Set<VideoQuality> newSelection) {
                      setState(() {
                        _quality = newSelection.first;
                      });
                      if (_originalVideo != null) {
                        _compressVideo();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected: ${_quality.name.toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        // Text('Bitrate: ${(_quality.suggestedBitrate / 1000000).toStringAsFixed(1)} Mbps'),
                        // Text('Max Height: ${_quality.suggestedHeight}p'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Card(
              color: _statusMessage!.contains('Error')
                  ? Colors.red.shade50
                  : _isCompressing
                      ? Colors.blue.shade50
                      : Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_isCompressing)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            _statusMessage!.contains('Error')
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            color: _statusMessage!.contains('Error')
                                ? Colors.red.shade900
                                : Colors.green.shade900,
                          ),
                        const SizedBox(width: 8),
                        const Text(
                          'Status',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: _statusMessage!.contains('Error')
                            ? Colors.red.shade900
                            : _isCompressing
                                ? Colors.blue.shade900
                                : Colors.green.shade900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (_originalVideo != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Video Files',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.video_file, color: Colors.blue),
                      title: const Text('Original Video'),
                      subtitle: Text(_originalVideo!.path.split('/').last),
                      trailing: FutureBuilder<int>(
                        future: _originalVideo!.length(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Text(_formatBytes(snapshot.data!));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    if (_compressedVideo != null) ...[
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.video_file, color: Colors.green),
                        title: const Text('Compressed Video'),
                        subtitle: Text(_compressedVideo!.path.split('/').last),
                        trailing: FutureBuilder<int>(
                          future: _compressedVideo!.length(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Text(_formatBytes(snapshot.data!));
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}