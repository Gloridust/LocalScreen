# LocalScreen

把身边任意设备变成你的副屏——像 LocalSend 传文件一样简单。

- 局域网自动发现，点选即投屏
- PIN 配对，端到端加密，流量不出内网
- Flutter + Rust，目标平台：Linux / Windows / macOS / Android / iOS

文档：[产品与技术方案](docs/PLAN.md) · [设计规范](docs/DESIGN.md)

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
