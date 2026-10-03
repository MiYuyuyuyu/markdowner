import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown_app/models/reading_session.dart';
import 'package:markdown_app/theme/app_theme.dart';
import 'package:markdown_app/providers/settings_provider.dart';
import 'package:markdown_app/screens/home_screen.dart';
import 'package:markdown_app/widgets/markdown/mermaid_support.dart';
import 'package:markdown_app/widgets/markdown/markdown_viewer.dart';
import 'package:markdown_app/widgets/welcome/welcome_page.dart';
import 'package:markdown_app/widgets/navigation/toc_panel.dart';
import 'package:provider/provider.dart';
import 'package:markdown_app/providers/tab_manager.dart';
import 'package:markdown_app/services/file_service.dart';
import 'package:markdown_app/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:markdown_widget/markdown_widget.dart';

double? _findFontSizeForText(InlineSpan span, String text) {
  if (span is TextSpan) {
    if (span.text == text) {
      return span.style?.fontSize;
    }

    for (final child in span.children ?? const <InlineSpan>[]) {
      final fontSize = _findFontSizeForText(child, text);
      if (fontSize != null) {
        return fontSize;
      }
    }
  }

  return null;
}

void main() {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  test('StorageService saves and restores reading session', () async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();

    await storageService.saveReadingSession(
      const ReadingSession(
        openTabs: [
          ReadingSessionTab(path: 'D:\\notes\\a.md', scrollOffset: 120),
          ReadingSessionTab(path: 'D:\\notes\\b.md', scrollOffset: 360),
        ],
        activePath: 'D:\\notes\\b.md',
        showSidebar: false,
        showToc: true,
      ),
    );

    final session = storageService.getReadingSession();

    expect(session.openTabs, hasLength(2));
    expect(session.openTabs[0].path, 'D:\\notes\\a.md');
    expect(session.openTabs[0].scrollOffset, 120);
    expect(session.activePath, 'D:\\notes\\b.md');
    expect(session.showSidebar, isFalse);
    expect(session.showToc, isTrue);
  });

  test('TabManager restores session and removes unreadable recent files', () async {
    final tempDir = await Directory.systemTemp.createTemp('markdown_app_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final validFile = File('${tempDir.path}${Platform.pathSeparator}valid.md');
    final missingPath = '${tempDir.path}${Platform.pathSeparator}missing.md';
    await validFile.writeAsString('# Valid');

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    await storageService.addRecentFile(validFile.path);
    await storageService.addRecentFile(missingPath);
    await storageService.saveReadingSession(
      ReadingSession(
        openTabs: [
          ReadingSessionTab(path: missingPath, scrollOffset: 100),
          ReadingSessionTab(path: validFile.path, scrollOffset: 240),
        ],
        activePath: validFile.path,
        showSidebar: true,
        showToc: false,
      ),
    );

    final tabManager = TabManager(FileService(), storageService);
    await tabManager.restoreSession();

    expect(tabManager.tabs, hasLength(1));
    expect(tabManager.activeTab?.filePath, validFile.path);
    expect(tabManager.activeTab?.scrollOffset, 240);
    expect(storageService.getRecentFiles(), isNot(contains(missingPath)));
  });

  testWidgets('WelcomePage shows title and open button', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    final fileService = FileService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => TabManager(fileService, storageService),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: WelcomePage())),
      ),
    );

    expect(find.text('Markdown Reader'), findsOneWidget);
    expect(find.text('打开文件'), findsNWidgets(2));
  });

  testWidgets(
    'MarkdownViewer keeps table cell text after latex absolute value',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storageService = await StorageService.init();

      const markdown = r'''
| 性质 | 定义 | 常见判别 |
|------|------|---------|
| **有界性** | $\exists M>0$，使 $|f(x)| \leq M$ | 闭区间上连续函数必有界 |
''';

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(storageService),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: MarkdownViewer(data: markdown)),
          ),
        ),
      );
      expect(find.text('闭区间上连续函数必有界'), findsOneWidget);
    },
  );

  testWidgets('MarkdownViewer uses configured reader font size', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'font_size': 22.0});
    final storageService = await StorageService.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MarkdownViewer(data: '普通正文测试')),
        ),
      ),
    );
    final richTextFinder = find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == '普通正文测试',
    );
    final richTextWidget = tester.widget<RichText>(richTextFinder);

    expect(_findFontSizeForText(richTextWidget.text, '普通正文测试'), 22.0);
  });

  testWidgets('MarkdownViewer does not overflow narrow tables', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();

    const markdown = r'''
| 原函数 | 等价无穷小 |
|------|------|
| $	an x - x$ | $rac{1}{3}x^3$ |
| $x-	ext{arctan}x$ | $rac{1}{3}x^3$ |
''';

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 320, child: MarkdownViewer(data: markdown)),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('MarkdownViewer does not overflow narrow plain text tables', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();

    const markdown = r'''
| 原函数 | 等价无穷小 |
|------|------|
| tan x - x | 1/3 x^3 |
| x - arctan x | 1/3 x^3 |
''';

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 320, child: MarkdownViewer(data: markdown)),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('MarkdownViewer scales heading text with reader font size', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'font_size': 22.0});
    final storageService = await StorageService.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MarkdownViewer(data: '## 标题测试')),
        ),
      ),
    );

    final richTextFinder = find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == '标题测试',
    );
    final richTextWidget = tester.widget<RichText>(richTextFinder);

    expect(_findFontSizeForText(richTextWidget.text, '标题测试'), 33.0);
  });

  test('AppTheme uses HarmonyOS Sans family', () {
    expect(AppTheme.light().textTheme.bodyMedium?.fontFamily, 'HarmonyOS Sans');
    expect(AppTheme.dark().textTheme.bodyMedium?.fontFamily, 'HarmonyOS Sans');
  });

  testWidgets('MarkdownViewer lets tables use available width on wide layouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();

    const markdown = r'''
| 性质 | 定义 | 常见判别 |
|------|------|---------|
| **有界性** | $orall x, |f(x)| 	ext{ 有界}$ | 闭区间上连续函数必有界 |
| **单调性** | $x_1 < x_2 ightarrow f(x_1) < f(x_2)$ | $f'(x) > 0$ 则递增 |
''';

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MarkdownViewer(data: markdown)),
        ),
      ),
    );

    final wrapperSize = tester.getSize(find.byKey(const ValueKey('markdown-table-wrapper')));
    expect(wrapperSize.width, greaterThan(1800));
  });

  testWidgets('MarkdownViewer keeps inline math tied to reader font size', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'font_size': 28.0});
    final storageService = await StorageService.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MarkdownViewer(data: r'定义：$f(x)$ 在区间上连续')),
        ),
      ),
    );

    final mathWidget = tester.widget<Math>(find.byType(Math));

    expect(mathWidget.textStyle?.fontSize, 28.0);
  });

  testWidgets('MarkdownViewer scales list item math with reader font size', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'font_size': 28.0});
    final storageService = await StorageService.init();

    const markdown = r'''
- $k=0$：$\lambda$ 不是特征根
''';

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MarkdownViewer(data: markdown)),
        ),
      ),
    );

    final mathFontSizes = tester
        .widgetList<Math>(find.byType(Math))
        .map((math) => math.textStyle?.fontSize)
        .toSet();

    expect(mathFontSizes, {28.0});
  });

  testWidgets('MarkdownViewer boosts inline math scale for visual consistency', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'font_size': 28.0});
    final storageService = await StorageService.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MarkdownViewer(data: r'定义：$f(x)$ 在区间上连续')),
        ),
      ),
    );

    final mathWidget = tester.widget<Math>(find.byType(Math));

    expect(mathWidget.textScaleFactor, greaterThan(1.0));
  });

  testWidgets('MarkdownViewer preserves bullets for formula-only list items', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();

    const markdown = r'''
- $e^x = 1 + x + rac{x^2}{2!}$
- $rac{1}{1-x} = 1 + x + x^2 + rac{x^3}{3!}$
- $(1+x)^rac{1}{2} = 1 + rac{x}{2}$
''';

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MarkdownViewer(data: markdown)),
        ),
      ),
    );

    final bulletFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.constraints?.hasTightWidth == true &&
          widget.constraints?.hasTightHeight == true &&
          widget.constraints?.minWidth == 6 &&
          widget.constraints?.minHeight == 6,
    );

    expect(bulletFinder, findsNWidgets(3));
  });

  testWidgets('MarkdownViewer renders mermaid blocks via local webview', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();

    const markdown = r'''
```mermaid
graph TD
    A --> B
```
''';

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MarkdownViewer(data: markdown)),
        ),
      ),
    );

    // 本地 WebView 渲染(不再走 mermaid.ink 在线服务)
    expect(find.byType(MermaidView), findsOneWidget);
    // 测试环境没有 WebView 插件,平台调用永久挂起:10 秒初始化超时后
    // 应降级为失败卡片,不允许崩溃(fake async 下为虚拟时间,不真实等待)
    await tester.pump(const Duration(seconds: 11));
    expect(find.text('Mermaid 图表渲染失败'), findsOneWidget);
  });

  testWidgets('TocPanel scrolls MarkdownViewer when a heading is tapped', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    final tocController = TocController();
    final filler = List.filled(40, '正文内容').join('\n\n');
    final markdown = '# 开头\n\n$filler\n\n## 目标标题\n\n目标内容';

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                TocPanel(markdownData: markdown, tocController: tocController),
                Expanded(
                  child: MarkdownViewer(
                    data: markdown,
                    tocController: tocController,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final markdownScrollable = find.byType(Scrollable).last;
    final scrollableState = tester.state<ScrollableState>(markdownScrollable);
    expect(scrollableState.position.pixels, 0);

    await tester.tap(find.text('目标标题').first);
    await tester.pumpAndSettle();

    expect(scrollableState.position.pixels, greaterThan(0));
  });

  testWidgets('MarkdownViewer reports scroll changes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    final filler = List.filled(80, '正文内容').join('\n\n');
    double? reportedOffset;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MarkdownViewer(
              data: '# 开头\n\n$filler',
              onScrollChanged: (offset) {
                reportedOffset = offset;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(reportedOffset, isNotNull);
    expect(reportedOffset!, greaterThan(0));
  });

  test('TabManager removes a recent file entry without deleting file', () async {
    final tempDir = await Directory.systemTemp.createTemp('markdown_app_recent_');
    try {
    final file = File('${tempDir.path}${Platform.pathSeparator}recent.md');
    await file.writeAsString('# Recent');

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    await storageService.addRecentFile(file.path);
    final tabManager = TabManager(FileService(), storageService);

    await tabManager.removeRecentFile(file.path);

    expect(storageService.getRecentFiles(), isEmpty);
    expect(await file.exists(), isTrue);
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  testWidgets('TocPanel still scrolls after switching markdown documents', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    final filler = List.filled(40, '正文内容').join('\n\n');
    final firstMarkdown = '# 第一篇\n\n$filler\n\n## 第一目标\n\n目标内容';
    final secondMarkdown = '# 第二篇\n\n$filler\n\n## 第二目标\n\n目标内容';

    Future<void> pumpMarkdown(String markdown, TocController tocController) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(storageService),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  TocPanel(
                    key: ValueKey('toc-$markdown'),
                    markdownData: markdown,
                    tocController: tocController,
                  ),
                  Expanded(
                    child: MarkdownViewer(
                      key: ValueKey(markdown),
                      data: markdown,
                      tocController: tocController,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpMarkdown(firstMarkdown, TocController());
    await pumpMarkdown(secondMarkdown, TocController());

    final markdownScrollable = find.byType(Scrollable).last;
    final scrollableState = tester.state<ScrollableState>(markdownScrollable);
    expect(scrollableState.position.pixels, 0);

    await tester.tap(find.text('第二目标').first);
    await tester.pumpAndSettle();

    expect(scrollableState.position.pixels, greaterThan(0));
  });

  test('parseHeadings extracts levels and titles from markdown', () {
    const data = r'''
# 一级标题
一些内容
## 二级标题
### 三级标题
#### 四级标题
##### 五级标题
###### 六级标题
''';

    final headings = parseHeadings(data);
    expect(headings, hasLength(6));
    expect(headings[0].level, 1);
    expect(headings[0].title, '一级标题');
    expect(headings[1].level, 2);
    expect(headings[1].title, '二级标题');
    expect(headings[2].level, 3);
    expect(headings[2].title, '三级标题');
    expect(headings[5].level, 6);
    expect(headings[5].title, '六级标题');
  });

  test('parseHeadings ignores headings inside fenced code blocks', () {
    const data = r'''
# 正文标题

```dart
# 代码块里的伪标题
```

## 下一个正文标题
''';

    final headings = parseHeadings(data);

    expect(headings.map((heading) => heading.title), [
      '正文标题',
      '下一个正文标题',
    ]);
  });

  testWidgets('MarkdownViewer keeps adjacent currency lines as plain text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();

    const markdown = '价格 \$5\n成本 \$10';

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MarkdownViewer(data: markdown)),
        ),
      ),
    );

    expect(find.byType(Math), findsNothing);
    expect(find.textContaining('成本'), findsOneWidget);
  });

  testWidgets('MarkdownViewer does not leak pipe tokens in latex fallback', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();

    const markdown = r'| a | $\foo{|}$ |';

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MarkdownViewer(data: markdown)),
        ),
      ),
    );

    expect(find.textContaining('@@LATEX_PIPE@@'), findsNothing);
  });

  testWidgets('MarkdownViewer survives hand-written mermaid tags', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: MarkdownViewer(data: '前文 <mermaid>方案图</mermaid> 后文'),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('方案图'), findsOneWidget);
  });

  testWidgets('MarkdownViewer keeps mixed text and block latex content', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MarkdownViewer(data: r'前文 $$x+1$$ 后文')),
        ),
      ),
    );

    expect(find.textContaining('前文'), findsOneWidget);
    expect(find.textContaining('后文'), findsOneWidget);
    // 块级公式按断行点拆分后可能产生多个 Math 片段
    expect(find.byType(Math), findsWidgets);
  });

  testWidgets('HomeScreen renders without tabs on narrow window with toc', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    await storageService.saveReadingSession(const ReadingSession(showToc: true));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storageService),
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
          ChangeNotifierProvider(
            create: (_) => TabManager(FileService(), storageService),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HomeScreen compact tier collapses secondary actions into menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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

    // 窄屏:次要操作(快速打开/字号/主题)全部收进溢出菜单
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode), findsNothing);
    expect(find.byIcon(Icons.file_open), findsNothing);

    // 菜单里的字号调节生效
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('放大字号'), findsOneWidget);

    final before = settings.fontSize;
    await tester.tap(find.text('放大字号'));
    await tester.pumpAndSettle();
    expect(settings.fontSize, before + 2);
  });

  testWidgets('HomeScreen binds ctrl+shift+= and numpad zoom shortcuts', (
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

    expect(hasActivator(LogicalKeyboardKey.equal, shift: true), isTrue);
    expect(hasActivator(LogicalKeyboardKey.numpadAdd), isTrue);
    expect(hasActivator(LogicalKeyboardKey.numpadSubtract), isTrue);

    final zoomInBinding = bindings.entries
        .singleWhere(
          (entry) =>
              entry.key is SingleActivator &&
              (entry.key as SingleActivator).trigger ==
                  LogicalKeyboardKey.equal &&
              (entry.key as SingleActivator).control &&
              (entry.key as SingleActivator).shift,
        )
        .value;

    final before = settings.fontSize;
    zoomInBinding();
    expect(settings.fontSize, before + 2);
  });

  testWidgets('MarkdownViewer ignores horizontal math scroll for progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    final filler = List.filled(60, '正文内容').join('\n\n');
    final markdown = '公式：\$${List.filled(40, 'x +').join(' ')} x\$ 结束'
        '\n\n$filler';
    double? reportedOffset;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MarkdownViewer(
              data: markdown,
              onScrollChanged: (offset) => reportedOffset = offset,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(SingleChildScrollView).first,
        const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(reportedOffset ?? 0, lessThan(1.0));

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(reportedOffset, isNotNull);
    expect(reportedOffset!, greaterThan(0));
  });

  testWidgets('MarkdownViewer keeps code block font size with reader setting', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'font_size': 22.0});
    final storageService = await StorageService.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MarkdownViewer(data: '```dart\nint sum = 0;\n```')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final richTextFinder = find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText().contains('sum'),
    );
    final codeRichText = tester.widget<RichText>(richTextFinder.first);

    // 收集代码块内全部叶子文本 span:无论是否被高亮规则命中,
    // 字号都必须跟随阅读字号(markdown_widget 对未命中 token 走
    // styleNotMatched,不传则继承环境默认 14 号,导致同行大小不一)
    final leafFontSizes = <double?>[];
    void collectLeaves(List<InlineSpan>? spans) {
      if (spans == null) return;
      for (final span in spans) {
        if (span is TextSpan) {
          if (span.children == null || span.children!.isEmpty) {
            if ((span.text ?? '').isNotEmpty) leafFontSizes.add(span.style?.fontSize);
          } else {
            collectLeaves(span.children);
          }
        }
      }
    }

    final root = codeRichText.text;
    collectLeaves(root is TextSpan ? [root] : null);
    expect(leafFontSizes, isNotEmpty);
    for (final fontSize in leafFontSizes) {
      expect(fontSize, 22.0);
    }
  });

  testWidgets('MarkdownViewer wraps long inline math inside table cells', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();

    const markdown = r'''
| 规则 | 公式 |
|------|------|
| 加法 | $T_1(n) + T_2(n) + T_3(n) = O(\max(f(n), g(n), h(n)))$ |
''';

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MarkdownViewer(data: markdown)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 单元格内的行内公式按 TeX 断行点拆为 Wrap 折行显示(列宽固定,
    // 旧实现仅横向滚动,大字号下内容被裁切不可见)
    expect(find.byType(Wrap), findsAtLeastNWidgets(1));
  });
}
