import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media_session.dart';

/// The media engine; overridden at startup (WebRTC or fake).
final mediaEngineProvider = Provider<MediaEngine>(
  (ref) => throw UnimplementedError('mediaEngineProvider must be overridden'),
);
