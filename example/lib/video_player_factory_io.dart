// Mobile / desktop: play from a local file path.
import 'dart:io';
import 'package:video_player/video_player.dart';

VideoPlayerController createVideoController(String path) =>
    VideoPlayerController.file(File(path));