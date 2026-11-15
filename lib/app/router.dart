import 'package:flutter/material.dart';

import 'theme/lumen.dart';

/// Navigator used by the app shell to push session and request screens.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Lumen page transition: fade with an 8 dp rise over `motion.slow`;
/// a plain fade when motion is reduced.
class LsPageRoute<T> extends PageRouteBuilder<T> {
  /// Creates a page route.
  LsPageRoute({
    required WidgetBuilder builder,
    required LsTokens tokens,
    required bool reduceMotion,
    super.settings,
    super.opaque,
    super.fullscreenDialog,
  }) : super(
         transitionDuration: tokens.motion.slow.duration,
         reverseTransitionDuration: tokens.motion.base.duration,
         pageBuilder: (context, _, _) => builder(context),
         transitionsBuilder: (context, animation, _, child) {
           final curved = CurvedAnimation(parent: animation, curve: tokens.motion.slow.curve);
           if (reduceMotion) return FadeTransition(opacity: curved, child: child);
           return FadeTransition(
             opacity: curved,
             child: AnimatedBuilder(
               animation: curved,
               builder: (context, child) => Transform.translate(
                 offset: Offset(0, tokens.motion.entranceOffset * (1 - curved.value)),
                 child: child,
               ),
               child: child,
             ),
           );
         },
       );

  /// Builds a route themed from [context].
  static LsPageRoute<T> of<T>(BuildContext context, WidgetBuilder builder, {bool opaque = true}) {
    return LsPageRoute<T>(
      builder: builder,
      tokens: context.ls,
      reduceMotion: context.reduceMotion,
      opaque: opaque,
    );
  }
}
