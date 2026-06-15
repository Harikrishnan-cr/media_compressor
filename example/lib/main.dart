import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_compressor/media_compressor.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _picker = ImagePicker();
  Uint8List? _bytes;
  String? _status;

  Future<void> _pickAndCompress() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _status = 'Compressing...');
    final result = await MediaCompressor.compressImage(
      ImageCompressionConfig(
        path: file.path,
        quality: 70,
        maxWidth: 1920,
        maxHeight: 1080,
      ),
    );
    if (result.isSuccess) {
      // Cross-platform read (file path on mobile, blob URL on web).
      final out = XFile(result.path!);
      final bytes = await out.readAsBytes();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _status = 'Done — ${(bytes.length / 1024).toStringAsFixed(1)} KB';
      });
      await MediaCompressor.release(result.path!);
    } else {
      if (!mounted) return;
      setState(() => _status = 'Failed: ${result.error?.message}');
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
            if (_bytes != null)
              SizedBox(height: 240, child: Image.memory(_bytes!)),
            if (_status != null) Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_status!),
            ),
            ElevatedButton(
              onPressed: _pickAndCompress,
              child: const Text('Pick & compress image'),
            ),
          ],
        ),
      ),
    );
  }
}

// // Cross-platform Media Compressor example (Web + Android + iOS + Desktop).
// //
// // Web compatibility notes:
// //  - No `dart:io`. Sizes/bytes go through `XFile` (handles file paths on
// //    mobile AND blob URLs on web).
// //  - Image previews use `Image.memory` (platform agnostic).
// //  - Video playback uses `video_player` via a conditional factory.
// //  - Real progress comes from the `native_compressor/progress` EventChannel
// //    (Android + Web). iOS emits no progress yet.

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:image_picker/image_picker.dart'; // exports XFile
// import 'package:media_compressor/media_compressor.dart';
// import 'package:media_compressor_example/video_payer_example.dart';


// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Media Compressor Demo',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         useMaterial3: true,
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
//       ),
//       home: const CompressorDemo(),
//     );
//   }
// }

// class CompressorDemo extends StatefulWidget {
//   const CompressorDemo({super.key});

//   @override
//   State<CompressorDemo> createState() => _CompressorDemoState();
// }

// class _CompressorDemoState extends State<CompressorDemo> {
//   final ImagePicker _picker = ImagePicker();

//   static const EventChannel _progressChannel =
//       EventChannel('native_compressor/progress');
//   StreamSubscription<dynamic>? _progressSub;

//   XFile? _originalFile;
//   String? _compressedPath;

//   Uint8List? _originalImageBytes;
//   Uint8List? _compressedImageBytes;

//   int? _originalSize;
//   int? _compressedSize;

//   bool _isCompressing = false;
//   double _progress = 0.0;
//   String _selectedType = 'image';

//   int _imageQuality = 80;
//   VideoQuality _videoQuality = VideoQuality.medium;

//   @override
//   void dispose() {
//     _progressSub?.cancel();
//     super.dispose();
//   }

//   void _listenProgress() {
//     _progressSub?.cancel();
//     _progressSub = _progressChannel.receiveBroadcastStream().listen(
//       (event) {
//         if (!_isCompressing || !mounted) return;
//         if (event is Map && event['progress'] != null) {
//           setState(() => _progress = (event['progress'] as num).toDouble());
//         }
//       },
//       onError: (_) {},
//     );
//   }

//   Future<void> _pickFile() async {
//     try {
//       final XFile? file = _selectedType == 'image'
//           ? await _picker.pickImage(source: ImageSource.gallery)
//           : await _picker.pickVideo(source: ImageSource.gallery);
//       if (file == null) return;

//       final size = await file.length();
//       Uint8List? imgBytes;
//       if (_selectedType == 'image') {
//         imgBytes = await file.readAsBytes();
//       }

//       setState(() {
//         _originalFile = file;
//         _originalSize = size;
//         _originalImageBytes = imgBytes;
//         _compressedPath = null;
//         _compressedSize = null;
//         _compressedImageBytes = null;
//         _progress = 0.0;
//       });

//       if (_selectedType == 'image') {
//         await _compressImage();
//       } else {
//         await _compressVideo();
//       }
//     } catch (e) {
//       _showError('Failed to pick file: $e');
//     }
//   }

