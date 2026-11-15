import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show DesktopCapturerSource;

import '../../app/l10n.dart';
import '../../app/router.dart';
import '../../app/theme/lumen.dart';

/// Asks the user which screen to share (Windows / macOS with several
/// screens; Linux uses the system portal instead).
Future<DesktopCapturerSource?> chooseScreenSource(List<DesktopCapturerSource> screens) async {
  final context = appNavigatorKey.currentContext;
  if (context == null) return screens.first;
  return showLsSheet<DesktopCapturerSource>(
    context,
    builder: (_) => _ScreenSourcePicker(screens: screens),
  );
}

class _ScreenSourcePicker extends StatelessWidget {
  const _ScreenSourcePicker({required this.screens});

  final List<DesktopCapturerSource> screens;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.screenPickerTitle, style: ls.text.headline.copyWith(color: c.textPrimary)),
        SizedBox(height: ls.space.xl),
        Wrap(
          spacing: ls.space.md,
          runSpacing: ls.space.md,
          children: [
            for (final (i, s) in screens.indexed)
              SizedBox(
                width: (ls.size.sheetMaxWidth - ls.space.xxl * 2 - ls.space.md) / 2,
                child: LsCard(
                  padding: EdgeInsets.all(ls.space.sm),
                  onTap: () => Navigator.of(context).pop(s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(ls.radius.sm),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: s.thumbnail == null
                              ? ColoredBox(color: c.bg)
                              : Image.memory(
                                  s.thumbnail!,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                        ),
                      ),
                      SizedBox(height: ls.space.sm),
                      Text(
                        l10n.screenPickerScreen(i + 1),
                        textAlign: TextAlign.center,
                        style: ls.text.label.copyWith(color: c.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: ls.space.xl),
        LsButton.ghost(
          label: l10n.cancel,
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
