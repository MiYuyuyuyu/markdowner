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
