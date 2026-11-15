import 'app/bootstrap.dart';

/// LocalScreen entry point. `--dart-define=LS_FAKE=true` runs the demo mode;
/// the `--autostart` argument (set by the login entry) starts minimized.
Future<void> main(List<String> args) => bootstrap(args);
