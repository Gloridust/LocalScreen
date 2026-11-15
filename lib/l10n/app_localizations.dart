import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('zh')];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'LocalScreen'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @trusted.
  ///
  /// In zh, this message translates to:
  /// **'已信任'**
  String get trusted;

  /// No description provided for @accept.
  ///
  /// In zh, this message translates to:
  /// **'接受'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In zh, this message translates to:
  /// **'拒绝'**
  String get decline;

  /// No description provided for @thisDevice.
  ///
  /// In zh, this message translates to:
  /// **'这台设备'**
  String get thisDevice;

  /// No description provided for @localDiscoverable.
  ///
  /// In zh, this message translates to:
  /// **'可被发现'**
  String get localDiscoverable;

  /// No description provided for @localHidden.
  ///
  /// In zh, this message translates to:
  /// **'已隐藏'**
  String get localHidden;

  /// No description provided for @localStarting.
  ///
  /// In zh, this message translates to:
  /// **'正在启动…'**
  String get localStarting;

  /// No description provided for @localFailed.
  ///
  /// In zh, this message translates to:
  /// **'本机服务未能启动'**
  String get localFailed;

  /// No description provided for @localFailedHint.
  ///
  /// In zh, this message translates to:
  /// **'请重启 LocalScreen。如果问题仍在，检查防火墙是否允许局域网访问。'**
  String get localFailedHint;

  /// No description provided for @discoverableToggle.
  ///
  /// In zh, this message translates to:
  /// **'允许附近设备发现'**
  String get discoverableToggle;

  /// No description provided for @homeNearbyTitle.
  ///
  /// In zh, this message translates to:
  /// **'附近的设备'**
  String get homeNearbyTitle;

  /// No description provided for @homeNearbySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'同一网络中打开 LocalScreen 的设备会出现在这里。点一下，它就成为你的副屏。'**
  String get homeNearbySubtitle;

  /// No description provided for @homeNearbyCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 台'**
  String homeNearbyCount(int count);

  /// No description provided for @manualConnect.
  ///
  /// In zh, this message translates to:
  /// **'手动输入 IP'**
  String get manualConnect;

  /// No description provided for @emptySearching.
  ///
  /// In zh, this message translates to:
  /// **'正在寻找附近的设备…'**
  String get emptySearching;

  /// No description provided for @emptyHintSameWifi.
  ///
  /// In zh, this message translates to:
  /// **'确保两台设备连接到同一个 Wi-Fi，并都打开了 LocalScreen。'**
  String get emptyHintSameWifi;

  /// No description provided for @emptyHintManual.
  ///
  /// In zh, this message translates to:
  /// **'还是找不到？试试手动输入对方的 IP。'**
  String get emptyHintManual;

  /// No description provided for @manualTitle.
  ///
  /// In zh, this message translates to:
  /// **'手动连接'**
  String get manualTitle;

  /// No description provided for @manualSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'适用于屏蔽了设备发现的网络。输入对方设置页里显示的地址。'**
  String get manualSubtitle;

  /// No description provided for @manualHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 192.168.1.42'**
  String get manualHint;

  /// No description provided for @manualConnectAction.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get manualConnectAction;

  /// No description provided for @manualFailed.
  ///
  /// In zh, this message translates to:
  /// **'这个地址上没有找到 LocalScreen。请检查地址，并确认对方已打开应用。'**
  String get manualFailed;

  /// No description provided for @connectModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'投屏方式'**
  String get connectModeLabel;

  /// No description provided for @modeExtend.
  ///
  /// In zh, this message translates to:
  /// **'扩展'**
  String get modeExtend;

  /// No description provided for @modeMirror.
  ///
  /// In zh, this message translates to:
  /// **'镜像'**
  String get modeMirror;

  /// No description provided for @modeExtendDescription.
  ///
  /// In zh, this message translates to:
  /// **'把副屏当作一块新的显示器，延伸你的桌面。'**
  String get modeExtendDescription;

  /// No description provided for @modeMirrorDescription.
  ///
  /// In zh, this message translates to:
  /// **'副屏显示与这台设备相同的画面。'**
  String get modeMirrorDescription;

  /// No description provided for @modeExtendUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'这台设备暂时无法创建虚拟显示器，本次将以镜像方式投屏。'**
  String get modeExtendUnavailable;

  /// No description provided for @comingSoon.
  ///
  /// In zh, this message translates to:
  /// **'暂不可用'**
  String get comingSoon;

  /// No description provided for @connectQualityLabel.
  ///
  /// In zh, this message translates to:
  /// **'画质'**
  String get connectQualityLabel;

  /// No description provided for @qualitySmooth.
  ///
  /// In zh, this message translates to:
  /// **'流畅'**
  String get qualitySmooth;

  /// No description provided for @qualityBalanced.
  ///
  /// In zh, this message translates to:
  /// **'均衡'**
  String get qualityBalanced;

  /// No description provided for @qualityClear.
  ///
  /// In zh, this message translates to:
  /// **'清晰'**
  String get qualityClear;

  /// No description provided for @qualitySmoothDescription.
  ///
  /// In zh, this message translates to:
  /// **'720p · 60 帧 · 网络一般时更稳'**
  String get qualitySmoothDescription;

  /// No description provided for @qualityBalancedDescription.
  ///
  /// In zh, this message translates to:
  /// **'1080p · 60 帧 · 推荐'**
  String get qualityBalancedDescription;

  /// No description provided for @qualityClearDescription.
  ///
  /// In zh, this message translates to:
  /// **'原始分辨率 · 30 帧 · 文字最锐利'**
  String get qualityClearDescription;

  /// No description provided for @startCasting.
  ///
  /// In zh, this message translates to:
  /// **'开始投屏'**
  String get startCasting;

  /// No description provided for @waitingForPeer.
  ///
  /// In zh, this message translates to:
  /// **'等待 {name} 回应…'**
  String waitingForPeer(String name);

  /// No description provided for @pinTitle.
  ///
  /// In zh, this message translates to:
  /// **'输入 PIN'**
  String get pinTitle;

  /// No description provided for @pinPrompt.
  ///
  /// In zh, this message translates to:
  /// **'输入 {name} 上显示的 6 位数字。'**
  String pinPrompt(String name);

  /// No description provided for @pinWrong.
  ///
  /// In zh, this message translates to:
  /// **'PIN 不正确，还可以再试 {attempts} 次。'**
  String pinWrong(int attempts);

  /// No description provided for @pinVerifying.
  ///
  /// In zh, this message translates to:
  /// **'正在验证…'**
  String get pinVerifying;

  /// No description provided for @pinInputLabel.
  ///
  /// In zh, this message translates to:
  /// **'6 位 PIN'**
  String get pinInputLabel;

  /// No description provided for @failDeclined.
  ///
  /// In zh, this message translates to:
  /// **'{name} 拒绝了请求。'**
  String failDeclined(String name);

  /// No description provided for @failTimeout.
  ///
  /// In zh, this message translates to:
  /// **'{name} 没有回应。请在那台设备上打开 LocalScreen 后重试。'**
  String failTimeout(String name);

  /// No description provided for @failPin.
  ///
  /// In zh, this message translates to:
  /// **'PIN 错误次数过多。请重新发起连接，获取新的 PIN。'**
  String get failPin;

  /// No description provided for @failNetwork.
  ///
  /// In zh, this message translates to:
  /// **'连接已断开。请确认两台设备在同一网络。'**
  String get failNetwork;

  /// No description provided for @failRequest.
  ///
  /// In zh, this message translates to:
  /// **'无法发起连接。请确认对方仍在线后重试。'**
  String get failRequest;

  /// No description provided for @incomingWants.
  ///
  /// In zh, this message translates to:
  /// **'{name} 想把这台设备用作副屏'**
  String incomingWants(String name);

  /// No description provided for @incomingPinHint.
  ///
  /// In zh, this message translates to:
  /// **'在 {name} 上输入这个 PIN'**
  String incomingPinHint(String name);

  /// No description provided for @incomingPinValidity.
  ///
  /// In zh, this message translates to:
  /// **'60 秒内有效，仅限本次配对。'**
  String get incomingPinValidity;

  /// No description provided for @incomingTrustedHint.
  ///
  /// In zh, this message translates to:
  /// **'这是受信任的设备，无需 PIN。'**
  String get incomingTrustedHint;

  /// No description provided for @sessionConnecting.
  ///
  /// In zh, this message translates to:
  /// **'正在连接…'**
  String get sessionConnecting;

  /// No description provided for @sessionWaitingPicture.
  ///
  /// In zh, this message translates to:
  /// **'正在等待画面…'**
  String get sessionWaitingPicture;

  /// No description provided for @fitContain.
  ///
  /// In zh, this message translates to:
  /// **'完整显示'**
  String get fitContain;

  /// No description provided for @fitCover.
  ///
  /// In zh, this message translates to:
  /// **'铺满屏幕'**
  String get fitCover;

  /// No description provided for @disconnect.
  ///
  /// In zh, this message translates to:
  /// **'断开'**
  String get disconnect;

  /// No description provided for @statLatency.
  ///
  /// In zh, this message translates to:
  /// **'延迟'**
  String get statLatency;

  /// No description provided for @hostCastingTo.
  ///
  /// In zh, this message translates to:
  /// **'正在投屏到'**
  String get hostCastingTo;

  /// No description provided for @hostSelectingSource.
  ///
  /// In zh, this message translates to:
  /// **'请在系统对话框中选择要共享的屏幕。'**
  String get hostSelectingSource;

  /// No description provided for @hostSelectingVirtualDisplay.
  ///
  /// In zh, this message translates to:
  /// **'已新增一块虚拟显示器。请在系统对话框中选中它（新出现的那一块）并共享。'**
  String get hostSelectingVirtualDisplay;

  /// No description provided for @hostPreparingDisplay.
  ///
  /// In zh, this message translates to:
  /// **'正在创建虚拟显示器…'**
  String get hostPreparingDisplay;

  /// No description provided for @noticeExtendFallback.
  ///
  /// In zh, this message translates to:
  /// **'未能创建虚拟显示器，已改为镜像投屏。'**
  String get noticeExtendFallback;

  /// No description provided for @hostConnecting.
  ///
  /// In zh, this message translates to:
  /// **'正在建立连接…'**
  String get hostConnecting;

  /// No description provided for @hostLive.
  ///
  /// In zh, this message translates to:
  /// **'投屏中'**
  String get hostLive;

  /// No description provided for @hostElapsed.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get hostElapsed;

  /// No description provided for @stopCasting.
  ///
  /// In zh, this message translates to:
  /// **'停止投屏'**
  String get stopCasting;

  /// No description provided for @screenPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择要共享的屏幕'**
  String get screenPickerTitle;

  /// No description provided for @screenPickerScreen.
  ///
  /// In zh, this message translates to:
  /// **'屏幕 {index}'**
  String screenPickerScreen(int index);

  /// No description provided for @captureNotificationText.
  ///
  /// In zh, this message translates to:
  /// **'正在共享这台设备的屏幕'**
  String get captureNotificationText;

  /// No description provided for @noticeEndedRemote.
  ///
  /// In zh, this message translates to:
  /// **'{name} 结束了投屏。'**
  String noticeEndedRemote(String name);

  /// No description provided for @noticeEndedLocal.
  ///
  /// In zh, this message translates to:
  /// **'投屏已结束。'**
  String get noticeEndedLocal;

  /// No description provided for @noticeCaptureFailed.
  ///
  /// In zh, this message translates to:
  /// **'未能开始屏幕采集。请重试，并在系统对话框中选择一个屏幕。'**
  String get noticeCaptureFailed;

  /// No description provided for @noticeAutoAccepted.
  ///
  /// In zh, this message translates to:
  /// **'已自动接受来自 {name} 的投屏。'**
  String noticeAutoAccepted(String name);

  /// No description provided for @noticeRequestExpired.
  ///
  /// In zh, this message translates to:
  /// **'来自 {name} 的请求已过期。'**
  String noticeRequestExpired(String name);

  /// No description provided for @noticeBusy.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝 {name}：当前正在投屏。'**
  String noticeBusy(String name);

  /// No description provided for @noticeForgot.
  ///
  /// In zh, this message translates to:
  /// **'已移除 {name}，下次连接需要重新输入 PIN。'**
  String noticeForgot(String name);

  /// No description provided for @sectionDevice.
  ///
  /// In zh, this message translates to:
  /// **'本机'**
  String get sectionDevice;

  /// No description provided for @deviceName.
  ///
  /// In zh, this message translates to:
  /// **'设备名称'**
  String get deviceName;

  /// No description provided for @deviceNameDescription.
  ///
  /// In zh, this message translates to:
  /// **'附近的设备会看到这个名字。'**
  String get deviceNameDescription;

  /// No description provided for @useDefaultName.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get useDefaultName;

  /// No description provided for @discoverable.
  ///
  /// In zh, this message translates to:
  /// **'可被发现'**
  String get discoverable;

  /// No description provided for @discoverableDescription.
  ///
  /// In zh, this message translates to:
  /// **'关闭后，附近的设备看不到这台设备，但你仍可以投屏到别人。'**
  String get discoverableDescription;

  /// No description provided for @localAddress.
  ///
  /// In zh, this message translates to:
  /// **'本机地址'**
  String get localAddress;

  /// No description provided for @sectionConnection.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get sectionConnection;

  /// No description provided for @defaultMode.
  ///
  /// In zh, this message translates to:
  /// **'默认投屏方式'**
  String get defaultMode;

  /// No description provided for @defaultQuality.
  ///
  /// In zh, this message translates to:
  /// **'默认画质'**
  String get defaultQuality;

  /// No description provided for @autoAccept.
  ///
  /// In zh, this message translates to:
  /// **'自动接受受信任设备'**
  String get autoAccept;

  /// No description provided for @autoAcceptDescription.
  ///
  /// In zh, this message translates to:
  /// **'受信任的主机发起投屏时直接开始，不再询问。'**
  String get autoAcceptDescription;

  /// No description provided for @sectionTrusted.
  ///
  /// In zh, this message translates to:
  /// **'受信任设备'**
  String get sectionTrusted;

  /// No description provided for @trustedEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有受信任的设备。第一次用 PIN 配对成功后，设备会出现在这里。'**
  String get trustedEmpty;

  /// No description provided for @forget.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get forget;

  /// No description provided for @forgetTitle.
  ///
  /// In zh, this message translates to:
  /// **'移除 {name}？'**
  String forgetTitle(String name);

  /// No description provided for @forgetBody.
  ///
  /// In zh, this message translates to:
  /// **'移除后，它下次连接需要重新输入 PIN。'**
  String get forgetBody;

  /// No description provided for @sectionAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get sectionAppearance;

  /// No description provided for @theme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @sectionAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get sectionAbout;

  /// No description provided for @aboutVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get aboutVersion;

  /// No description provided for @aboutPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'投屏全程只走局域网：无账号、无云端、无广告。'**
  String get aboutPrivacy;

  /// No description provided for @aboutDeviceId.
  ///
  /// In zh, this message translates to:
  /// **'设备 ID'**
  String get aboutDeviceId;

  /// No description provided for @launchAtStartup.
  ///
  /// In zh, this message translates to:
  /// **'开机自启'**
  String get launchAtStartup;

  /// No description provided for @launchAtStartupDescription.
  ///
  /// In zh, this message translates to:
  /// **'登录系统后自动启动，在后台等待连接。'**
  String get launchAtStartupDescription;

  /// No description provided for @sessionWaitingHint.
  ///
  /// In zh, this message translates to:
  /// **'对方电脑还在准备画面。如果那边弹出了选择屏幕的窗口，请在那里选好要共享的屏幕。'**
  String get sessionWaitingHint;

  /// No description provided for @aboutLogs.
  ///
  /// In zh, this message translates to:
  /// **'诊断日志'**
  String get aboutLogs;

  /// No description provided for @aboutLogsDescription.
  ///
  /// In zh, this message translates to:
  /// **'只保存在本机，遇到问题时可以发给开发者。'**
  String get aboutLogsDescription;

  /// No description provided for @aboutLogsOpen.
  ///
  /// In zh, this message translates to:
  /// **'打开文件夹'**
  String get aboutLogsOpen;

  /// No description provided for @sectionUpdates.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get sectionUpdates;

  /// No description provided for @autoCheckUpdates.
  ///
  /// In zh, this message translates to:
  /// **'自动检查更新'**
  String get autoCheckUpdates;

  /// No description provided for @autoCheckUpdatesDescription.
  ///
  /// In zh, this message translates to:
  /// **'启动后及每小时向 GitHub 查询一次新版本，不发送任何设备信息。'**
  String get autoCheckUpdatesDescription;

  /// No description provided for @checkForUpdates.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkForUpdates;

  /// No description provided for @checkNow.
  ///
  /// In zh, this message translates to:
  /// **'立即检查'**
  String get checkNow;

  /// No description provided for @updateStatusNever.
  ///
  /// In zh, this message translates to:
  /// **'尚未检查'**
  String get updateStatusNever;

  /// No description provided for @updateStatusChecking.
  ///
  /// In zh, this message translates to:
  /// **'正在检查…'**
  String get updateStatusChecking;

  /// No description provided for @updateStatusUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本 · {time} 检查'**
  String updateStatusUpToDate(String time);

  /// No description provided for @updateStatusAvailable.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本 {version}'**
  String updateStatusAvailable(String version);

  /// No description provided for @updateStatusFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查失败，请确认网络后重试。'**
  String get updateStatusFailed;

  /// No description provided for @updateBannerTitle.
  ///
  /// In zh, this message translates to:
  /// **'新版本 {version} 可用'**
  String updateBannerTitle(String version);

  /// No description provided for @updateBannerSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前 {current}'**
  String updateBannerSubtitle(String current);

  /// No description provided for @updateAction.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get updateAction;

  /// No description provided for @updateLater.
  ///
  /// In zh, this message translates to:
  /// **'忽略此版本'**
  String get updateLater;

  /// No description provided for @updateDownloading.
  ///
  /// In zh, this message translates to:
  /// **'正在下载 {percent}%'**
  String updateDownloading(int percent);

  /// No description provided for @updateInstalling.
  ///
  /// In zh, this message translates to:
  /// **'正在安装…'**
  String get updateInstalling;

  /// No description provided for @updateInstalledTitle.
  ///
  /// In zh, this message translates to:
  /// **'{version} 已安装'**
  String updateInstalledTitle(String version);

  /// No description provided for @updateInstalledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'重启 LocalScreen 即可使用新版本。'**
  String get updateInstalledSubtitle;

  /// No description provided for @updateRestart.
  ///
  /// In zh, this message translates to:
  /// **'重启'**
  String get updateRestart;

  /// No description provided for @updateOpenedTitle.
  ///
  /// In zh, this message translates to:
  /// **'请在安装程序中完成更新'**
  String get updateOpenedTitle;

  /// No description provided for @updateOpenedSubtitleMac.
  ///
  /// In zh, this message translates to:
  /// **'把 LocalScreen 拖入\"应用程序\"替换旧版，然后重新打开。'**
  String get updateOpenedSubtitleMac;

  /// No description provided for @updateSheetMeta.
  ///
  /// In zh, this message translates to:
  /// **'当前 {current} · 发布于 {date}'**
  String updateSheetMeta(String current, String date);

  /// No description provided for @updateWhatsNew.
  ///
  /// In zh, this message translates to:
  /// **'更新内容'**
  String get updateWhatsNew;

  /// No description provided for @updateInstallButton.
  ///
  /// In zh, this message translates to:
  /// **'下载并安装 · {size}'**
  String updateInstallButton(String size);

  /// No description provided for @updateOpenPage.
  ///
  /// In zh, this message translates to:
  /// **'前往下载页'**
  String get updateOpenPage;

  /// No description provided for @updateViewRelease.
  ///
  /// In zh, this message translates to:
  /// **'查看完整说明'**
  String get updateViewRelease;

  /// No description provided for @updateHintLinux.
  ///
  /// In zh, this message translates to:
  /// **'安装时会请你输入系统密码。'**
  String get updateHintLinux;

  /// No description provided for @updateHintWindows.
  ///
  /// In zh, this message translates to:
  /// **'安装程序会先关闭 LocalScreen，完成后自动重新打开。'**
  String get updateHintWindows;

  /// No description provided for @updateHintMac.
  ///
  /// In zh, this message translates to:
  /// **'下载后会打开磁盘映像，把 LocalScreen 拖入\"应用程序\"即可。'**
  String get updateHintMac;

  /// No description provided for @updateHintManual.
  ///
  /// In zh, this message translates to:
  /// **'这台设备上的 LocalScreen 不能自行安装更新，请从下载页获取新版本。'**
  String get updateHintManual;

  /// No description provided for @updateHintSession.
  ///
  /// In zh, this message translates to:
  /// **'投屏进行中，结束后再更新。'**
  String get updateHintSession;

  /// No description provided for @updateFailedNetwork.
  ///
  /// In zh, this message translates to:
  /// **'下载失败，请确认网络后重试。'**
  String get updateFailedNetwork;

  /// No description provided for @updateFailedChecksum.
  ///
  /// In zh, this message translates to:
  /// **'下载的文件没有通过校验，已丢弃。'**
  String get updateFailedChecksum;

  /// No description provided for @updateFailedInstall.
  ///
  /// In zh, this message translates to:
  /// **'安装没有完成，请重试或从下载页手动安装。'**
  String get updateFailedInstall;

  /// No description provided for @updateFailedNoPackage.
  ///
  /// In zh, this message translates to:
  /// **'这个版本没有适用于本机的安装包。'**
  String get updateFailedNoPackage;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
