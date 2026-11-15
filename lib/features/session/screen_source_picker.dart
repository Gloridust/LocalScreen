import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/router.dart';
import '../../app/theme/lumen.dart';
import '../../core/media/captured_screen.dart';

/// Asks the user which screen to share, when there are several and the
/// platform leaves the choice to the app.
Future<ScreenOption?> chooseScreenSource(List<ScreenOption> screens) async {
  final context = appNavigatorKey.currentContext;
  if (context == null) return screens.first;
  return showLsSheet<ScreenOption>(context, builder: (_) => _ScreenSourcePicker(screens: screens));
}

class _ScreenSourcePicker extends StatelessWidget {
  const _ScreenSourcePicker({required this.screens});

  final List<ScreenOption> screens;

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
                              ? ColoredBox(
                                  color: c.bg,
                                  child: Icon(
                                    Icons.monitor_rounded,
                                    size: ls.size.iconLarge,
                                    color: c.textTertiary,
                                  ),
                                )
                              : Image.memory(
                                  Uint8List.fromList(s.thumbnail!),
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                        ),
                      ),
                      SizedBox(height: ls.space.sm),
                      Text(
                        s.title ?? l10n.screenPickerScreen(i + 1),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ls.text.label.copyWith(color: c.textPrimary),
                      ),
                      if (s.detail != null)
                        Text(
                          s.detail!,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ls.text.caption.copyWith(color: c.textSecondary),
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
