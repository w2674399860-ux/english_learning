import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// App 显示名称在各平台统一为"梦词"（U-10 I-f 统一为"AI 英语学习"，2026-10 改名）。
void main() {
  const name = '梦词';

  String read(String path) => File(path).readAsStringSync();

  test('Web：标题、iOS 主屏名称、manifest、语言', () {
    final html = read('web/index.html');
    expect(html, contains('<title>$name</title>'));
    expect(html, contains('apple-mobile-web-app-title" content="$name"'));
    expect(html, contains('<html lang="zh-CN">'));
    final manifest = read('web/manifest.json');
    expect(manifest, contains('"name": "$name"'));
    expect(manifest, contains('"short_name": "$name"'));
  });

  test('Android 桌面名称', () {
    expect(
      read('android/app/src/main/AndroidManifest.xml'),
      contains('android:label="$name"'),
    );
  });

  test('iOS 桌面名称与 CFBundleName', () {
    final plist = read('ios/Runner/Info.plist');
    expect(
      plist,
      matches(
        RegExp('<key>CFBundleDisplayName</key>\\s*<string>$name</string>'),
      ),
    );
    expect(
      plist,
      matches(RegExp('<key>CFBundleName</key>\\s*<string>$name</string>')),
    );
  });
}
