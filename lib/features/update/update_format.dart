import 'package:intl/intl.dart';

import '../../app/l10n.dart';
import '../../core/update/release.dart';
import '../../core/update/update_controller.dart';
import '../../core/update/update_installer.dart';
import '../../core/update/update_source.dart';

/// `15.2 MB`-style size.
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  return unit == 0 ? '$bytes B' : '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[unit]}';
}

/// What went wrong, in words.
String updateFailureText(AppLocalizations l10n, UpdateFailure failure) => switch (failure) {
  UpdateFailure.network => l10n.updateFailedNetwork,
  UpdateFailure.checksum => l10n.updateFailedChecksum,
  UpdateFailure.install => l10n.updateFailedInstall,
  UpdateFailure.noPackage => l10n.updateFailedNoPackage,
};

/// One line describing [state], for the settings row.
String updateStatusText(AppLocalizations l10n, UpdateState state) => switch (state) {
  UpdateIdle() => l10n.updateStatusNever,
  UpdateChecking() => l10n.updateStatusChecking,
  UpdateUpToDate(:final checkedAt) => l10n.updateStatusUpToDate(
    DateFormat.Hm(l10n.localeName).format(checkedAt),
  ),
  UpdateAvailable(:final release) => l10n.updateStatusAvailable('${release.version}'),
  UpdateDownloading(:final fraction) => l10n.updateDownloading(((fraction ?? 0) * 100).round()),
  UpdateInstalling() => l10n.updateInstalling,
  UpdateInstalled(:final release) => l10n.updateInstalledTitle('${release.version}'),
  UpdateOpened() => l10n.updateOpenedTitle,
  UpdateFailed(release: null) => l10n.updateStatusFailed,
  UpdateFailed(:final failure) => updateFailureText(l10n, failure),
};

/// What installing involves on this platform.
String installHint(AppLocalizations l10n, UpdateInstaller installer) {
  if (!installer.canInstall) return l10n.updateHintManual;
  return switch (installer.package) {
    UpdatePackage.deb => l10n.updateHintLinux,
    UpdatePackage.windowsSetup => l10n.updateHintWindows,
    UpdatePackage.dmg => l10n.updateHintMac,
    UpdatePackage.apk || null => l10n.updateHintManual,
  };
}
