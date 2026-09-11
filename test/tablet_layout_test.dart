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
import 'package:markdown_app/theme/app_breakpoints.dart';
import 'package:markdown_app/widgets/tab_bar/browser_tab_bar.dart';
import 'package:markdown_app/widgets/navigation/toc_panel.dart';
import 'package:markdown_app/widgets/sidebar/file_explorer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('windowTierForWidth', () {
    test('maps widths to three tiers', () {
      expect(windowTierForWidth(500), WindowTier.compact);
      expect(windowTierForWidth(600), WindowTier.medium);
      expect(windowTierForWidth(800), WindowTier.medium);
      expect(windowTierForWidth(1099), WindowTier.medium);
      expect(windowTierForWidth(1100), WindowTier.expanded);
    });
  });

  testWidgets('compact tier hides inline panels', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final root = Directory.systemTemp.createTempSync('markdown_app_tab_');
    addTearDown(() => root.deleteSync(recursive: true));
    final mdFile = File('${root.path}/doc.md');
    mdFile.writeAsStringSync('# Doc');

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    await storageService.saveReadingSession(
      const ReadingSession(showToc: true),
    );
    final settings = SettingsProvider(storageService);
    final tabManager = TabManager(FileService(), storageService);
    final workspace = WorkspaceProvider(FileService(), storageService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storageService),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<TabManager>.value(value: tabManager),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspace),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    // compact 档:无内嵌面板
    expect(find.byType(FileExplorer), findsNothing);
    expect(find.byType(TocPanel), findsNothing);
  });

  testWidgets('medium tier shows inline toc but sidebar stays in drawer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final root = Directory.systemTemp.createTempSync('markdown_app_tab_');
    addTearDown(() => root.deleteSync(recursive: true));
    final mdFile = File('${root.path}/doc.md');
    mdFile.writeAsStringSync('# Doc\n\n内容');

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    await storageService.saveReadingSession(
      const ReadingSession(showToc: true),
    );
    final settings = SettingsProvider(storageService);
    final tabManager = TabManager(FileService(), storageService);
    final workspace = WorkspaceProvider(FileService(), storageService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storageService),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<TabManager>.value(value: tabManager),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspace),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    // 打开一个文件(真实 IO,runAsync 内完成)
    await tester.runAsync(() async {
      await tabManager.openFileFromPath(mdFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // medium:目录内嵌、侧栏不内嵌
    expect(find.byType(TocPanel), findsOneWidget);
    expect(find.byType(FileExplorer), findsNothing);
  });

  testWidgets('expanded tier shows sidebar and limits reading width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final root = Directory.systemTemp.createTempSync('markdown_app_tab_');
    addTearDown(() => root.deleteSync(recursive: true));
    final mdFile = File('${root.path}/doc.md');
    mdFile.writeAsStringSync('# Doc\n\n| A | B |\n|---|---|\n| 1 | 2 |');

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    await storageService.saveReadingSession(
      const ReadingSession(showSidebar: true, showToc: true),
    );
    final settings = SettingsProvider(storageService);
    final tabManager = TabManager(FileService(), storageService);
    final workspace = WorkspaceProvider(FileService(), storageService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storageService),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<TabManager>.value(value: tabManager),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspace),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.runAsync(() async {
      await tabManager.openFileFromPath(mdFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // expanded:侧栏 + 目录 + 内容三栏
    expect(find.byType(FileExplorer), findsOneWidget);
    expect(find.byType(TocPanel), findsOneWidget);

    // 阅读内容限宽:表格 wrapper 不超过 840(减去 viewer 内边距 48)
    final wrapperWidth =
        tester.getSize(find.byKey(const ValueKey('markdown-table-wrapper')))
            .width;
    expect(wrapperWidth, lessThanOrEqualTo(840));
    expect(wrapperWidth, greaterThan(600));
  });

  testWidgets('tab close button is always visible with touch-sized area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final root = Directory.systemTemp.createTempSync('markdown_app_tab_');
    addTearDown(() => root.deleteSync(recursive: true));
    final mdFile = File('${root.path}/tab-doc.md');
    mdFile.writeAsStringSync('# Doc');

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    final settings = SettingsProvider(storageService);
    final tabManager = TabManager(FileService(), storageService);
    final workspace = WorkspaceProvider(FileService(), storageService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storageService),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<TabManager>.value(value: tabManager),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspace),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.runAsync(() async {
      await tabManager.openFileFromPath(mdFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // 未 hover 时关闭按钮也存在且命中区域达标。
    // 文字与关闭图标是 Row 兄弟节点;按 36x36 命中 SizedBox 定位
    final hitBoxFinder = find.ancestor(
      of: find.byIcon(Icons.close),
      matching: find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 36.0,
      ),
    );
    expect(hitBoxFinder, findsOneWidget);
    final size = tester.getSize(hitBoxFinder);
    expect(size.width, greaterThanOrEqualTo(32));
    expect(size.height, greaterThanOrEqualTo(32));
  });

  testWidgets('long pressing a tab opens the context menu', (tester) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final root = Directory.systemTemp.createTempSync('markdown_app_tab_');
    addTearDown(() => root.deleteSync(recursive: true));
    final mdFile = File('${root.path}/tab-doc.md');
    mdFile.writeAsStringSync('# Doc');

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    final settings = SettingsProvider(storageService);
    final tabManager = TabManager(FileService(), storageService);
    final workspace = WorkspaceProvider(FileService(), storageService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storageService),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<TabManager>.value(value: tabManager),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspace),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.runAsync(() async {
      await tabManager.openFileFromPath(mdFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // 限定在标签栏内长按(侧栏最近列表里也有同名条目)
    await tester.longPress(
      find.descendant(
        of: find.byType(BrowserTabBar),
        matching: find.text('tab-doc.md'),
      ),
    );
    await tester.pumpAndSettle();

    // 长按与右键同款菜单(触摸设备可达)
    expect(find.text('关闭'), findsOneWidget);
    expect(find.text('关闭其他'), findsOneWidget);
  });
}
