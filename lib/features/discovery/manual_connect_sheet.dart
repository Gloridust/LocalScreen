import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n.dart';
import '../../app/theme/lumen.dart';
import 'peers_controller.dart';

/// Sheet for connecting by IP when multicast discovery is blocked.
/// Pops with the probed device on success.
class ManualConnectSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const ManualConnectSheet({super.key});

  @override
  ConsumerState<ManualConnectSheet> createState() => _ManualConnectSheetState();
}

class _ManualConnectSheetState extends ConsumerState<ManualConnectSheet> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final address = _controller.text.trim();
    if (address.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final peer = await ref.read(peersProvider.notifier).connectManual(address);
      if (mounted) Navigator.of(context).pop(peer);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.manualTitle, style: ls.text.headline.copyWith(color: c.textPrimary)),
        SizedBox(height: ls.space.sm),
        Text(l10n.manualSubtitle, style: ls.text.body.copyWith(color: c.textSecondary)),
        SizedBox(height: ls.space.xl),
        LsTextField(
          controller: _controller,
          autofocus: true,
          hint: l10n.manualHint,
          leadingIcon: Icons.lan_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F.:\[\]]'))],
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _connect(),
          onChanged: (_) {
            if (_failed) setState(() => _failed = false);
          },
          errorText: _failed ? l10n.manualFailed : null,
        ),
        SizedBox(height: ls.space.xl),
        Row(
          children: [
            Expanded(
              child: LsButton(
                label: l10n.cancel,
                expand: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(width: ls.space.md),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => LsButton.primary(
                  label: l10n.manualConnectAction,
                  expand: true,
                  loading: _busy,
                  onPressed: _controller.text.trim().isEmpty ? null : _connect,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
