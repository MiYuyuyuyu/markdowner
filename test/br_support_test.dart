import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_app/providers/settings_provider.dart';
import 'package:markdown_app/services/storage_service.dart';
import 'package:markdown_app/widgets/markdown/br_support.dart';
import 'package:markdown_app/widgets/markdown/markdown_viewer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// 与渲染端(markdown_viewer 的 MarkdownGenerator)一致的 Document 配置
md.Document _document() => md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
      inlineSyntaxes: [BrSyntax()],
    );

bool _containsTag(md.Node node, String tag) {
  if (node is md.Element) {
    if (node.tag == tag) return true;
    return node.children?.any((child) => _containsTag(child, tag)) ?? false;
  }
  return false;
}

Widget _viewer(StorageService storageService, String data) => MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(storageService),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: MarkdownViewer(data: data))),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // markdown_widget 用 VisibilityDetector 包裹每个块,默认 500ms
    // 上报 Timer 会在测试结束时挂起;测试中立即上报
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('BrSyntax(单元)', () {
    test('<br /> 转为 br 元素', () {
      final nodes = _document().parseLines(['a<br />b']);
      expect(_containsTag(nodes.first, 'br'), isTrue);
    });

    test('<br> 与 <BR/> 大小写不敏感', () {
      expect(
        _containsTag(_document().parseLines(['a<br>b']).first, 'br'),
        isTrue,
      );
      expect(
        _containsTag(_document().parseLines(['a<BR/>b']).first, 'br'),
        isTrue,
      );
    });

    test('行内代码中的 <br> 保持字面', () {
      final nodes = _document().parseLines(['a`<br>`b']);
      expect(_containsTag(nodes.first, 'br'), isFalse);
    });

    test('围栏代码块中的 <br> 保持字面', () {
      final nodes = _document().parseLines(['```text', '<br>', '```']);
      expect(nodes.any((node) => _containsTag(node, 'br')), isFalse);
    });
  });

  group('BrSyntax(widget)', () {
    testWidgets('表格单元格内 <br /> 渲染为换行且无字面文本', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storageService = await StorageService.init();
      await tester.pumpWidget(_viewer(
        storageService,
        '| 项目 | 内容 |\n|---|---|\n| A | 第一行<br />第二行<br>第三行 |',
      ));
      await tester.pump();

      expect(find.textContaining('<br', findRichText: true), findsNothing);
      expect(
        find.textContaining('第一行\n第二行\n第三行', findRichText: true),
        findsOneWidget,
      );
    });
  });

  group('任务列表(GFM 对齐钉住)', () {
    testWidgets('- [ ] / - [x] 渲染为勾选框,无字面标记', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storageService = await StorageService.init();
      await tester.pumpWidget(_viewer(
        storageService,
        '- [ ] 待办事项\n- [x] 已完成事项',
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('[ ]', findRichText: true), findsNothing);
      expect(find.textContaining('[x]', findRichText: true), findsNothing);
      expect(
        find.textContaining('待办事项', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('已完成事项', findRichText: true),
        findsOneWidget,
      );
    });
  });
}
