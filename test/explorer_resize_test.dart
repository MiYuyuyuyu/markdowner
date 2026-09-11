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

  testWidgets('uses persisted width, drag resizes and clamps', (tester) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final root = Directory.systemTemp.createTempSync('markdown_app_exp_');
    addTearDown(() => root.deleteSync(recursive: true));
    final mdFile = File('${root.path}/doc.md');
    mdFile.writeAsStringSync('# Doc\n\n正文');

    SharedPreferences.setMockInitialValues({'file_explorer_width': 320.0});
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

    await tester.runAsync(() async {
      await tabManager.openFileFromPath(mdFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // 初始宽度来自持久化设置
    expect(tester.getSize(find.byType(FileExplorer)).width, 320.0);

    // 向右拖动 80px → 400 以下
    await tester.drag(
      find.byKey(const ValueKey('explorer-divider')),
      const Offset(80, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(FileExplorer)).width, closeTo(400, 2));
    expect(storageService.getFileExplorerWidth(), closeTo(400, 0.5));

    // 向左拖 300px → 触发最小宽度 200 钳制
    await tester.drag(
      find.byKey(const ValueKey('explorer-divider')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(FileExplorer)).width, 200.0);
    expect(storageService.getFileExplorerWidth(), 200.0);
  });
}
