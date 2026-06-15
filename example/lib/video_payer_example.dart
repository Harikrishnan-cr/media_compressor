// Cross-platform video comparison screen (Web + mobile + desktop).
// Uses video_player via the conditional controller factory.
import 'package:flutter/material.dart';
import 'package:media_compressor_example/video_player_factory.dart';
import 'package:video_player/video_player.dart';


class VideoCompareScreen extends StatelessWidget {
  const VideoCompareScreen({
    super.key,
    required this.originalPath,
    required this.compressedPath,
    required this.originalSize,
    required this.compressedSize,
  });

  final String originalPath;
  final String compressedPath;
  final int originalSize;
  final int compressedSize;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final reduction = originalSize > 0
        ? ((1 - compressedSize / originalSize) * 100).toInt()
        : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Video Comparison')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('$reduction% smaller',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.green)),
            const SizedBox(height: 12),
            Expanded(
              child: _VideoCard(
                  label: 'Original',
                  pathOrUrl: originalPath,
                  size: _formatBytes(originalSize)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _VideoCard(
                  label: 'Compressed',
                  pathOrUrl: compressedPath,
                  size: _formatBytes(compressedSize)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoCard extends StatefulWidget {
  const _VideoCard(
      {required this.label, required this.pathOrUrl, required this.size});
  final String label;
  final String pathOrUrl;
  final String size;

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = createVideoController(widget.pathOrUrl)
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }).catchError((_) {
        if (mounted) setState(() => _ready = false);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(widget.size,
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 8),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _ready
                    ? AspectRatio(
                        aspectRatio: _controller.value.aspectRatio == 0
                            ? 16 / 9
                            : _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      )
                    : Container(
                        color: Colors.black12,
                        child:
                            const Center(child: CircularProgressIndicator()),
                      ),
              ),
              if (_ready)
                IconButton(
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_circle
                        : Icons.play_circle,
                    size: 58,
                    color: Colors.white,
                  ),
                  onPressed: () => setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  }),
                ),
            ],
          ),
        ),
      ],
    );
  }
}