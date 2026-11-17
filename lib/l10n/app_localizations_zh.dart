// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'LocalScreen';

  @override
  String get cancel => '取消';

  @override
  String get close => '关闭';

  @override
  String get retry => '重试';

  @override
  String get save => '保存';

  @override
  String get back => '返回';

  @override
  String get settings => '设置';

  @override
  String get trusted => '已信任';

  @override
  String get accept => '接受';

  @override
  String get decline => '拒绝';

  @override
  String get thisDevice => '这台设备';

  @override
  String get localDiscoverable => '可被发现';

  @override
  String get localHidden => '已隐藏';

  @override
  String get localStarting => '正在启动…';

  @override
  String get localFailed => '本机服务未能启动';

  @override
  String get localFailedHint => '请重启 LocalScreen。如果问题仍在，检查防火墙是否允许局域网访问。';

  @override
  String get discoverableToggle => '允许附近设备发现';

  @override
  String get homeNearbyTitle => '附近的设备';

  @override
  String get homeNearbySubtitle => '同一网络中打开 LocalScreen 的设备会出现在这里。点一下，它就成为你的副屏。';

  @override
  String homeNearbyCount(int count) {
    return '$count 台';
  }

  @override
  String get manualConnect => '手动输入 IP';

  @override
  String get emptySearching => '正在寻找附近的设备…';

  @override
  String get emptyHintSameWifi => '确保两台设备连接到同一个 Wi-Fi，并都打开了 LocalScreen。';

  @override
  String get emptyHintManual => '还是找不到？试试手动输入对方的 IP。';

  @override
  String get manualTitle => '手动连接';

  @override
  String get manualSubtitle => '适用于屏蔽了设备发现的网络。输入对方设置页里显示的地址。';

  @override
  String get manualHint => '例如 192.168.1.42';

  @override
  String get manualConnectAction => '连接';

  @override
  String get manualFailed => '这个地址上没有找到 LocalScreen。请检查地址，并确认对方已打开应用。';

  @override
  String get connectModeLabel => '投屏方式';

  @override
  String get modeExtend => '扩展';

  @override
  String get modeMirror => '镜像';

  @override
  String get modeExtendDescription => '把副屏当作一块新的显示器，延伸你的桌面。';

  @override
  String get modeMirrorDescription => '副屏显示与这台设备相同的画面。';

  @override
  String get modeExtendUnavailable => '这台设备暂时无法创建虚拟显示器，本次将以镜像方式投屏。';

  @override
  String get comingSoon => '暂不可用';

  @override
  String get connectQualityLabel => '画质';

  @override
  String get qualitySmooth => '流畅';

  @override
  String get qualityBalanced => '均衡';

  @override
  String get qualityClear => '清晰';

  @override
  String get qualitySmoothDescription => '720p · 60 帧 · 网络一般时更稳';

  @override
  String get qualityBalancedDescription => '1080p · 60 帧 · 推荐';

  @override
  String get qualityClearDescription => '原始分辨率 · 30 帧 · 文字最锐利';

  @override
  String get startCasting => '开始投屏';

  @override
  String waitingForPeer(String name) {
    return '等待 $name 回应…';
  }

  @override
  String get pinTitle => '输入 PIN';

  @override
  String pinPrompt(String name) {
    return '输入 $name 上显示的 6 位数字。';
  }

  @override
  String pinWrong(int attempts) {
    return 'PIN 不正确，还可以再试 $attempts 次。';
  }

  @override
  String get pinVerifying => '正在验证…';

  @override
  String get pinInputLabel => '6 位 PIN';

  @override
  String failDeclined(String name) {
    return '$name 拒绝了请求。';
  }

  @override
  String failTimeout(String name) {
    return '$name 没有回应。请在那台设备上打开 LocalScreen 后重试。';
  }

  @override
  String get failPin => 'PIN 错误次数过多。请重新发起连接，获取新的 PIN。';

  @override
  String get failNetwork => '连接已断开。请确认两台设备在同一网络。';

  @override
  String get failRequest => '无法发起连接。请确认对方仍在线后重试。';

  @override
  String incomingWants(String name) {
    return '$name 想把这台设备用作副屏';
  }

  @override
  String incomingPinHint(String name) {
    return '在 $name 上输入这个 PIN';
  }

  @override
  String get incomingPinValidity => '60 秒内有效，仅限本次配对。';

  @override
  String get incomingTrustedHint => '这是受信任的设备，无需 PIN。';

  @override
  String get sessionConnecting => '正在连接…';

  @override
  String get sessionWaitingPicture => '正在等待画面…';

  @override
  String get fitContain => '完整显示';

  @override
  String get fitCover => '铺满屏幕';

  @override
  String get disconnect => '断开';

  @override
  String get statLatency => '延迟';

  @override
  String get hostCastingTo => '正在投屏到';

  @override
  String get hostSelectingSource => '请在系统对话框中选择要共享的屏幕。';

  @override
  String get hostSelectingVirtualDisplay => '已新增一块虚拟显示器。请在系统对话框中选中它（新出现的那一块）并共享。';

  @override
  String get hostPreparingDisplay => '正在创建虚拟显示器…';

  @override
  String get noticeExtendFallback => '未能创建虚拟显示器，已改为镜像投屏。';

  @override
  String get hostConnecting => '正在建立连接…';

  @override
  String get hostLive => '投屏中';

  @override
  String get hostElapsed => '时长';

  @override
  String get stopCasting => '停止投屏';

  @override
  String get screenPickerTitle => '选择要共享的屏幕';

  @override
  String screenPickerScreen(int index) {
    return '屏幕 $index';
  }

  @override
  String get captureNotificationText => '正在共享这台设备的屏幕';

  @override
  String noticeEndedRemote(String name) {
    return '$name 结束了投屏。';
  }

  @override
  String get noticeEndedLocal => '投屏已结束。';

  @override
  String get noticeCaptureFailed => '未能开始屏幕采集。请重试，并在系统对话框中选择一个屏幕。';

  @override
  String noticeAutoAccepted(String name) {
    return '已自动接受来自 $name 的投屏。';
  }

  @override
  String noticeRequestExpired(String name) {
    return '来自 $name 的请求已过期。';
  }

  @override
  String noticeBusy(String name) {
    return '已拒绝 $name：当前正在投屏。';
  }

  @override
  String noticeForgot(String name) {
    return '已移除 $name，下次连接需要重新输入 PIN。';
  }

  @override
  String get sectionDevice => '本机';

  @override
  String get deviceName => '设备名称';

  @override
  String get deviceNameDescription => '附近的设备会看到这个名字。';

  @override
  String get useDefaultName => '恢复默认';

  @override
  String get discoverable => '可被发现';

  @override
  String get discoverableDescription => '关闭后，附近的设备看不到这台设备，但你仍可以投屏到别人。';

  @override
  String get localAddress => '本机地址';

  @override
  String get sectionConnection => '连接';

  @override
  String get defaultMode => '默认投屏方式';

  @override
  String get defaultQuality => '默认画质';

  @override
  String get autoAccept => '自动接受受信任设备';

  @override
  String get autoAcceptDescription => '受信任的主机发起投屏时直接开始，不再询问。';

  @override
  String get sectionTrusted => '受信任设备';

  @override
  String get trustedEmpty => '还没有受信任的设备。第一次用 PIN 配对成功后，设备会出现在这里。';

  @override
  String get forget => '移除';

  @override
  String forgetTitle(String name) {
    return '移除 $name？';
  }

  @override
  String get forgetBody => '移除后，它下次连接需要重新输入 PIN。';

  @override
  String get sectionAppearance => '外观';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get sectionAbout => '关于';

  @override
  String get aboutVersion => '版本';

  @override
  String get aboutPrivacy => '投屏全程只走局域网：无账号、无云端、无广告。';

  @override
  String get aboutDeviceId => '设备 ID';

  @override
  String get launchAtStartup => '开机自启';

  @override
  String get launchAtStartupDescription => '登录系统后自动启动，在后台等待连接。';

  @override
  String get sessionWaitingHint => '对方电脑还在准备画面。如果那边弹出了选择屏幕的窗口，请在那里选好要共享的屏幕。';

  @override
  String get aboutLogs => '诊断日志';

  @override
  String get aboutLogsDescription => '只保存在本机，遇到问题时可以发给开发者。';

  @override
  String get aboutLogsOpen => '打开文件夹';

  @override
  String get sectionUpdates => '更新';

  @override
  String get autoCheckUpdates => '自动检查更新';

  @override
  String get autoCheckUpdatesDescription => '启动后及每小时向 GitHub 查询一次新版本，不发送任何设备信息。';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get checkNow => '立即检查';

  @override
  String get updateStatusNever => '尚未检查';

  @override
  String get updateStatusChecking => '正在检查…';

  @override
  String updateStatusUpToDate(String time) {
    return '已是最新版本 · $time 检查';
  }

  @override
  String updateStatusAvailable(String version) {
    return '发现新版本 $version';
  }

  @override
  String get updateStatusFailed => '检查失败，请确认网络后重试。';

  @override
  String updateBannerTitle(String version) {
    return '新版本 $version 可用';
  }

  @override
  String updateBannerSubtitle(String current) {
    return '当前 $current';
  }

  @override
  String get updateAction => '更新';

  @override
  String get updateLater => '忽略此版本';

  @override
  String updateDownloading(int percent) {
    return '正在下载 $percent%';
  }

  @override
  String get updateInstalling => '正在安装…';

  @override
  String updateInstalledTitle(String version) {
    return '$version 已安装';
  }

  @override
  String get updateInstalledSubtitle => '重启 LocalScreen 即可使用新版本。';

  @override
  String get updateRestart => '重启';

  @override
  String get updateOpenedTitle => '请在安装程序中完成更新';

  @override
  String get updateOpenedSubtitleMac => '把 LocalScreen 拖入\"应用程序\"替换旧版，然后重新打开。';

  @override
  String updateSheetMeta(String current, String date) {
    return '当前 $current · 发布于 $date';
  }

  @override
  String get updateWhatsNew => '更新内容';

  @override
  String updateInstallButton(String size) {
    return '下载并安装 · $size';
  }

  @override
  String get updateOpenPage => '前往下载页';

  @override
  String get updateViewRelease => '查看完整说明';

  @override
  String get updateHintLinux => '安装时会请你输入系统密码。';

  @override
  String get updateHintWindows => '安装程序会先关闭 LocalScreen，完成后自动重新打开。';

  @override
  String get updateHintMac => '下载后会打开磁盘映像，把 LocalScreen 拖入\"应用程序\"即可。';

  @override
  String get updateHintManual => '这台设备上的 LocalScreen 不能自行安装更新，请从下载页获取新版本。';

  @override
  String get updateHintSession => '投屏进行中，结束后再更新。';

  @override
  String get updateFailedNetwork => '下载失败，请确认网络后重试。';

  @override
  String get updateFailedChecksum => '下载的文件没有通过校验，已丢弃。';

  @override
  String get updateFailedInstall => '安装没有完成，请重试或从下载页手动安装。';

  @override
  String get updateFailedNoPackage => '这个版本没有适用于本机的安装包。';

  @override
  String get windowMinimize => '最小化';

  @override
  String get windowMaximize => '最大化';

  @override
  String get windowRestore => '还原';

  @override
  String get windowClose => '关闭';
}
