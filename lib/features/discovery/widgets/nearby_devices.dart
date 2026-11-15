import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../../app/l10n.dart';
import '../../../app/theme/lumen.dart';
import '../../../core/node/device_labels.dart';
import '../../../core/node/node_service.dart';

/// Section header: "附近的设备 · 3 台" with an optional trailing action.
class NearbyHeader extends StatelessWidget {
  /// Creates the header.
  const NearbyHeader({
    super.key,
    required this.count,
    this.large = false,
    this.trailing,
    this.showSubtitle = false,
  });

  final int count;
  final bool large;
  final Widget? trailing;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.homeNearbyTitle,
              style: (large ? ls.text.title : ls.text.headline).copyWith(color: c.textPrimary),
            ),
            if (count > 0) ...[
              SizedBox(width: ls.space.md),
              Container(
                padding: EdgeInsets.symmetric(horizontal: ls.space.sm, vertical: ls.space.xs / 2),
                decoration: BoxDecoration(
                  color: c.textPrimary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(ls.radius.full),
                ),
                child: Text(
                  l10n.homeNearbyCount(count),
                  style: ls.text.stat.copyWith(color: c.textSecondary),
                ),
              ),
            ],
            const Spacer(),
            ?trailing,
          ],
        ),
        if (showSubtitle) ...[
          SizedBox(height: ls.space.sm),
          Text(l10n.homeNearbySubtitle, style: ls.text.body.copyWith(color: c.textSecondary)),
        ],
      ],
    );
  }
}

/// A [LsDeviceTile] for a discovered peer.
class PeerTile extends StatelessWidget {
  /// Creates a tile; tapping it opens the connect sheet.
  const PeerTile({super.key, required this.peer, required this.onTap});

  final DeviceInfo peer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LsDeviceTile(
      icon: deviceKindIcon(peer.kind),
      name: peer.name,
      details: deviceDetails(peer),
      onTap: onTap,
      trailing: peer.trusted
          ? LsTrustedMark(label: l10n.trusted, icon: Icons.verified_user_rounded)
          : null,
    );
  }
}

/// Peers as a responsive grid (one column on compact) with staggered entrance.
class NearbyGrid extends StatelessWidget {
  /// Creates the grid.
  const NearbyGrid({super.key, required this.peers, required this.onSelect, this.columns = 1});

  final List<DeviceInfo> peers;
  final ValueChanged<DeviceInfo> onSelect;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    return LayoutBuilder(
      builder: (context, box) {
        final gap = ls.space.md;
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (i, peer) in peers.indexed)
              SizedBox(
                key: ValueKey(peer.id),
                width: width,
                child: LsEntrance(
                  index: i,
                  child: PeerTile(peer: peer, onTap: () => onSelect(peer)),
                ),
              ),
          ],
        );
      },
    );
  }
}
