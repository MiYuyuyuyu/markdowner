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

  testWidgets('FileExplorer shows sections and opens file from tree', (
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

    // 合并分区视图:目录树 + 最近文件分区同时可见
    expect(find.text('目录'), findsOneWidget);
    expect(find.text('最近文件 (0)'), findsOneWidget);
    expect(find.text('最近文件夹 (0)'), findsOneWidget);
    // 目录树条目可见(sub 目录 + 支持的文件;py/隐藏/build 被过滤)
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

  testWidgets('FileExplorer lists recent files section with remove', (
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

    expect(find.text('recent.md'), findsOneWidget);
    expect(find.text('最近文件 (1)'), findsOneWidget);

    // 点击 × 移除记录
    await tester.tap(find.byTooltip('移除最近文件'));
    await tester.pumpAndSettle();
    expect(storageService.getRecentFiles(), isEmpty);
    expect(find.text('recent.md'), findsNothing);
  });

  testWidgets('FileExplorer recent folders section supports open and remove', (
    tester,
  ) async {
    final root = _createSampleFolder();
    addTearDown(() => root.deleteSync(recursive: true));

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    await storageService.addRecentFolder(root.path);
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

    final folderName =
        root.path.replaceAll(Platform.pathSeparator, '/').split('/').last;
    expect(find.text(folderName), findsOneWidget);
    expect(find.textContaining('最近文件夹 (1)'), findsOneWidget);

    // 点击最近文件夹 → 打开为工作区(目录树出现)
    await tester.runAsync(() async {
      await tester.tap(find.text(folderName), warnIfMissed: false);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(workspace.rootPath, root.path);
    expect(find.text('a.txt'), findsOneWidget);

    // 点击 × → 仅移除记录,工作区保持打开
    await tester.tap(find.byTooltip('移除最近文件夹记录'));
    await tester.pumpAndSettle();
    expect(storageService.getRecentFolders(), isEmpty);
    expect(workspace.rootPath, root.path, reason: '移除记录不影响已打开的工作区');
  });

  testWidgets('vertical dividers resize section heights', (tester) async {
    final root = _createSampleFolder();
    addTearDown(() => root.deleteSync(recursive: true));

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    final settings = SettingsProvider(storageService);
    final workspace = WorkspaceProvider(FileService(), storageService);
    workspace.openFolder(root.path, persist: false);

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

    // 用分区标题的位置变化验证拖动效果(标题位置随分区边界移动)
    final treeTitleBefore = tester.getTopLeft(find.text('目录')).dy;
    final foldersTitleBefore =
        tester.getTopLeft(find.textContaining('最近文件夹').first).dy;
    expect(foldersTitleBefore, greaterThan(treeTitleBefore));

    // 向下拖目录/最近区域分隔条 80px → 目录树变高,最近文件夹标题下移
    await tester.drag(
      find.byKey(const ValueKey('tree-divider')),
      const Offset(0, 80),
    );
    await tester.pumpAndSettle();
    final foldersTitleAfterDrag1 =
        tester.getTopLeft(find.textContaining('最近文件夹').first).dy;
    expect(foldersTitleAfterDrag1, greaterThan(foldersTitleBefore),
        reason: '目录树变高后,最近文件夹分区应下移');

    // 向上拖 60px,目录树变矮,最近文件夹标题应上移
    await tester.drag(
      find.byKey(const ValueKey('tree-divider')),
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();
    final foldersTitleAfterDrag2 =
        tester.getTopLeft(find.textContaining('最近文件夹').first).dy;
    expect(foldersTitleAfterDrag2, lessThan(foldersTitleAfterDrag1),
        reason: '目录树变矮后,最近文件夹分区应上移');

    // 最近文件夹与最近文件之间:向下拖 → 最近文件标题下移
    final filesTitleBefore =
        tester.getTopLeft(find.textContaining('最近文件 (').first).dy;
    await tester.drag(
      find.byKey(const ValueKey('folders-divider')),
      const Offset(0, 60),
    );
    await tester.pumpAndSettle();
    final filesTitleAfter =
        tester.getTopLeft(find.textContaining('最近文件 (').first).dy;
    expect(filesTitleAfter, greaterThan(filesTitleBefore),
        reason: '最近文件夹区变高后,最近文件分区应下移');
  });

  testWidgets('rapid same-frame drag events do not lose increments', (
    tester,
  ) async {
    final root = _createSampleFolder();
    addTearDown(() => root.deleteSync(recursive: true));

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    final settings = SettingsProvider(storageService);
    final workspace = WorkspaceProvider(FileService(), storageService);
    workspace.openFolder(root.path, persist: false);

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

    // 模拟高轮询率鼠标:同一帧内连续多次小位移 move 事件
    // (帧未 pump,事件共享同一闭包)。修复前增量互相覆盖,
    // 拖动 150px 只生效最后一次的事件位移。
    final foldersTitleBefore =
        tester.getTopLeft(find.textContaining('最近文件夹').first).dy;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tree-divider'))),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 15));
    }
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final foldersTitleAfter =
        tester.getTopLeft(find.textContaining('最近文件夹').first).dy;
    final moved = foldersTitleAfter - foldersTitleBefore;
    expect(moved, greaterThan(100),
        reason: '同帧 10 次 x15px 事件应累计移动约 150px,'
            '实际仅移动 \$moved px,说明增量丢失');
  });
}
