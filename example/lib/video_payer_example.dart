import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:native_video_player/native_video_player.dart';

class NativeVideoPlayerScreen extends StatefulWidget {
  final String? videoPath; // nullable
  const NativeVideoPlayerScreen({super.key, this.videoPath});
  
  @override
  State<NativeVideoPlayerScreen> createState() =>
      _NativeVideoPlayerScreenState();
}

class _NativeVideoPlayerScreenState extends State<NativeVideoPlayerScreen> {
  NativeVideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isReady = false;
  double _volume = 1.0; // 0.0 to 1.0

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadVideo() async {
    final path = widget.videoPath;
    if (path == null) return;

    final file = File(path);
    if (!await file.exists()) {
      log('Video file does not exist: $path');
      return;
    }

    await _controller?.loadVideo(
      VideoSource(
        path: path,
        type: VideoSourceType.file,
      ),
    );

    setState(() {
      _isReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.videoPath?.split('/').last ?? 'No Video')),
      body: Column(
        children: [
          Expanded(
            child: NativeVideoPlayerView(
              onViewReady: (controller) {
                _controller = controller;
                _loadVideo();
              },
            ),
          ),
          if (_isReady)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Rewind 5 seconds
                      IconButton(
                        icon: const Icon(Icons.replay_5),
                        onPressed: () {
                          // _controller?.seekBy(Duration(seconds: -5));
                        },
                      ),
                      // Play / Pause
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: () {
                          if (_isPlaying) {
                            _controller?.pause();
                          } else {
                            _controller?.play();
                          }
                          setState(() => _isPlaying = !_isPlaying);
                        },
                      ),
                      // Fast-forward 5 seconds
                      IconButton(
                        icon: const Icon(Icons.forward_5),
                        onPressed: () {
                          // _controller?.seekBy(Duration(seconds: 5));
                        },
                      ),
                      // Stop
                      IconButton(
                        icon: const Icon(Icons.stop),
                        onPressed: () {
                          _controller?.seekTo(Duration.zero);
                          _controller?.pause();
                          setState(() => _isPlaying = false);
                        },
                      ),
                    ],
                  ),
                  // Volume slider
                  Row(
                    children: [
                      const Icon(Icons.volume_down),
                      Expanded(
                        child: Slider(
                          value: _volume,
                          onChanged: (value) {
                            setState(() => _volume = value);
                            _controller?.setVolume(value);
                          },
                          min: 0,
                          max: 1,
                        ),
                      ),
                      const Icon(Icons.volume_up),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
