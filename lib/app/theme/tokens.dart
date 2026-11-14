import 'package:flutter/material.dart';

/// Colour roles of the Lumen design system (`docs/DESIGN.md` › 色彩).
@immutable
class LsColors {
  /// Creates a colour set; use [LsColors.dark] or [LsColors.light].
  const LsColors({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentAlt,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.scrim,
  });

  /// The primary (dark) palette.
  static const dark = LsColors(
    bg: Color(0xFF0B0C10),
    surface: Color(0xFF14161C),
    surfaceRaised: Color(0xFF1B1E26),
    outline: Color(0x14FFFFFF),
    textPrimary: Color(0xFFF2F4F8),
    textSecondary: Color(0xFF9AA3B2),
    textTertiary: Color(0xFF626B7A),
    accent: Color(0xFF7C8CFF),
    accentAlt: Color(0xFF5CE1E6),
    onAccent: Color(0xFF0B0C10),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    scrim: Color(0xB80B0C10),
  );

  /// The light palette, finished to the same level as [dark].
  static const light = LsColors(
    bg: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    outline: Color(0x140B0C10),
    textPrimary: Color(0xFF0E1116),
    textSecondary: Color(0xFF5B6472),
    textTertiary: Color(0xFF8A93A1),
    accent: Color(0xFF4F5BFF),
    accentAlt: Color(0xFF12B5C4),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    scrim: Color(0x8C0E1116),
  );

  final Color bg;
  final Color surface;
  final Color surfaceRaised;

  /// Hairlines and card strokes.
  final Color outline;
  final Color textPrimary;
  final Color textSecondary;

  /// Placeholders and disabled content.
  final Color textTertiary;

  /// Primary actions, selection and focus.
  final Color accent;

  /// Only for the end of the signature gradient and the "online" dot.
  final Color accentAlt;
  final Color onAccent;
  final Color success;
  final Color warning;
  final Color danger;

  /// Modal barrier behind sheets, dialogs and the incoming-request card.
  final Color scrim;

  /// Interpolates every role, used by animated theme changes.
  LsColors lerp(LsColors other, double t) => LsColors(
    bg: Color.lerp(bg, other.bg, t)!,
    surface: Color.lerp(surface, other.surface, t)!,
    surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
    outline: Color.lerp(outline, other.outline, t)!,
    textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
    textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
    accent: Color.lerp(accent, other.accent, t)!,
    accentAlt: Color.lerp(accentAlt, other.accentAlt, t)!,
    onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    success: Color.lerp(success, other.success, t)!,
    warning: Color.lerp(warning, other.warning, t)!,
    danger: Color.lerp(danger, other.danger, t)!,
    scrim: Color.lerp(scrim, other.scrim, t)!,
  );
}

/// 4-pt spacing scale (`xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · xxxl 48`).
@immutable
class LsSpacing {
  /// The one spacing scale of the product.
  const LsSpacing();

  double get xs => 4;
  double get sm => 8;
  double get md => 12;
  double get lg => 16;
  double get xl => 24;
  double get xxl => 32;
  double get xxxl => 48;
}

/// Corner radii (`sm 10 · md 16 · lg 24 · xl 32 · full`).
@immutable
class LsRadii {
  /// The one radius scale of the product.
  const LsRadii();

  /// Tags and elements inside inputs.
  double get sm => 10;

  /// Buttons and inputs.
  double get md => 16;

  /// Cards.
  double get lg => 24;

  /// Dialogs and bottom sheets.
  double get xl => 32;

  /// Dots and capsules.
  double get full => 999;
}

/// Component sizes and layout breakpoints.
@immutable
class LsSizes {
  /// The one size scale of the product.
  const LsSizes();

  /// Minimum touch target (DESIGN.md › 原则 4).
  double get minTarget => 44;
  double get controlHeight => 48;
  double get controlHeightSmall => 36;
  double get iconSmall => 16;
  double get icon => 20;
  double get iconLarge => 24;

  /// Rounded square behind a device-kind icon.
  double get deviceBadge => 44;
  double get hairline => 1;
  double get focusRing => 2;
  double get dot => 8;
  double get orbCompact => 104;
  double get orbExpanded => 152;
  double get pinCellWidth => 52;
  double get pinCellHeight => 64;
  double get countdownRing => 40;
  double get switchWidth => 44;
  double get switchHeight => 26;
  double get switchKnob => 20;
  double get sidePanelWidth => 360;
  double get sheetMaxWidth => 460;
  double get cardMaxWidth => 440;
  double get readableMaxWidth => 720;
  double get contentMaxWidth => 1080;
  double get deviceTileHeight => 76;
  double get gridTileMaxExtent => 380;

  /// Width below which the layout is `compact`.
  double get compactMax => 600;

  /// Width from which the layout is `expanded`.
  double get expandedMin => 1024;
}

/// Type ramp (DESIGN.md › 字体); colours are applied by the consumer.
@immutable
class LsTypography {
  /// Builds the ramp on top of the system font stack.
  const LsTypography();

  /// Primary family, with [fontFallback] covering every platform and CJK.
  static const fontFamily = 'Inter';

  /// The rest of the stack from DESIGN.md.
  static const fontFallback = <String>[
    'SF Pro Text',
    'MiSans',
    'HarmonyOS Sans SC',
    'PingFang SC',
    'Noto Sans CJK SC',
    'Microsoft YaHei UI',
    'sans-serif',
  ];

  static const _tabular = [FontFeature.tabularFigures()];

