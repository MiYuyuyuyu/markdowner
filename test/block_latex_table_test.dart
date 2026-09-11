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

/// 表格单元格内含块级公式时,IntrinsicColumnWidth 的固有宽度测量
/// 会遇到 width=infinity 的块公式容器,导致布局爆炸(正文空白)。
void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('REPRO: block latex inside table cell renders without crash', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final root = Directory.systemTemp.createTempSync('markdown_app_blk_');
    addTearDown(() => root.deleteSync(recursive: true));
    final mdFile = File('${root.path}/概率论.md');
    mdFile.writeAsStringSync(r'''
# 概率论

| 公式 | 说明 |
|------|------|
| $$P(A|B)=\frac{P(B|A)P(A)}{P(B)}$$ | 贝叶斯公式 |
| $$X \sim N(\mu, \sigma^2)$$ | 正态分布 |

## 第二节

表格之后的内容。
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

    // 滚动到表格区域,触发其布局
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '表格含块公式时布局崩溃');
    expect(find.textContaining('贝叶斯公式'), findsOneWidget,
        reason: '表格内容应可见');
  });
}
