import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:localscreen/app/app.dart';
import 'package:localscreen/core/media/fake_media_session.dart';
import 'package:localscreen/core/media/media_providers.dart';
import 'package:localscreen/core/node/fake_node_service.dart';
import 'package:localscreen/core/node/local_node.dart';
import 'package:localscreen/core/platform/autostart.dart';
import 'package:localscreen/core/platform/device_profile.dart';
import 'package:localscreen/core/prefs/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Boots the real app shell on a real device / desktop with the simulated
/// network, so platform plugins (window, prefs, fonts) are exercised.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app starts and lists simulated peers', (tester) async {
    SharedPreferences.setMockInitialValues({'ls.locale': 'zh'});
    final prefs = await SharedPreferences.getInstance();
    final profile = await DeviceProfile.detect();
    final node = FakeNodeService(discoveryInterval: const Duration(milliseconds: 100));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceProfileProvider.overrideWithValue(profile),
          nodeServiceProvider.overrideWithValue(node),
          mediaEngineProvider.overrideWithValue(const FakeMediaEngine()),
          autostartServiceProvider.overrideWithValue(InMemoryAutostartService()),
        ],
        child: const LocalScreenApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(profile.defaultName), findsWidgets);
    for (final p in FakeNodeService.demoPeers) {
      expect(find.text(p.name), findsOneWidget);
    }
    await node.dispose();
  });
}
