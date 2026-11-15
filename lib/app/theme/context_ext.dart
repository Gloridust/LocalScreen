import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Convenience accessors for the Lumen tokens.
extension LsContext on BuildContext {
  /// The active [LsTokens]; falls back to dark if the theme lacks them.
  LsTokens get ls => Theme.of(this).extension<LsTokens>() ?? LsTokens.dark;

  /// Whether the platform asked for reduced motion.
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  /// Current breakpoint class.
  LsWindowClass get windowClass => LsWindowClass.of(MediaQuery.sizeOf(this).width, ls.size);
}

/// Motion helpers that honour reduced motion.
extension LsMotionContext on BuildContext {
  /// [spec]'s duration, or zero when motion is reduced and [essential] is false.
  Duration motionDuration(LsMotionSpec spec, {bool essential = false}) {
    if (reduceMotion && !essential) return Duration.zero;
    return spec.duration;
  }
}