//   Future<void> _compressImage() async {
//     final original = _originalFile;
//     if (original == null) return;

//     setState(() {
//       _isCompressing = true;
//       _progress = 0.0;
//     });
//     _listenProgress();

//     try {
//       final result = await MediaCompressor.compressImage(
//         ImageCompressionConfig(
//           path: original.path,
//           quality: _imageQuality,
//           maxWidth: 1920,
//           maxHeight: 1080,
//         ),
//       );

//       if (result.isSuccess) {
//         final out = XFile(result.path!);
//         final bytes = await out.readAsBytes();
//         if (!mounted) return;
//         setState(() {
//           _compressedPath = result.path;
//           _compressedImageBytes = bytes;
//           _compressedSize = bytes.length;
//           _progress = 1.0;
//           _isCompressing = false;
//         });
//       } else {
//         throw Exception(result.error?.message ?? 'Compression failed');
//       }
//     } catch (e) {
//       if (mounted) setState(() => _isCompressing = false);
//       _showError('Compression failed: $e');
//     }
//   }

//   Future<void> _compressVideo() async {
//     final original = _originalFile;
//     if (original == null) return;

//     setState(() {
//       _isCompressing = true;
//       _progress = 0.0;
//     });
//     _listenProgress();

//     try {
//       final result = await MediaCompressor.compressVideo(
//         VideoCompressionConfig(
//           path: original.path,
//           quality: _videoQuality,
//         ),
//       );

//       if (result.isSuccess) {
//         final out = XFile(result.path!);
//         final compressedSize = await out.length();
//         if (!mounted) return;
//         setState(() {
//           _compressedPath = result.path;
//           _compressedSize = compressedSize;
//           _progress = 1.0;
//           _isCompressing = false;
//         });

//         if (mounted) {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (_) => VideoCompareScreen(
//                 originalPath: original.path,
//                 compressedPath: result.path!,
//                 originalSize: _originalSize ?? 0,
//                 compressedSize: compressedSize,
//               ),
//             ),
//           );
//         }
//       } else {
//         throw Exception(result.error?.message ?? 'Compression failed');
//       }
//     } catch (e) {
//       if (mounted) setState(() => _isCompressing = false);
//       _showError('Compression failed: $e');
//     }
//   }

//   String _formatBytes(int bytes) {
//     if (bytes < 1024) return '$bytes B';
//     if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
//     return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
//   }

//   void _showError(String message) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message), backgroundColor: Colors.red),
//     );
//   }

//   void _resetState() {
//     setState(() {
//       _originalFile = null;
//       _compressedPath = null;
//       _originalImageBytes = null;
//       _compressedImageBytes = null;
//       _originalSize = null;
//       _compressedSize = null;
//       _progress = 0.0;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final reduction = (_originalSize != null &&
//             _compressedSize != null &&
//             _originalSize! > 0)
//         ? ((1 - (_compressedSize! / _originalSize!)) * 100).toInt()
//         : null;

