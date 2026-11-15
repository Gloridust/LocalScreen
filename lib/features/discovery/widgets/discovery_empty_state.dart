import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../../app/l10n.dart';
import '../../../app/theme/lumen.dart';

/// "Looking for nearby devices…" with a centred ripple and two hints.
class DiscoveryEmptyState extends StatelessWidget {
  /// Creates the empty state; [onManualConnect] null hides the action.
  const DiscoveryEmptyState({super.key, required this.onManualConnect});

  final VoidCallback? onManualConnect;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    final core = ls.size.deviceBadge + ls.space.md;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: ls.size.cardMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LsRipples(
              coreSize: core,
              color: c.textSecondary,
              spread: 2.6,
              child: Container(
                width: core,
                height: core,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.surface,
                  border: Border.all(color: c.outline),
                ),
                child: Icon(Icons.radar_rounded, color: c.textSecondary, size: ls.size.iconLarge),
              ),
            ),
            Text(
              l10n.emptySearching,
              textAlign: TextAlign.center,
              style: ls.text.headline.copyWith(color: c.textPrimary),
            ),
            SizedBox(height: ls.space.sm),
            Text(
              l10n.emptyHintSameWifi,
              textAlign: TextAlign.center,
              style: ls.text.body.copyWith(color: c.textSecondary),
            ),
            if (onManualConnect != null) ...[
              SizedBox(height: ls.space.xl),
              Text(
                l10n.emptyHintManual,
                textAlign: TextAlign.center,
                style: ls.text.caption.copyWith(color: c.textTertiary),
              ),
              SizedBox(height: ls.space.md),
              LsButton(
                label: l10n.manualConnect,
                icon: Icons.lan_outlined,
                size: LsButtonSize.small,
                onPressed: onManualConnect,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
