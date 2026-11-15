import 'package:dbus/dbus.dart';

import '../../media/captured_screen.dart';
import 'mutter_display_config.dart';
import 'mutter_screen_cast.dart';
import 'pipewire_capture.dart';

/// Mirrors one of the existing monitors on GNOME by recording it through
/// Mutter directly: the app shows its own picker (only when there is more
/// than one monitor) instead of the portal's dialog.
class MutterMonitorCapture implements DirectScreenCapture {
  /// Creates the capturer.
  const MutterMonitorCapture();

  @override
  Future<CapturedScreen?> open({required int frameRate, required ScreenChooser chooser}) async {
    final client = DBusClient.session();
    try {
      if (!await MutterScreenCast.available(client) || !await PipeWireCapture.supported()) {
        throw UnsupportedError('direct capture needs GNOME and the GStreamer PipeWire plugin');
      }
      final layout = await MutterDisplayConfig(client).current();
      final options = [
        for (final m in layout.monitors)
          if (m.modeId != null && layout.logicalFor(m.connector) != null)
            ScreenOption(
              id: m.connector,
              title: m.displayName,
              detail: '${m.width} × ${m.height} · ${m.connector}',
            ),
      ];
      if (options.isEmpty) throw StateError('no monitor to capture');
      final choice = options.length == 1 ? options.first : await chooser(options);
      if (choice == null) {
        await client.close();
        return null;
      }
      final cast = await MutterScreenCast.monitor(client, choice.id);
      try {
        return await PipeWireCapture.start(
          node: cast.node,
          frameRate: frameRate,
          onClose: () async {
            await cast.stop();
            await client.close();
          },
        );
      } catch (_) {
        await cast.stop();
        rethrow;
      }
    } catch (_) {
      await client.close();
      rethrow;
    }
  }
}
