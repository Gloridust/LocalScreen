import 'package:flutter/material.dart';

import 'tokens.dart';

/// Builds the Material [ThemeData] that hosts the Lumen [LsTokens].
///
/// Material widgets are only used as plumbing (text selection, scrolling,
/// focus); every visible component reads [LsTokens] directly.
ThemeData buildLsTheme(LsTokens t) {
  final c = t.colors;
  final type = t.text;
  final scheme = ColorScheme(
    brightness: t.brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.accentAlt,
    onSecondary: c.onAccent,
    error: c.danger,
    onError: c.onAccent,
    surface: c.surface,
    onSurface: c.textPrimary,
    onSurfaceVariant: c.textSecondary,
    outline: c.outline,
    outlineVariant: c.outline,
    surfaceContainerHighest: c.surfaceRaised,
  );
  TextStyle tinted(TextStyle s, Color color) => s.copyWith(color: color);
  final textTheme = TextTheme(
    displayLarge: tinted(type.display, c.textPrimary),
    headlineMedium: tinted(type.title, c.textPrimary),
    titleLarge: tinted(type.title, c.textPrimary),
    titleMedium: tinted(type.headline, c.textPrimary),
    bodyLarge: tinted(type.body, c.textPrimary),
    bodyMedium: tinted(type.body, c.textPrimary),
    bodySmall: tinted(type.caption, c.textSecondary),
    labelLarge: tinted(type.label, c.textPrimary),
    labelMedium: tinted(type.label, c.textSecondary),
    labelSmall: tinted(type.caption, c.textSecondary),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: t.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    fontFamily: LsTypography.fontFamily,
    fontFamilyFallback: LsTypography.fontFallback,
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    splashColor: Colors.transparent,
    focusColor: c.accent.withValues(alpha: 0.16),
    dividerColor: c.outline,
    iconTheme: IconThemeData(color: c.textSecondary, size: t.size.icon),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withValues(alpha: 0.28),
      selectionHandleColor: c.accent,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.textTertiary.withValues(alpha: 0.4)),
      radius: Radius.circular(t.radius.full),
      thickness: WidgetStatePropertyAll(t.space.xs),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(t.radius.sm),
        border: Border.all(color: c.outline),
        boxShadow: t.floatingShadow,
      ),
      textStyle: tinted(type.caption, c.textPrimary),
      waitDuration: t.motion.slow.duration,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    extensions: [t],
  );
}
