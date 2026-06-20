import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_app/theme/app_theme.dart';
import 'package:markdown_app/providers/settings_provider.dart';
import 'package:markdown_app/widgets/markdown/markdown_viewer.dart';
import 'package:markdown_app/widgets/welcome/welcome_page.dart';
import 'package:provider/provider.dart';
import 'package:markdown_app/providers/tab_manager.dart';
import 'package:markdown_app/services/file_service.dart';
import 'package:markdown_app/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

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
}
