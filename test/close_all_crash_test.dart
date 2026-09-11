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
import 'package:markdown_app/widgets/tab_bar/browser_tab_bar.dart';
import 'package:markdown_app/widgets/welcome/welcome_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('closing all tabs while toc jump is pending does not crash', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final root = Directory.systemTemp.createTempSync('markdown_app_ca_');
    addTearDown(() => root.deleteSync(recursive: true));
    // 文档包含标题 + 表格(触发过崩溃的场景)
    final mdFile = File('${root.path}/doc.md');
    mdFile.writeAsStringSync('''
# 第一章

内容段落

| 列一 | 列二 | 列三 |
|------|------|------|
| 1 | 2 | 3 |

## 第二节

更多内容
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

    // 点击目录条目触发跳转(scroll_to_index 异步动画开始)
    final tocEntry = find.text('第一章').first;
    if (tester.any(tocEntry)) {
      await tester.tap(tocEntry, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
    }

    // 跳转动画进行中立即关闭全部标签(长按 → 关闭全部)
    await tester.longPress(
      find.descendant(
        of: find.byType(BrowserTabBar),
        matching: find.text('doc.md'),
      ),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭全部'));
    await tester.pumpAndSettle();

    // 不崩溃,回到欢迎页
    expect(tester.takeException(), isNull);
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(tabManager.hasTabs, isFalse);
  });

  testWidgets('closing tabs disposes toc controllers after frame', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final root = Directory.systemTemp.createTempSync('markdown_app_ca_');
    addTearDown(() => root.deleteSync(recursive: true));
    final mdFile = File('${root.path}/a.md');
    mdFile.writeAsStringSync('# A\n\n| 一 | 二 |\n|---|---|\n| 1 | 2 |');
    final mdFile2 = File('${root.path}/b.md');
    mdFile2.writeAsStringSync('# B');

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
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
      await tabManager.openFileFromPath(mdFile2.path);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(tabManager.hasTabs, isTrue);

    // 依次关闭所有标签
    while (tabManager.hasTabs) {
      await tester.longPress(
        find.descendant(
          of: find.byType(BrowserTabBar),
          matching: find.byType(Text),
        ).first,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭').last);
      await tester.pumpAndSettle();
    }

    expect(find.byType(WelcomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
