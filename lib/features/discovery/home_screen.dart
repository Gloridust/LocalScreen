import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n.dart';
import '../../app/router.dart';
import '../../app/theme/lumen.dart';
import '../../core/node/local_node.dart';
import '../../core/node/node_service.dart';
import '../pairing/connect_sheet.dart';
import '../pairing/outgoing_request.dart';
import '../settings/settings_screen.dart';
import '../update/update_banner.dart';
import 'manual_connect_sheet.dart';
import 'peers_controller.dart';
import 'widgets/discovery_empty_state.dart';
import 'widgets/local_device.dart';
import 'widgets/nearby_devices.dart';

/// Home: "who is nearby". Compact stacks the local header above the list;
/// expanded puts the 360-wide local panel beside a device grid.
class HomeScreen extends ConsumerWidget {
  /// Creates the home screen.
  const HomeScreen({super.key});

  static Future<void> _openConnect(BuildContext context, WidgetRef ref, DeviceInfo peer) async {
    final notifier = ref.read(outgoingRequestProvider.notifier);
    notifier.open(peer);
    await showLsSheet<void>(context, builder: (_) => const ConnectSheet());
    await notifier.dismiss();
  }

  static Future<void> _openManual(BuildContext context, WidgetRef ref) async {
    final peer = await showLsSheet<DeviceInfo>(context, builder: (_) => const ManualConnectSheet());
    if (peer != null && context.mounted) await _openConnect(context, ref, peer);
  }

  static void _openSettings(BuildContext context) {
    Navigator.of(context).push(LsPageRoute.of<void>(context, (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final peers = ref.watch(peersProvider);
    final running = ref.watch(localNodeProvider) is LocalNodeRunning;
    void select(DeviceInfo p) => _openConnect(context, ref, p);
    final onManual = running ? () => _openManual(context, ref) : null;
    return Scaffold(
      backgroundColor: ls.colors.bg,
      body: SafeArea(
        child: context.windowClass == LsWindowClass.expanded
            ? _ExpandedHome(
                peers: peers,
                onSelect: select,
                onManualConnect: onManual,
                onOpenSettings: () => _openSettings(context),
              )
            : _CompactHome(
                peers: peers,
                onSelect: select,
                onManualConnect: onManual,
                onOpenSettings: () => _openSettings(context),
              ),
      ),
    );
  }
}

int _columnsFor(double width, LsTokens ls) {
  final gap = ls.space.md;
  return math.max(1, ((width + gap) / (ls.size.gridTileMaxExtent + gap)).ceil());
}

class _ExpandedHome extends StatelessWidget {
  const _ExpandedHome({
    required this.peers,
    required this.onSelect,
    required this.onManualConnect,
    required this.onOpenSettings,
  });

  final List<DeviceInfo> peers;
  final ValueChanged<DeviceInfo> onSelect;
  final VoidCallback? onManualConnect;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: ls.size.contentMaxWidth + ls.space.xl * 2),
        child: Padding(
          padding: EdgeInsets.all(ls.space.xl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: ls.size.sidePanelWidth,
                child: LocalDevicePanel(
                  onManualConnect: onManualConnect ?? () {},
                  onOpenSettings: onOpenSettings,
                ),
              ),
              SizedBox(width: ls.space.xxl),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: ls.space.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      UpdateBanner(padding: EdgeInsets.only(bottom: ls.space.xl)),
                      NearbyHeader(count: peers.length, large: true, showSubtitle: true),
                      SizedBox(height: ls.space.xl),
                      Expanded(
                        child: peers.isEmpty
                            ? Padding(
                                padding: EdgeInsets.only(bottom: ls.space.xxxl),
                                child: DiscoveryEmptyState(onManualConnect: onManualConnect),
                              )
                            : LayoutBuilder(
                                builder: (context, box) => SingleChildScrollView(
                                  padding: EdgeInsets.only(bottom: ls.space.xl),
                                  child: NearbyGrid(
                                    peers: peers,
                                    onSelect: onSelect,
                                    columns: _columnsFor(box.maxWidth, ls),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactHome extends StatelessWidget {
  const _CompactHome({
    required this.peers,
    required this.onSelect,
    required this.onManualConnect,
    required this.onOpenSettings,
  });

  final List<DeviceInfo> peers;
  final ValueChanged<DeviceInfo> onSelect;
  final VoidCallback? onManualConnect;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final side = math.max(ls.space.lg + ls.space.xs, (width - ls.size.readableMaxWidth) / 2);
    final columns = context.windowClass == LsWindowClass.medium ? 2 : 1;
    EdgeInsets pad({double top = 0, double bottom = 0}) =>
        EdgeInsets.fromLTRB(side, top, side, bottom);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: pad(top: ls.space.md),
          sliver: SliverToBoxAdapter(child: HomeTopBar(onOpenSettings: onOpenSettings)),
        ),
        SliverPadding(
          padding: pad(top: ls.space.sm, bottom: ls.space.xl),
          sliver: const SliverToBoxAdapter(child: LocalDeviceHeader()),
        ),
        SliverPadding(
          padding: pad(),
          sliver: SliverToBoxAdapter(
            child: UpdateBanner(padding: EdgeInsets.only(bottom: ls.space.xl)),
          ),
        ),
        SliverPadding(
          padding: pad(bottom: ls.space.lg),
          sliver: SliverToBoxAdapter(
            child: NearbyHeader(
              count: peers.length,
              trailing: peers.isEmpty || onManualConnect == null
                  ? null
                  : LsIconButton(
                      icon: Icons.add_link_rounded,
                      semanticLabel: l10n.manualConnect,
                      onPressed: onManualConnect,
                    ),
            ),
          ),
        ),
        if (peers.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: pad(bottom: ls.space.xxl),
              child: DiscoveryEmptyState(onManualConnect: onManualConnect),
            ),
          )
        else
          SliverPadding(
            padding: pad(bottom: ls.space.xxl),
            sliver: SliverToBoxAdapter(
              child: NearbyGrid(peers: peers, onSelect: onSelect, columns: columns),
            ),
          ),
      ],
    );
  }
}
