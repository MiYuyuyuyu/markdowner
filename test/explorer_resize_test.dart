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
import 'package:markdown_app/widgets/sidebar/file_explorer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('SettingsProvider fileExplorerWidth', () {
    test('defaults to 260 and clamps to 200-400', () async {
      SharedPreferences.setMockInitialValues({});
      final storageService = await StorageService.init();
      final settings = SettingsProvider(storageService);

      expect(settings.fileExplorerWidth, 260.0);

      settings.setFileExplorerWidth(100);
      expect(settings.fileExplorerWidth, 200.0);

      settings.setFileExplorerWidth(999);
      expect(settings.fileExplorerWidth, 400.0);
    });

    test('persists across provider instances', () async {
      SharedPreferences.setMockInitialValues({});
      final storageService = await StorageService.init();
      final settings = SettingsProvider(storageService);
      settings.setFileExplorerWidth(320);

      final reloaded = SettingsProvider(storageService);
      expect(reloaded.fileExplorerWidth, 320.0);
    });
  });

  testWidgets('dragging the explorer divider resizes the sidebar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final root = Directory.systemTemp.createTempSync('markdown_app_exp_');
    addTearDown(() => root.deleteSync(recursive: true));
    final mdFile = File('${root.path}/doc.md');
    mdFile.writeAsStringSync('# Doc\n\n正文');

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    await storageService.saveReadingSession(
      const ReadingSession(showSidebar: true),
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

    // 打开一个文件(真实 IO,runAsync 放行)
    await tester.runAsync(() async {
      await tabManager.openFileFromPath(mdFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // 初始宽度 260
    expect(tester.getSize(find.byType(FileExplorer)).width, 260.0);

    // 向右拖动分隔条 80px
    await tester.drag(
      find.byKey(const ValueKey('explorer-divider')),
      const Offset(80, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(FileExplorer)).width, closeTo(340, 2));

    // 向左拖 300px,触发最小宽度 200 钳制(340-300=40 < 200)
    await tester.drag(
      find.byKey(const ValueKey('explorer-divider')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(FileExplorer)).width, 200.0);
  });
}
