# LocalScreen 产品与技术方案

> 一句话：**像 LocalSend 传文件一样简单地，把身边任意设备变成你的副屏。**
> 打开即发现、点选即投屏；全程只走局域网，无账号、无云端、无广告。

## 1. 产品定位

| | |
|---|---|
| 目标用户 | 多设备的开发者、设计师、学生：手边有闲置平板 / 旧笔记本 / 手机，想临时多一块屏 |
| 核心场景 | 在 Ubuntu 上写代码，把小米平板、Windows 二合一平板当副屏放文档 / 终端 / 预览 |
| 差异点 | 全平台对等（任意设备既可当主机也可当副屏）；零配置发现；PIN 配对 + 端到端加密；开源 |
| 不做什么 | 远程桌面（跨公网控制）、云中继、账号体系 |

### 角色模型

每个 LocalScreen 实例都是一个对等**节点**，同时具备两种能力：

- **主机（Host）**：采集并发送自己的屏幕。
- **副屏（Display）**：接收并全屏渲染主机画面。

用户不需要预先选择角色：首页列出附近设备，**点谁，谁就成为我的副屏**；被点的一方弹出请求。

## 2. 核心流程

```
主机 (Ubuntu)                               副屏 (小米平板)
────────────                               ──────────────
打开 App，自动发现 ───── mDNS ─────────────  打开 App，自动广播
点选「小米平板」→ 选择 扩展 / 镜像
        ── 请求 ─────────────────────────▶  弹出请求卡片，显示 6 位 PIN
输入 PIN ── SPAKE2 握手 ─────────────────▶  校验通过，双方互存信任密钥
系统门户选择要共享的屏幕
        ══ WebRTC (DTLS-SRTP, 局域网直连) ═▶ 自动进入沉浸式全屏
```

再次连接同一设备：已信任，**免 PIN**，副屏端一键接受（可设为自动接受）。

## 3. 功能规划

### M1 · 可用内核（本期实现）

- 局域网自动发现（mDNS），设备卡片显示名称 / 类型 / 平台 / 信任状态
- 手动输入 IP 连接（应对隔离多播的网络）
- PIN 配对（6 位、60 秒有效、5 次失败即作废），配对后加入受信任设备
- 加密控制信道 + WebRTC 媒体，全程不出局域网
- 镜像投屏：整屏 / 窗口（由各平台系统选择器决定）
- 开机自启（桌面端）
- 副屏端沉浸式全屏、屏幕常亮、实时状态浮层（分辨率 / 帧率 / 码率 / 延迟）
- 画质预设：流畅 / 均衡 / 清晰（分辨率、帧率、码率上限联动）
- 设置：设备名、可被发现开关、受信任设备管理、主题（跟随系统 / 浅色 / 深色）
- 中英双语

### M2 · 真·扩展屏

「扩展」需要操作系统多出一块**虚拟显示器**，各平台机制不同，统一抽象为
`VirtualDisplayProvider`（`lib/core/platform/virtual_display.dart`）：

| 主机平台 | 方案 | 状态 |
|---|---|---|
| Linux · GNOME (Wayland) | Mutter ScreenCast `RecordVirtual` | **已实现**，无需驱动，GNOME 42+ |
| Linux · KDE (Wayland) | `krfb-virtualmonitor` / KWin 虚拟输出 | 待做 |
| Linux · X11 | `xrandr` 虚拟输出 + 裁剪采集 | 待做，依赖显卡驱动 |
| Windows | Indirect Display Driver (IddCx) | 待做，需随包签名驱动 |
| macOS | `CGVirtualDisplay` | 待做，私有 API，非 App Store 分发 |
| Android / iOS | 不支持作为扩展主机 | 仅镜像 |

**GNOME 上的工作方式**：会话建立后副屏上报自己的屏幕分辨率，主机据此向 Mutter 申请一块
同尺寸的虚拟显示器（由一条极简的 GStreamer 管线 `pipewiresrc ! fakesink` 充当消费者来
确定尺寸并维持其存活），随后像采集普通显示器一样采集它；会话结束即销毁。
在系统选屏对话框里需要手动选中这块新显示器——这是 Wayland 的安全模型所要求的一步。
依赖 GStreamer 的 PipeWire 插件（GNOME 桌面默认自带）。

在尚未支持的主机平台上，「扩展」降级为镜像并明确提示。

### M3 · 体验增强

- 触控 / 手写笔回传（副屏当触控板、数位板）
- 一主多副、副屏排列（左 / 右 / 上 / 下）
- USB 有线直连（ADB reverse / usbmuxd）以获得更低延迟
- 音频随屏
- 二维码配对、浏览器免安装副屏端（WebRTC 天然支持）
- 自适应码率、HEVC / AV1 硬编

## 4. 技术架构

```
┌──────────────────────── Flutter (Dart) ────────────────────────┐
│  UI  ·  状态管理 (Riverpod)  ·  设计系统                         │
│  媒体面：flutter_webrtc (libwebrtc)                              │
│     采集 getDisplayMedia → 编码 → SRTP → 解码 → 纹理渲染         │
└───────────────▲───────────────────────────────▲────────────────┘
                │ flutter_rust_bridge            │ 信令 (SDP / ICE)
┌───────────────┴──────────── Rust core ─────────┴────────────────┐
│  控制面：身份 · 发现 (mDNS) · 配对 (SPAKE2) · 加密信道 · 会话机   │
│  (后续) 低延迟采集编码管线                                       │
└─────────────────────────────────────────────────────────────────┘
```

