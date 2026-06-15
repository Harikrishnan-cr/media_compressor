// Web: play from a blob / object URL.
import 'package:video_player/video_player.dart';

VideoPlayerController createVideoController(String url) =>
    VideoPlayerController.networkUrl(Uri.parse(url));