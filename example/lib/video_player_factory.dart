// Picks the right video controller per platform.
// Web -> network/blob URL; mobile & desktop -> local File path.
import 'package:video_player/video_player.dart';

import 'video_player_factory_io.dart'
    if (dart.library.js_interop) 'video_player_factory_web.dart' as impl;

VideoPlayerController createVideoController(String pathOrUrl) =>
    impl.createVideoController(pathOrUrl);