### 为什么这样分层

- **媒体面用 libwebrtc（flutter_webrtc）**：一次性获得全平台硬件编解码、拥塞控制、
  抖动缓冲与纹理渲染。已验证其 Linux 预编译库内置 PipeWire 采集，Wayland 可用。
  局域网下只收集 host 候选，不配置 STUN / TURN，流量不出内网。
- **控制面用 Rust**：发现、密码学、协议状态机是最需要正确性与跨平台一致性的部分，
  纯 Rust 实现无系统依赖，可脱离 UI 做单元 / 集成测试。
- **契约即边界**：`rust/src/api/` 是唯一的桥接面（见 `types.rs`、`node.rs`），
  Rust 只把信令当作不透明字符串转运，媒体协商细节全部留在 Dart。
- 虚拟显示器属于平台胶水，放在 Dart 侧的 `VirtualDisplayProvider` 之后；后续若在
  Rust 中自研低延迟采集编码管线，可作为标准 WebRTC 发送端与现有接收端互通，
  无需改动副屏侧。

### 控制面协议

- **发现**：mDNS 服务 `_localscreen._tcp.local.`，TXT 记录携带
  `id / name / kind / platform / v`。
- **身份**：首次启动生成 Ed25519 长期密钥，设备 ID = 公钥指纹。
- **传输**：TCP，长度前缀帧。
- **首次配对**：副屏生成 6 位 PIN → 双方以 PIN 运行 **SPAKE2**（抗离线爆破的
  PAKE）→ 派生会话密钥，并交换、保存长期信任密钥。
- **再次连接**：用已保存的信任密钥做双向挑战应答，免 PIN。
- **加密**：握手后所有帧用 ChaCha20-Poly1305 加密；SDP 中的 DTLS 指纹因此被认证，
  媒体面等效端到端加密，局域网内的中间人无法旁听或篡改。

### 目录结构

```
lib/
  app/            应用外壳、路由、主题与设计令牌
  core/           节点服务封装、偏好设置、平台工具
  features/
    discovery/    首页 · 附近设备
    pairing/      请求、PIN 输入与展示
    session/      投屏会话（主机控制台 / 副屏全屏）
    settings/     设置与受信任设备
  src/rust/       flutter_rust_bridge 生成代码（勿手改）
rust/src/
  api/            桥接面：types.rs · node.rs
  core/           identity · discovery · pairing · channel · session · store
docs/             PLAN.md · DESIGN.md
```

## 5. 工程规范

- Dart：`flutter analyze` 零告警；按 feature 分包；UI 只依赖 `core` 的抽象，不直接调桥接函数。
- Rust：`cargo clippy -D warnings`、`cargo fmt`；`api` 只做转发，逻辑在 `core` 并配测试。
- 界面只使用 `docs/DESIGN.md` 定义的令牌，禁止硬编码颜色 / 圆角 / 间距 / 时长。
- 文案全部走本地化文件。

## 6. 平台与验证状态

| 平台 | 副屏端 | 主机端 | CI 构建 | 运行验证 |
|---|---|---|---|---|
| Linux (GNOME Wayland / X11) | ✓ | 镜像 ✓ · 扩展 ✓ (GNOME) | ✓ | 见下 |
| Windows | ✓ | 镜像 | ✓ | 待真机验证 |
| macOS | ✓ | 镜像（需屏幕录制权限） | ✓ | 待真机验证 |
| Android | ✓ | 镜像（MediaProjection） | ✓ | 待真机验证 |
| iOS / iPadOS | ✓ | 需 Broadcast Extension（M3） | 未构建 | 待真机验证 |

每次推送都会由 GitHub Actions（`.github/workflows/build.yml`）跑静态检查与测试，并构建
Linux / Android / Windows / macOS 安装包，可在对应的 workflow 运行页面下载。

**已在开发机（Ubuntu 26.04）实测**

- **镜像**：同一台机器上启动两个相互隔离的真实实例（X11 虚拟显示器），走通 mDNS 互相发现 →
  PIN 配对 → H.264 编码的 WebRTC 投屏 → 副屏渲染与工具条 → 断开 → 重启后免 PIN 重连，
  截图见 `docs/screenshots/e2e_pin_pairing.png` 等。
- **扩展**：在一个隔离的无头 GNOME Wayland 会话里运行两个真实实例，走通
  选择「扩展」→ 配对 → 主机创建虚拟显示器 → 系统门户选屏 → 副屏全屏显示这块虚拟显示器的
  实时画面（把窗口移到虚拟显示器上，副屏同步出现）→ 断开后虚拟显示器被移除。
  截图见 `docs/screenshots/e2e_extend_*.png`。
- 在真实桌面会话中创建并销毁 2560×1600 的虚拟显示器
  （`LS_REAL_MUTTER=1 flutter test test/platform/mutter_virtual_display_test.dart`）。

**已知问题**

- Wayland 下开始投屏时系统选屏对话框会弹出两个（来自 flutter_webrtc 插件枚举屏幕源时的
  额外请求）。在最上面的那个里选屏并共享即可出画面，另一个取消不影响投屏。
- 系统没有音频服务（PulseAudio / PipeWire-Pulse）时，libwebrtc 初始化会直接中止进程。
  正常桌面环境都有音频服务，仅在精简或无头环境会遇到。

**尚未实测**

- 两台物理设备之间（真实 Wi-Fi、不同系统）的发现与投屏——需要真机。
- Windows / macOS / Android 安装包只验证了能构建，没有运行过。
- 开机自启在登录后的实际生效。
