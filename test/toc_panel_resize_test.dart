import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

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

  group('SettingsProvider tocPanelWidth', () {
    test('defaults to 240 and clamps to 180-480', () async {
      SharedPreferences.setMockInitialValues({});
      final storageService = await StorageService.init();
      final settings = SettingsProvider(storageService);

      expect(settings.tocPanelWidth, 240.0);

      settings.setTocPanelWidth(50);
      expect(settings.tocPanelWidth, 180.0);

      settings.setTocPanelWidth(999);
      expect(settings.tocPanelWidth, 480.0);
    });

    test('persists across provider instances', () async {
      SharedPreferences.setMockInitialValues({});
      final storageService = await StorageService.init();
      final settings = SettingsProvider(storageService);
      settings.setTocPanelWidth(320);

      final reloaded = SettingsProvider(storageService);
      expect(reloaded.tocPanelWidth, 320.0);
    });
  });

  testWidgets('dragging the divider resizes the toc panel', (tester) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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

    // 目录面板只在有激活文档时渲染,先打开一个文件(真实 IO,runAsync 放行)
    final root = Directory.systemTemp.createTempSync('markdown_app_toc_');
    addTearDown(() => root.deleteSync(recursive: true));
    final mdFile = File('${root.path}/doc.md');
    mdFile.writeAsStringSync('# Doc\n\n正文');
    await tester.runAsync(() async {
      await tabManager.openFileFromPath(mdFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // 初始宽度 240
    expect(tester.getSize(find.byType(TocPanel)).width, 240.0);

    // 向右拖动分隔条 60px
    await tester.drag(
      find.byKey(const ValueKey('toc-panel-divider')),
      const Offset(60, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(TocPanel)).width, closeTo(300, 2));

    // 再向左拖 200px,触发最小宽度 180 钳制(300-200=100 < 180)
    await tester.drag(
      find.byKey(const ValueKey('toc-panel-divider')),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(TocPanel)).width, 180.0);
  });
}
