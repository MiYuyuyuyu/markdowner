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
import 'package:markdown_app/widgets/navigation/toc_panel.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  Future<(WidgetTester, StorageService)> pumpApp(
    WidgetTester tester,
    Map<String, Object> initialValues,
  ) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final root = Directory.systemTemp.createTempSync('markdown_app_toc_');
    addTearDown(() => root.deleteSync(recursive: true));
    final mdFile = File('${root.path}/doc.md');
    mdFile.writeAsStringSync('# Doc\n\n正文');

    SharedPreferences.setMockInitialValues(initialValues);
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

    // 目录面板只在有激活文档时渲染
    await tester.runAsync(() async {
      await tabManager.openFileFromPath(mdFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    return (tester, storageService);
  }

  testWidgets('uses persisted width, drag resizes and persists', (tester) async {
    final (t, storageService) = await pumpApp(
      tester,
      {'toc_panel_width': 320.0},
    );

    // 初始宽度来自持久化设置
    expect(t.getSize(find.byType(TocPanel)).width, 320.0);

    // 向右拖动 60px → 380,松手后写入持久化
    await t.drag(
      find.byKey(const ValueKey('toc-panel-divider')),
      const Offset(60, 0),
    );
    await tester.pumpAndSettle();

    expect(t.getSize(find.byType(TocPanel)).width, closeTo(380, 2));
    expect(storageService.getTocPanelWidth(), closeTo(380, 0.5));

    // 向左拖 400px → 触发最小宽度 180 钳制
    await t.drag(
      find.byKey(const ValueKey('toc-panel-divider')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();

    expect(t.getSize(find.byType(TocPanel)).width, 180.0);
    expect(storageService.getTocPanelWidth(), 180.0);
  });
}
