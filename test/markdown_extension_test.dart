import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_app/providers/settings_provider.dart';
import 'package:markdown_app/services/storage_service.dart';
import 'package:markdown_app/widgets/markdown/markdown_viewer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

Widget _wrap(StorageService storageService, Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SettingsProvider(storageService)),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

Future<StorageService> _initStorage() async {
  SharedPreferences.setMockInitialValues({});
  return StorageService.init();
}

/// 等待真实图片解码完成(测试环境的编解码器初始化较慢,需轮询)
Future<void> _pumpUntilImageDecoded(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    if (tester.getSize(find.byType(Image).first).width > 0) return;
  }
}

void main() {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  testWidgets('GitHub note alert renders styled box with label and content', (
    tester,
  ) async {
    final storageService = await _initStorage();
    const markdown = '> [!NOTE]\n> GitHub 风格提示内容测试';

    await tester.pumpWidget(
      _wrap(storageService, const MarkdownViewer(data: markdown)),
    );
    await tester.pumpAndSettle();

    expect(find.text('注意'), findsOneWidget);
    expect(find.textContaining('GitHub 风格提示内容测试'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets('GitHub warning alert maps to warning label and icon', (
    tester,
  ) async {
    final storageService = await _initStorage();
    const markdown = '> [!WARNING]\n> 危险操作提醒';

    await tester.pumpWidget(
      _wrap(storageService, const MarkdownViewer(data: markdown)),
    );
    await tester.pumpAndSettle();

    expect(find.text('警告'), findsOneWidget);
    expect(find.textContaining('危险操作提醒'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('alert content keeps inline markdown rendering', (tester) async {
    final storageService = await _initStorage();
    const markdown = '> [!TIP]\n> 包含 **加粗** 与 `代码` 的建议';

    await tester.pumpWidget(
      _wrap(storageService, const MarkdownViewer(data: markdown)),
    );
    await tester.pumpAndSettle();

    expect(find.text('建议'), findsOneWidget);
    expect(find.textContaining('加粗'), findsOneWidget);
  });

  testWidgets('emoji short codes render as characters', (tester) async {
    final storageService = await _initStorage();
    const markdown = '心情 :+1: 极佳 :smile:';

    await tester.pumpWidget(
      _wrap(storageService, const MarkdownViewer(data: markdown)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('👍'), findsOneWidget);
    expect(find.textContaining('😄'), findsOneWidget);
  });

  testWidgets('code block copy button copies code to clipboard', (
    tester,
  ) async {
    final storageService = await _initStorage();
    const markdown = '```dart\nprint("hi");\n```';

    final clipboardCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardCalls.add(call);
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      _wrap(storageService, const MarkdownViewer(data: markdown)),
    );
    await tester.pumpAndSettle();

    expect(find.text('复制'), findsOneWidget);
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();

    expect(clipboardCalls, hasLength(1));
    expect(
      ((clipboardCalls.first.arguments as Map)['text'] as String).trim(),
      'print("hi");',
    );
    expect(find.text('已复制'), findsOneWidget);

    // 冲掉"已复制"2 秒复位定时器
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('复制'), findsOneWidget);
  });

  testWidgets('image renders and opens fullscreen viewer on tap', (
    tester,
  ) async {
    final storageService = await _initStorage();
    // 使用本地真实 PNG(1x1 像素)。
    // 注意:testWidgets 是 FakeAsync zone,必须用同步 IO,否则真实异步永不完成。
    final tempDir = Directory.systemTemp.createTempSync('markdown_app_img_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final imagePath = '${tempDir.path.replaceAll('\\', '/')}/sample.png';
    File(imagePath).writeAsBytesSync(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    ));
    final markdown = '![示例]($imagePath)';

    // 有界 pump:图片解码是真实异步,不能用 pumpAndSettle 死等
    await tester.pumpWidget(
      _wrap(storageService, MarkdownViewer(data: markdown)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(Image), findsOneWidget);

    // 图片解码是真实异步,轮询等待完成,否则渲染尺寸为 0 无法命中点击
    await _pumpUntilImageDecoded(tester);

    await tester.tap(find.byType(Image).first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets(r'inline \( \) delimiters render as math', (tester) async {
    final storageService = await _initStorage();
    const markdown = r'质能方程 \(E=mc^2\) 很有名';

    await tester.pumpWidget(
      _wrap(storageService, const MarkdownViewer(data: markdown)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Math), findsOneWidget);
    expect(find.textContaining(r'\('), findsNothing);
  });

  testWidgets(r'block \[ \] delimiters render as display math', (tester) async {
    final storageService = await _initStorage();
    const markdown = r'''
前文说明:

\[
x = a | b
\]

后文说明:
''';

    await tester.pumpWidget(
      _wrap(storageService, const MarkdownViewer(data: markdown)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Math), findsWidgets);
    expect(find.textContaining('@@LATEX_PIPE@@'), findsNothing);
    expect(find.textContaining('前文说明'), findsOneWidget);
    expect(find.textContaining('后文说明'), findsOneWidget);
  });

  testWidgets('long block formula breaks into wrap layout', (tester) async {
    final storageService = await _initStorage();
    final terms = List.generate(20, (i) => 'a_{$i}').join(' + ');
    final markdown = '\$\$\n$terms + 1\n\$\$';

    await tester.pumpWidget(
      _wrap(storageService, MarkdownViewer(data: markdown)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Wrap), findsOneWidget);
    expect(find.byType(Math), findsWidgets);
  });

  testWidgets('block formula wraps at operator break points', (tester) async {
    final storageService = await _initStorage();
    const markdown = '\$\$\nx^2 + y^2 = z^2\n\$\$';

    await tester.pumpWidget(
      _wrap(storageService, const MarkdownViewer(data: markdown)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 等号/加号是合法断行点,texBreak 会拆分为多个 Math 片段并用 Wrap 布局
    expect(find.byType(Wrap), findsOneWidget);
    expect(find.byType(Math), findsWidgets);
  });

  testWidgets('formula without break points keeps centered scrollable layout', (
    tester,
  ) async {
    final storageService = await _initStorage();
    const markdown = '\$\$\n\\frac{a}{b}\n\$\$';

    await tester.pumpWidget(
      _wrap(storageService, const MarkdownViewer(data: markdown)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsWidgets);
    expect(find.byType(Wrap), findsNothing);
  });

  testWidgets('wide table wraps content without crash (FlexColumnWidth)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final storageService = await _initStorage();
    const markdown = '''
| 列一 | 列二 | 列三 | 列四 | 列五 |
|------|------|------|------|------|
| 这是很长的内容一 | 这是很长的内容二 | 这是很长的内容三 | 这是很长的内容四 | 这是很长的内容五 |
''';

    await tester.pumpWidget(
      _wrap(storageService, const MarkdownViewer(data: markdown)),
    );
    await tester.pumpAndSettle();

    // IntrinsicColumnWidth 会对含公式的单元格做固有测量并崩溃
    // (公式重音符号内部含 LayoutBuilder),因此表格必须使用 FlexColumnWidth
    expect(tester.takeException(), isNull);
    final table = tester.widget<Table>(find.byType(Table));
    expect(table.defaultColumnWidth, isA<FlexColumnWidth>());
  });

  testWidgets('narrow table still fills available width', (tester) async {
    tester.view.physicalSize = const Size(1900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final storageService = await _initStorage();
    const markdown = '''
| 性质 | 定义 |
|------|------|
| 有界 | 存在 M |
''';

    await tester.pumpWidget(
      _wrap(storageService, const MarkdownViewer(data: markdown)),
    );
    await tester.pumpAndSettle();

    final wrapperSize =
        tester.getSize(find.byKey(const ValueKey('markdown-table-wrapper')));
    expect(wrapperSize.width, greaterThan(1800));
    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('markdown-table-wrapper')),
            matching: find.byType(Scrollable),
          ).first,
        )
        .position;
    expect(position.maxScrollExtent, 0);
  });
}
