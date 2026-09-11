import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_app/models/tab_item.dart';
import 'package:markdown_app/providers/search_provider.dart';
import 'package:markdown_app/providers/settings_provider.dart';
import 'package:markdown_app/providers/tab_manager.dart';
import 'package:markdown_app/screens/home_screen.dart';
import 'package:markdown_app/services/file_service.dart';
import 'package:markdown_app/services/storage_service.dart';
import 'package:markdown_app/widgets/navigation/toc_panel.dart';
import 'package:markdown_app/widgets/search/document_search_panel.dart';
import 'package:markdown_app/widgets/search/global_search_panel.dart';
import 'package:markdown_app/widgets/search/quick_open_panel.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('searchInText', () {
    test('finds all case-insensitive matches with line numbers', () {
      const text = 'hello World\nsecond line\nHELLO again';
      final matches = searchInText(text, 'hello');
      expect(matches, hasLength(2));
      expect(matches[0].lineIndex, 0);
      expect(matches[0].lineText, 'hello World');
      expect(matches[1].lineIndex, 2);
    });

    test('returns empty for empty query', () {
      expect(searchInText('some text', ''), isEmpty);
    });

    test('returns empty when nothing matches', () {
      expect(searchInText('abc', 'xyz'), isEmpty);
    });

    test('match preview stays within line bounds', () {
      const text = '这是一个非常非常非常长的行,包含目标关键词在这里';
      final matches = searchInText(text, '关键词');
      expect(matches, hasLength(1));
      expect(matches.single.preview(), contains('关键词'));
    });
  });

  group('searchAcrossTabs', () {
    test('groups matches by tab and keeps order', () {
      final tabs = [
        TabItem(id: '1', title: 'A.md', content: 'apple pie'),
        TabItem(id: '2', title: 'B.md', content: 'no match here'),
        TabItem(id: '3', title: 'C.md', content: 'apple juice\napple tea'),
      ];
      final results = searchAcrossTabs(tabs, 'apple');
      expect(results, hasLength(2));
      expect(results[0].title, 'A.md');
      expect(results[1].title, 'C.md');
      expect(results[1].matches, hasLength(2));
    });
  });

  group('quick open entries', () {
    test('merges tabs and recents with tab priority and dedupe', () {
      final tabs = [
        TabItem(id: '1', title: 'open.md', filePath: 'D:/notes/open.md'),
        TabItem(id: '2', title: '未保存'),
      ];
      final entries = buildQuickOpenEntries(
        tabs: tabs,
        recentPaths: ['D:/notes/open.md', 'D:/notes/other.md'],
        fileNameOf: (path) => path.split('/').last,
      );
      expect(entries, hasLength(3));
      expect(entries[0].isOpen, isTrue);
      expect(entries[1].title, '未保存');
      expect(entries[2].title, 'other.md');
      expect(entries[2].isOpen, isFalse);
    });

    test('filter matches filename case-insensitively', () {
      final entries = [
        const QuickOpenEntry(
            title: 'Readme.md', subtitle: '', path: 'a', isOpen: false),
        const QuickOpenEntry(
            title: 'notes.txt', subtitle: '', path: 'b', isOpen: false),
      ];
      expect(filterQuickOpen(entries, 'read'), hasLength(1));
      expect(filterQuickOpen(entries, 'READ'), hasLength(1));
      expect(filterQuickOpen(entries, ''), hasLength(2));
    });
  });

  group('nearestHeadingIndexForLine', () {
    test('finds nearest preceding heading', () {
      // 行号:0=标题一,2=正文,4=标题二,6=正文2
      final headings = parseHeadings('# 第一标题\n\n正文\n\n## 第二标题\n\n正文2');
      expect(nearestHeadingIndexForLine(headings, 0), 0);
      expect(nearestHeadingIndexForLine(headings, 3), 0);
      expect(nearestHeadingIndexForLine(headings, 4), 1);
      expect(nearestHeadingIndexForLine(headings, 6), 1);
    });

    test('returns -1 when no headings at all', () {
      expect(nearestHeadingIndexForLine(const [], 3), -1);
    });
  });

  testWidgets('DocumentSearchPanel shows count and navigates with jumps', (
    tester,
  ) async {
    final jumps = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              top: 8,
              right: 16,
              child: DocumentSearchPanel(
                text: 'apple pie\nbanana\napple juice',
                onJumpToLine: jumps.add,
                onClose: () {},
              ),
            ),
          ],
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'apple');
    await tester.pump();

    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();
    expect(find.text('2/2'), findsOneWidget);
    expect(jumps, [2]);

    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pump();
    expect(find.text('1/2'), findsOneWidget);
    expect(jumps, [2, 0]);
  });

  testWidgets('DocumentSearchPanel close button fires callback', (
    tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DocumentSearchPanel(
          text: 'text',
          onJumpToLine: (_) {},
          onClose: () => closed = true,
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(closed, isTrue);
  });

  testWidgets('GlobalSearchPanel searches tabs and reports selection', (
    tester,
  ) async {
    final tabs = [
      TabItem(id: '1', title: 'A.md', content: 'apple pie\nnothing else'),
      TabItem(id: '2', title: 'B.md', content: 'another apple here'),
    ];
    TabItem? selectedTab;
    int? selectedLine;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GlobalSearchPanel(
          tabs: tabs,
          onSelected: (tab, line) {
            selectedTab = tab;
            selectedLine = line;
          },
        ),
      ),
    ));

    // 空查询显示引导文案
    expect(find.text('输入关键词,在所有已打开的文档中搜索'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'apple');
    // 冲掉 200ms 防抖定时器
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('A.md'), findsOneWidget);
    expect(find.text('B.md'), findsOneWidget);
    expect(find.textContaining('共 2 个文档、2 处命中'), findsOneWidget);

    await tester.tap(find.text('B.md'));
    await tester.pump();
    expect(selectedTab?.id, '2');
    expect(selectedLine, 0);
  });

  testWidgets('QuickOpenPanel filters and selects entry', (tester) async {
    final entries = [
      const QuickOpenEntry(
          title: 'Readme.md', subtitle: 'D:/a', path: 'D:/a/Readme.md', isOpen: true),
      const QuickOpenEntry(
          title: 'notes.txt', subtitle: 'D:/b', path: 'D:/b/notes.txt', isOpen: false),
    ];
    QuickOpenEntry? selected;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QuickOpenPanel(
          entries: entries,
          onSelected: (entry) => selected = entry,
        ),
      ),
    ));

    expect(find.text('Readme.md'), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'read');
    await tester.pump();
    expect(find.text('notes.txt'), findsNothing);

    await tester.tap(find.text('Readme.md'));
    await tester.pump();
    expect(selected?.path, 'D:/a/Readme.md');
  });

  testWidgets('HomeScreen registers search shortcuts and buttons', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    final settings = SettingsProvider(storageService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storageService),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider(
            create: (_) => TabManager(FileService(), storageService),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    final bindings =
        tester.widget<CallbackShortcuts>(find.byType(CallbackShortcuts))
            .bindings;

    bool hasActivator(LogicalKeyboardKey trigger, {bool shift = false}) {
      return bindings.keys.whereType<SingleActivator>().any(
            (activator) =>
                activator.trigger == trigger &&
                activator.control &&
                activator.shift == shift,
          );
    }

    expect(hasActivator(LogicalKeyboardKey.keyF), isTrue);
    expect(hasActivator(LogicalKeyboardKey.keyF, shift: true), isTrue);
    expect(hasActivator(LogicalKeyboardKey.keyP), isTrue);

    // 移动端/无键盘入口:AppBar 上有搜索与快速打开按钮
    expect(find.byTooltip('快速打开 (Ctrl+P)'), findsOneWidget);
    expect(find.byTooltip('跨标签搜索 (Ctrl+Shift+F)'), findsNothing); // 无标签页时不显示
  });
}
