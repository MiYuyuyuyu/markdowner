// ignore_for_file: unnecessary_string_escapes
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_app/models/reading_session.dart';
import 'package:markdown_app/providers/settings_provider.dart';
import 'package:markdown_app/providers/tab_manager.dart';
import 'package:markdown_app/providers/workspace_provider.dart';
import 'package:markdown_app/screens/home_screen.dart';
import 'package:markdown_app/services/file_service.dart';
import 'package:markdown_app/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('REPRO: toc jump on rich doc does not corrupt layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final root = Directory.systemTemp.createTempSync('markdown_app_repro_');
    addTearDown(() => root.deleteSync(recursive: true));
    final mdFile = File('${root.path}/概率论.md');
    // 模拟高数/概率笔记特征:多级标题+表格+块公式+行内公式
    mdFile.writeAsStringSync('''
# 第一章 排列与逆序数

正文含行内公式 \$a_i\$ 与表格:

| 列一 | 列二 | 列三 | 列四 |
|------|------|------|------|
| \$x=1\$ | 内容二 | \$\frac{a}{b}\$ | 内容四 |
| 2 | 3 | 4 | 5 |

\$\$
y = x^2 + 2x + 1
\$\$

## 第二节 六大基本性质

更多正文内容,包含 \$\lambda\$ 符号。

| A | B |
|-----|-----|
| \$\sum_i x_i\$ | \$\prod_j y_j\$ |

\$\$
P(A|B) = \frac{P(B|A)P(A)}{P(B)}
\$\$

### 小节 递推法详解

尾段内容。
''');

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    await storageService.saveReadingSession(
      const ReadingSession(showToc: true),
    );
    final settings = SettingsProvider(storageService);
    final tabManager = TabManager(FileService(), storageService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storageService),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<TabManager>.value(value: tabManager),
          ChangeNotifierProvider(
            create: (_) => WorkspaceProvider(FileService(), storageService),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.runAsync(() async {
      await tabManager.openFileFromPath(mdFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // 正文应可见
    expect(find.textContaining('排列与逆序数'), findsWidgets);

    // 点击目录条目(跳到后面的标题)
    await tester.tap(find.textContaining('六大基本性质').first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: '目录跳转后布局损坏');

    // 滚动后正文仍应渲染(点击目录条目后视口应包含第二节内容)
    expect(find.textContaining('更多正文内容'), findsWidgets,
        reason: '跳转后正文不可见');
  });
}