  TextStyle _style(double size, double lineHeight, FontWeight weight, {double letterSpacing = 0}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  /// 40 / 44 · 600 — PIN digits; tabular.
  TextStyle get display =>
      _style(40, 44, FontWeight.w600, letterSpacing: -0.2).copyWith(fontFeatures: _tabular);

  /// 24 / 30 · 600 — page titles.
  TextStyle get title => _style(24, 30, FontWeight.w600, letterSpacing: -0.2);

  /// 18 / 24 · 600 — card and dialog titles.
  TextStyle get headline => _style(18, 24, FontWeight.w600, letterSpacing: -0.2);

  /// 15 / 22 · 400 — body copy.
  TextStyle get body => _style(15, 22, FontWeight.w400);

  /// 13 / 18 · 500 — buttons and labels.
  TextStyle get label => _style(13, 18, FontWeight.w500);

  /// 12 / 16 · 400 — captions and statistics.
  TextStyle get caption => _style(12, 16, FontWeight.w400);

  /// [caption] with tabular figures, for live numbers.
  TextStyle get stat => caption.copyWith(fontFeatures: _tabular);
}

/// A duration paired with its easing curve.
@immutable
class LsMotionSpec {
  /// Creates a motion spec.
  const LsMotionSpec(this.duration, this.curve);

  final Duration duration;
  final Curve curve;
}

/// Motion tokens (DESIGN.md › 动效).
@immutable
class LsMotion {
  /// The one motion scale of the product.
  const LsMotion();

  /// Hover and press.
  LsMotionSpec get fast => const LsMotionSpec(Duration(milliseconds: 120), Curves.easeOut);

  /// State changes, cards appearing.
  LsMotionSpec get base => const LsMotionSpec(Duration(milliseconds: 220), Curves.easeOutCubic);

  /// Page transitions, entering fullscreen.
  LsMotionSpec get slow => const LsMotionSpec(Duration(milliseconds: 420), Curves.easeInOutCubic);

  /// Looping discovery ripples and breathing glow.
  LsMotionSpec get ambient => const LsMotionSpec(Duration(milliseconds: 2400), Curves.easeOut);

  /// Delay between consecutive list items entering.
  Duration get stagger => const Duration(milliseconds: 40);

  /// Upward travel of an entering list item.
  double get entranceOffset => 8;

  /// Scale applied while a control is pressed.
  double get pressScale => 0.98;

  /// How long the session toolbar stays visible after the last interaction.
  Duration get toolbarLinger => const Duration(seconds: 3);

  /// How long a toast stays on screen.
  Duration get toastLinger => const Duration(milliseconds: 3200);
}

/// Every design token of Lumen, exposed to widgets through [ThemeData].
///
/// Read it with `context.ls` (see `context_ext.dart`); components must not
/// hard-code colours, sizes or durations.
@immutable
class LsTokens extends ThemeExtension<LsTokens> {
  /// Creates a token set; use [LsTokens.dark] or [LsTokens.light].
  const LsTokens({
    required this.brightness,
    required this.colors,
    required this.floatingShadow,
    this.space = const LsSpacing(),
    this.radius = const LsRadii(),
    this.size = const LsSizes(),
    this.text = const LsTypography(),
    this.motion = const LsMotion(),
  });

  /// Dark — the primary design.
  static const dark = LsTokens(
    brightness: Brightness.dark,
    colors: LsColors.dark,
    floatingShadow: [BoxShadow(color: Color(0x73000000), offset: Offset(0, 24), blurRadius: 64)],
  );

  /// Light — same finish as [dark].
  static const light = LsTokens(
    brightness: Brightness.light,
    colors: LsColors.light,
    floatingShadow: [BoxShadow(color: Color(0x1F0E1116), offset: Offset(0, 16), blurRadius: 48)],
  );

  final Brightness brightness;
  final LsColors colors;

  /// Shadow reserved for floating layers (sheets, dialogs, toasts).
  final List<BoxShadow> floatingShadow;
  final LsSpacing space;
  final LsRadii radius;
  final LsSizes size;
  final LsTypography text;
  final LsMotion motion;

  /// Signature `accent → accentAlt` gradient at 135°. Only for the local orb,
  /// primary buttons and the focused PIN cell.
  LinearGradient get signatureGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [colors.accent, colors.accentAlt],
  );

  /// The "active" glow: accent at 24 % with a 32 px blur.
  List<BoxShadow> get glow => [
    BoxShadow(color: colors.accent.withValues(alpha: 0.24), blurRadius: 32),
  ];

  @override
  LsTokens copyWith({LsColors? colors, List<BoxShadow>? floatingShadow}) {
    return LsTokens(
      brightness: brightness,
      colors: colors ?? this.colors,
      floatingShadow: floatingShadow ?? this.floatingShadow,
    );
  }

  @override
  LsTokens lerp(covariant LsTokens? other, double t) {
    if (other == null) return this;
    return LsTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      colors: colors.lerp(other.colors, t),
      floatingShadow: [
        for (var i = 0; i < floatingShadow.length; i++)
          BoxShadow.lerp(
            floatingShadow[i],
            i < other.floatingShadow.length ? other.floatingShadow[i] : null,
            t,
          )!,
      ],
    );
  }
}

/// Breakpoint classes from DESIGN.md: `compact < 600 ≤ medium < 1024 ≤ expanded`.
enum LsWindowClass {
  compact,
  medium,
  expanded;

  /// Classifies a logical width.
  static LsWindowClass of(double width, LsSizes sizes) {
    if (width < sizes.compactMax) return compact;
    if (width < sizes.expandedMin) return medium;
    return expanded;
  }
}
