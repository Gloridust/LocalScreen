# LocalScreen

把身边任意设备变成你的副屏——像 LocalSend 传文件一样简单。

- 局域网自动发现，点选即投屏
- PIN 配对，端到端加密，流量不出内网
- Flutter + Rust，目标平台：Linux / Windows / macOS / Android / iOS

文档：[产品与技术方案](docs/PLAN.md) · [设计规范](docs/DESIGN.md)

## 下载

在 [Releases](https://github.com/Gloridust/LocalScreen/releases/latest) 下载对应平台的安装包：

| 平台 | 安装包 | 安装 |
|---|---|---|
| Linux（Debian / Ubuntu） | `localscreen_<版本>_amd64.deb` | `sudo apt install ./localscreen_<版本>_amd64.deb` |
| Android | `LocalScreen-<版本>-android.apk` | 直接安装 |
| Windows | `LocalScreen-<版本>-windows-x64-setup.exe` | 运行安装程序 |
| macOS | `LocalScreen-<版本>-macos.dmg` | 拖入“应用程序” |

推送 `v*` 标签时，[GitHub Actions](https://github.com/Gloridust/LocalScreen/actions/workflows/build.yml)
会构建这些安装包并附到对应的 Release。本地打 deb：`flutter build linux --release && packaging/linux/build_deb.sh`。

## 开发

```bash
flutter pub get
flutter_rust_bridge_codegen generate   # 修改 rust/src/api 后执行
flutter run -d linux

# 无需 Rust 内核的演示模式（模拟附近设备；LS_FAKE_INCOMING=pin|trusted 模拟来电）
flutter run -d linux --dart-define=LS_FAKE=true

flutter test                                    # 单元 + 组件测试
flutter test --update-goldens test/screenshots  # 重新生成 docs/screenshots
```

需要 Flutter 3.47+、Rust 1.90+ 与 `flutter_rust_bridge_codegen` 2.13。
Linux 上构建还需要 GStreamer 开发包：
`sudo apt install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev`。

遇到问题时，设置 → 关于 → 诊断日志 可以打开日志文件夹（日志只保存在本机）。
