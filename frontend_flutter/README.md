# AI 英语学习 — Flutter 客户端

项目说明、启动方式见仓库根目录的 [README](../README.md)，开发细节见 [开发者操作文档](../docs/开发者操作文档.md)。

```powershell
flutter pub get
flutter run -d chrome --web-port 5000                               # Web 调试（后端需放行 5000 端口的 CORS）
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000         # Android 模拟器
flutter analyze
flutter test
```

后端地址通过 `--dart-define=API_BASE_URL=...` 指定，默认 `http://localhost:8000`；移动端 release 构建必须是 `https://`。