//     return Scaffold(
//       appBar: AppBar(title: const Text('Media Compressor'), centerTitle: true),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Row(
//               children: [
//                 Expanded(
//                   child: ChoiceChip(
//                     label: const Text('Image'),
//                     selected: _selectedType == 'image',
//                     onSelected: _isCompressing
//                         ? null
//                         : (_) {
//                             setState(() => _selectedType = 'image');
//                             _resetState();
//                           },
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: ChoiceChip(
//                     label: const Text('Video'),
//                     selected: _selectedType == 'video',
//                     onSelected: _isCompressing
//                         ? null
//                         : (_) {
//                             setState(() => _selectedType = 'video');
//                             _resetState();
//                           },
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton.icon(
//               onPressed: _isCompressing ? null : _pickFile,
//               icon: Icon(
//                   _selectedType == 'image' ? Icons.image : Icons.video_library),
//               label: Text(
//                   'Select ${_selectedType == 'image' ? 'Image' : 'Video'}'),
//               style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
//             ),
//             const SizedBox(height: 20),
//             if (_selectedType == 'image') ...[
//               const Text('Image Quality',
//                   style: TextStyle(fontWeight: FontWeight.w500)),
//               Row(
//                 children: [
//                   const Text('Low', style: TextStyle(fontSize: 12)),
//                   Expanded(
//                     child: Slider(
//                       value: _imageQuality.toDouble(),
//                       min: 10,
//                       max: 100,
//                       divisions: 18,
//                       label: '$_imageQuality%',
//                       onChanged: _isCompressing
//                           ? null
//                           : (v) => setState(() => _imageQuality = v.toInt()),
//                       onChangeEnd: (_) {
//                         if (_originalFile != null) _compressImage();
//                       },
//                     ),
//                   ),
//                   const Text('High', style: TextStyle(fontSize: 12)),
//                 ],
//               ),
//             ] else ...[
//               const Text('Video Quality',
//                   style: TextStyle(fontWeight: FontWeight.w500)),
//               const SizedBox(height: 8),
//               SegmentedButton<VideoQuality>(
//                 segments: const [
//                   ButtonSegment(value: VideoQuality.low, label: Text('Low')),
//                   ButtonSegment(
//                       value: VideoQuality.medium, label: Text('Medium')),
//                   ButtonSegment(value: VideoQuality.high, label: Text('High')),
//                 ],
//                 selected: {_videoQuality},
//                 onSelectionChanged: _isCompressing
//                     ? null
//                     : (sel) {
//                         setState(() => _videoQuality = sel.first);
//                         if (_originalFile != null) _compressVideo();
//                       },
//               ),
//             ],
//             if (_isCompressing) ...[
//               const SizedBox(height: 24),
//               const Text('Compressing...',
//                   textAlign: TextAlign.center,
//                   style:
//                       TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
//               const SizedBox(height: 12),
//               LinearProgressIndicator(
//                 value: _progress == 0 ? null : _progress,
//                 minHeight: 8,
//                 borderRadius: BorderRadius.circular(4),
//               ),
//               const SizedBox(height: 8),
//               Text('${(_progress * 100).toInt()}%',
//                   textAlign: TextAlign.center),
//             ],
//             if (_originalSize != null) ...[
//               const SizedBox(height: 24),
//               Row(
//                 children: [
//                   Expanded(
//                     child: _SizeCard(
//                         label: 'Before',
//                         size: _formatBytes(_originalSize!),
//                         color: Colors.grey),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: _SizeCard(
//                       label: 'After',
//                       size: _compressedSize != null
//                           ? _formatBytes(_compressedSize!)
//                           : '...',
//                       color: Colors.green,
//                     ),
//                   ),
//                 ],
//               ),
//               if (reduction != null) ...[
//                 const SizedBox(height: 8),
//                 Text('$reduction% smaller',
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(
//                         fontWeight: FontWeight.w600, color: Colors.green)),
//               ],
//             ],
//             if (_selectedType == 'image' && _originalImageBytes != null) ...[
//               const SizedBox(height: 24),
//               Row(
//                 children: [
//                   Expanded(
//                     child: _ImagePreview(
//                         label: 'Original',
//                         bytes: _originalImageBytes,
//                         isLoading: false),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: _ImagePreview(
//                         label: 'Compressed',
//                         bytes: _compressedImageBytes,
//                         isLoading: _isCompressing),
//                   ),
//                 ],
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _SizeCard extends StatelessWidget {
//   const _SizeCard(
//       {required this.label, required this.size, required this.color});
//   final String label;
//   final String size;
//   final Color color;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.12),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         children: [
//           Text(label, style: const TextStyle(fontSize: 14)),
//           const SizedBox(height: 4),
//           Text(size,
//               style:
//                   const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//         ],
//       ),
//     );
//   }
// }

// class _ImagePreview extends StatelessWidget {
//   const _ImagePreview(
//       {required this.label, required this.bytes, required this.isLoading});
//   final String label;
//   final Uint8List? bytes;
//   final bool isLoading;

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
//         const SizedBox(height: 8),
//         AspectRatio(
//           aspectRatio: 1,
//           child: ClipRRect(
//             borderRadius: BorderRadius.circular(8),
//             child: bytes != null
//                 ? Image.memory(bytes!, fit: BoxFit.cover)
//                 : Container(
//                     color: Colors.grey.shade200,
//                     child: isLoading
//                         ? const Center(child: CircularProgressIndicator())
//                         : null,
//                   ),
//           ),
//         ),
//       ],
//     );
//   }
// }