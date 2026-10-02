import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_app/widgets/markdown/mermaid_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('decodeMermaidCode', () {
    test('base64Url 往返', () {
      const code = 'graph TD\n    A["第2章(上)"] --> B';
      final encoded = base64Url.encode(utf8.encode(code));
      expect(decodeMermaidCode(encoded), code);
    });

    test('非法输入返回 null', () {
      expect(decodeMermaidCode('!!!!不是base64!!!!'), isNull);
      expect(decodeMermaidCode(base64Url.encode(utf8.encode('   '))), isNull);
    });
  });

  group('encodeMermaidJsParam', () {
    test('单引号被补编码,可直接内插进 JS 单引号字符串', () {
      const code = '''
flowchart TD
    A["It's ok"] --> B{C}''';
      final param = encodeMermaidJsParam(code);
      // 生成的是合法 JS 字面量:参数内不能出现裸单引号,
      // 即下一个引号序列必须恰好在参数串结束处(', ' 分隔符)
      final script = "renderMermaid('$param', 'default', '#ffffff');";
      final inner = script.substring("renderMermaid('".length);
      expect(inner.indexOf("', '"), param.length);
    });

    test('decodeURIComponent 可还原原文(含单引号与反斜杠)', () {
      const code = r'''A-->|'x\ny'|B''';
      final param = encodeMermaidJsParam(code);
      final restored = Uri.decodeComponent(param);
      expect(restored, code);
    });
  });

  group('mermaid.html 资产', () {
    test('包含内嵌渲染与全屏矢量查看两个入口', () async {
      final html = await rootBundle.loadString('assets/mermaid/mermaid.html');
      // 内嵌模式:宽度自适应 + 高度上报
      expect(html, contains('renderMermaid'));
      expect(html, contains('ResizeObserver'));
      // 全屏查看模式:自然尺寸矢量渲染 + JS 平移/缩放
      expect(html, contains('renderMermaidZoom'));
      expect(html, contains('zoomReady'));
      expect(html, contains('pointermove'));
      expect(html, contains('wheel'));
      // 消息桥兼容双平台
      expect(html, contains('window.chrome.webview.postMessage'));
      expect(html, contains('FlutterMermaidChannel'));
      // 共享同一份 mermaid.min.js
      expect(html, contains('<script src="mermaid.min.js"></script>'));
    });
  });
}
