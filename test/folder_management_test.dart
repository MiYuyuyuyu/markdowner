import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_app/providers/settings_provider.dart';
import 'package:markdown_app/providers/tab_manager.dart';
import 'package:markdown_app/providers/workspace_provider.dart';
import 'package:markdown_app/services/file_service.dart';
import 'package:markdown_app/services/storage_service.dart';
import 'package:markdown_app/widgets/sidebar/file_explorer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 构造临时目录:
/// root/
///   b.md
///   a.txt
///   .hidden.md          (隐藏,应跳过)
///   note.py             (不支持类型,应跳过)
///   sub/sub.md
///   build/x.md          (排除目录,应跳过)
Directory _createSampleFolder() {
  final root = Directory.systemTemp.createTempSync('markdown_app_ws_');
  File('${root.path}/b.md').writeAsStringSync('# B');
  File('${root.path}/a.txt').writeAsStringSync('A');
  File('${root.path}/.hidden.md').writeAsStringSync('hidden');
  File('${root.path}/note.py').writeAsStringSync('print(1)');
  final sub = Directory('${root.path}/sub')..createSync();
  File('${sub.path}/sub.md').writeAsStringSync('# Sub');
  final build = Directory('${root.path}/build')..createSync();
  File('${build.path}/x.md').writeAsStringSync('# X');
  return root;
}

void main() {
  group('FileService.listEntries', () {
    test('dirs first, sorts by name, filters hidden/build/unsupported', () {
      final root = _createSampleFolder();
      addTearDown(() => root.deleteSync(recursive: true));

      final fileService = FileService();
      final entries = fileService.listEntries(root.path);

      final names = entries
          .map((e) => e.path.replaceAll('\\', '/').split('/').last)
          .toList();
      expect(names, ['sub', 'a.txt', 'b.md']);
    });

    test('returns empty for missing directory', () {
      final fileService = FileService();
      expect(fileService.listEntries('Z:/definitely/missing'), isEmpty);
    });
  });

  group('WorkspaceProvider', () {
    test('openFolder builds tree, lazy loads and toggles', () async {
      final root = _createSampleFolder();
      addTearDown(() => root.deleteSync(recursive: true));

      SharedPreferences.setMockInitialValues({});
      final storageService = await StorageService.init();
      final workspace = WorkspaceProvider(FileService(), storageService);

      expect(workspace.root, isNull);

      workspace.openFolder(root.path);
      expect(workspace.rootPath, root.path);
      expect(workspace.isExpanded(root.path), isTrue);

      // 根已展开且子节点已加载:root + sub + a.txt + b.md
      expect(workspace.flattenVisible(), hasLength(4));

      final sub = workspace
          .flattenVisible()
          .firstWhere((row) => row.$1.name == 'sub')
          .$1;
      expect(workspace.isExpanded(sub.path), isFalse);

      workspace.toggleExpand(sub);
      expect(workspace.isExpanded(sub.path), isTrue);
      expect(sub.children, isNotNull);
      expect(sub.children!.single.name, 'sub.md');
      expect(workspace.flattenVisible(), hasLength(5));

      workspace.toggleExpand(sub);
      expect(workspace.flattenVisible(), hasLength(4));
    });

    test('persists recent folders and restores last workspace', () async {
      final root = _createSampleFolder();
      addTearDown(() => root.deleteSync(recursive: true));

      SharedPreferences.setMockInitialValues({});
      final storageService = await StorageService.init();
      final workspace = WorkspaceProvider(FileService(), storageService);

      workspace.openFolder(root.path);
      // 持久化写入是异步的,冲一下微任务队列
      await Future<void>.delayed(Duration.zero);
      expect(storageService.getRecentFolders(), [root.path]);
      expect(storageService.getLastWorkspace(), root.path);

      final restored = WorkspaceProvider(FileService(), storageService);
      restored.restoreLast();
      expect(restored.rootPath, root.path);
    });
  });

  testWidgets('FileExplorer renders folder tree and opens file on tap', (
    tester,
  ) async {
    final root = _createSampleFolder();
    addTearDown(() => root.deleteSync(recursive: true));

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    final settings = SettingsProvider(storageService);
    final workspace = WorkspaceProvider(FileService(), storageService);
    final tabManager = TabManager(FileService(), storageService);
    workspace.openFolder(root.path, persist: false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storageService),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<TabManager>.value(value: tabManager),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspace),
        ],
        child: const MaterialApp(home: Scaffold(body: FileExplorer())),
      ),
    );
    await tester.pumpAndSettle();

    // 切换到目录模式(默认为最近模式)
    await tester.tap(find.text('目录'));
    await tester.pumpAndSettle();

    // 目录模式下可见根下条目(sub 目录 + 支持的文件;py/隐藏/build 被过滤)
    expect(find.text('sub'), findsOneWidget);
    expect(find.text('a.txt'), findsOneWidget);
    expect(find.text('b.md'), findsOneWidget);
    expect(find.text('note.py'), findsNothing);
    expect(find.text('.hidden.md'), findsNothing);

    // 点击 b.md → 打开为新标签。
    // openFileFromPath 内部是真实异步 IO,需整体在 runAsync 内完成。
    await tester.runAsync(() async {
      await tester.tap(find.text('b.md'), warnIfMissed: false);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(tabManager.hasTabs, isTrue);
    expect(tabManager.activeTab?.title, 'b.md');
  });

  testWidgets('FileExplorer recent mode still lists recent files', (
    tester,
  ) async {
    final root = _createSampleFolder();
    addTearDown(() => root.deleteSync(recursive: true));
    final mdFile = File('${root.path}/recent.md');
    mdFile.writeAsStringSync('# Recent');

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    await storageService.addRecentFile(mdFile.path);
    final settings = SettingsProvider(storageService);
    final workspace = WorkspaceProvider(FileService(), storageService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storageService),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider(
            create: (_) => TabManager(FileService(), storageService),
          ),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspace),
        ],
        child: const MaterialApp(home: Scaffold(body: FileExplorer())),
      ),
    );
    await tester.pumpAndSettle();

    debugPrint('recent files: ${storageService.getRecentFiles()}');
    debugPrint(
        'text widgets: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).where((d) => d != null).toList()}');
    // 默认"最近"模式
    expect(find.text('recent.md'), findsOneWidget);

    // 切到目录模式
    await tester.tap(find.text('目录'));
    await tester.pumpAndSettle();
    expect(find.text('recent.md'), findsNothing);
    expect(find.textContaining('打开一个文件夹'), findsOneWidget);
  });
}
