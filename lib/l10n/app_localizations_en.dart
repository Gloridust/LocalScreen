// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LocalScreen';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Try again';

  @override
  String get save => 'Save';

  @override
  String get back => 'Back';

  @override
  String get settings => 'Settings';

  @override
  String get trusted => 'Trusted';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get thisDevice => 'This device';

  @override
  String get localDiscoverable => 'Discoverable';

  @override
  String get localHidden => 'Hidden';

  @override
  String get localStarting => 'Starting…';

  @override
  String get localFailed => 'Couldn\'t start';

  @override
  String get localFailedHint =>
      'Restart LocalScreen. If it keeps happening, check that your firewall allows local network access.';

  @override
  String get discoverableToggle => 'Visible to nearby devices';

  @override
  String get homeNearbyTitle => 'Nearby devices';

  @override
  String get homeNearbySubtitle =>
      'Devices on this network running LocalScreen show up here. Tap one to use it as a second screen.';

  @override
  String homeNearbyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices',
      one: '1 device',
    );
    return '$_temp0';
  }

  @override
  String get manualConnect => 'Enter IP address';

  @override
  String get emptySearching => 'Looking for nearby devices…';

  @override
  String get emptyHintSameWifi =>
      'Make sure both devices are on the same Wi-Fi and have LocalScreen open.';

  @override
  String get emptyHintManual => 'Still not there? Try entering its IP address.';

  @override
  String get manualTitle => 'Connect by IP';

  @override
  String get manualSubtitle =>
      'For networks that block discovery. Enter the address shown in the other device\'s settings.';

  @override
  String get manualHint => 'e.g. 192.168.1.42';

  @override
  String get manualConnectAction => 'Connect';

  @override
  String get manualFailed =>
      'No LocalScreen found at that address. Check it and make sure the app is open there.';

  @override
  String get connectModeLabel => 'Mode';

  @override
  String get modeExtend => 'Extend';

  @override
  String get modeMirror => 'Mirror';

  @override
  String get modeExtendDescription => 'Use it as an extra monitor that extends your desktop.';

  @override
  String get modeMirrorDescription => 'Shows the same picture as this device.';

  @override
  String get modeExtendUnavailable =>
      'This device can\'t create a virtual display yet. Your screen will be mirrored instead.';

  @override
  String get comingSoon => 'Unavailable';

  @override
  String get connectQualityLabel => 'Quality';

  @override
  String get qualitySmooth => 'Smooth';

  @override
  String get qualityBalanced => 'Balanced';

  @override
  String get qualityClear => 'Sharp';

  @override
  String get qualitySmoothDescription => '720p · 60 fps · steadier on busy Wi-Fi';

  @override
  String get qualityBalancedDescription => '1080p · 60 fps · recommended';

  @override
  String get qualityClearDescription => 'Native resolution · 30 fps · crispest text';

  @override
  String get startCasting => 'Start casting';

  @override
  String waitingForPeer(String name) {
    return 'Waiting for $name…';
  }

  @override
  String get pinTitle => 'Enter PIN';

  @override
  String pinPrompt(String name) {
    return 'Enter the 6-digit code shown on $name.';
  }

  @override
  String pinWrong(int attempts) {
    String _temp0 = intl.Intl.pluralLogic(
      attempts,
      locale: localeName,
      other: 'Wrong PIN. $attempts attempts left.',
      one: 'Wrong PIN. 1 attempt left.',
    );
    return '$_temp0';
  }

  @override
  String get pinVerifying => 'Verifying…';

  @override
  String get pinInputLabel => '6-digit PIN';

  @override
  String failDeclined(String name) {
    return '$name declined the request.';
  }

  @override
  String failTimeout(String name) {
    return '$name didn\'t respond. Open LocalScreen on it and try again.';
  }

  @override
  String get failPin => 'Too many wrong PINs. Start again to get a new code.';

  @override
  String get failNetwork =>
      'The connection dropped. Make sure both devices are on the same network.';

  @override
  String get failRequest =>
      'Couldn\'t send the request. Check that the device is still online and try again.';

  @override
  String incomingWants(String name) {
    return '$name wants to use this device as a screen';
  }

  @override
  String incomingPinHint(String name) {
    return 'Enter this PIN on $name';
  }

  @override
  String get incomingPinValidity => 'Valid for 60 seconds, for this pairing only.';

  @override
  String get incomingTrustedHint => 'Trusted device, no PIN needed.';

  @override
  String get sessionConnecting => 'Connecting…';

  @override
  String get sessionWaitingPicture => 'Waiting for the picture…';

  @override
  String get fitContain => 'Fit';

  @override
  String get fitCover => 'Fill';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get statLatency => 'Latency';

  @override
  String get hostCastingTo => 'Casting to';

  @override
  String get hostSelectingSource => 'Choose the screen to share in the system dialog.';

  @override
  String get hostSelectingVirtualDisplay =>
      'A virtual display was added. Pick it (the new one) in the system dialog and share.';

  @override
  String get hostPreparingDisplay => 'Creating the virtual display…';

  @override
  String get noticeExtendFallback => 'Couldn\'t create a virtual display. Mirroring instead.';

  @override
  String get hostConnecting => 'Connecting…';

  @override
  String get hostLive => 'Live';

  @override
  String get hostElapsed => 'Duration';

  @override
  String get stopCasting => 'Stop casting';

  @override
  String get screenPickerTitle => 'Choose a screen to share';

  @override
  String screenPickerScreen(int index) {
    return 'Screen $index';
  }

  @override
  String get captureNotificationText => 'Sharing this device\'s screen';

  @override
  String noticeEndedRemote(String name) {
    return '$name ended the session.';
  }

  @override
  String get noticeEndedLocal => 'Casting ended.';

  @override
  String get noticeCaptureFailed =>
      'Couldn\'t start screen capture. Try again and pick a screen in the system dialog.';

  @override
  String noticeAutoAccepted(String name) {
    return 'Accepted $name automatically.';
  }

  @override
  String noticeRequestExpired(String name) {
    return 'The request from $name expired.';
  }

  @override
  String noticeBusy(String name) {
    return 'Declined $name: a session is already running.';
  }

  @override
  String noticeForgot(String name) {
    return 'Removed $name. It will need a PIN next time.';
  }

  @override
  String get sectionDevice => 'This device';

  @override
  String get deviceName => 'Device name';

  @override
  String get deviceNameDescription => 'Nearby devices see this name.';

  @override
  String get useDefaultName => 'Use default';

  @override
  String get discoverable => 'Discoverable';

  @override
  String get discoverableDescription =>
      'When off, others can\'t see this device, but you can still cast to them.';

  @override
  String get localAddress => 'Address';

  @override
  String get sectionConnection => 'Connection';

  @override
  String get defaultMode => 'Default mode';

  @override
  String get defaultQuality => 'Default quality';

  @override
  String get autoAccept => 'Auto-accept trusted devices';

  @override
  String get autoAcceptDescription => 'Trusted hosts start casting without asking.';

  @override
  String get sectionTrusted => 'Trusted devices';

  @override
  String get trustedEmpty =>
      'No trusted devices yet. They appear here after the first successful PIN pairing.';

  @override
  String get forget => 'Remove';

  @override
  String forgetTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get forgetBody => 'It will need a PIN the next time it connects.';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get sectionAbout => 'About';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutPrivacy => 'Local network only: no accounts, no cloud, no ads.';

  @override
  String get aboutDeviceId => 'Device ID';

  @override
  String get launchAtStartup => 'Launch at startup';

  @override
  String get launchAtStartupDescription =>
      'Start when you sign in and wait for connections in the background.';

  @override
  String get sessionWaitingHint =>
      'The other computer is still preparing the picture. If it shows a screen picker, choose the screen to share there.';

  @override
  String get aboutLogs => 'Diagnostic logs';

  @override
  String get aboutLogsDescription =>
      'Kept on this device only. Send them along when reporting a problem.';

  @override
  String get aboutLogsOpen => 'Open folder';
}
