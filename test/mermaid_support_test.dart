import 'dart:convert';
import 'dart:typed_data';

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

  group('decodeMermaidSnapshot', () {
    test('解析 PNG dataURL', () {
      final pngBytes = Uint8List.fromList([1, 2, 3, 137, 80, 78, 71]);
      final dataUrl =
          'data:image/png;base64,${base64Encode(pngBytes)}';
      expect(decodeMermaidSnapshot(dataUrl), pngBytes);
    });

    test('非法格式返回 null', () {
      expect(decodeMermaidSnapshot('not-a-data-url'), isNull);
      expect(decodeMermaidSnapshot('data:image/png;base64,!!!!'), isNull);
      expect(decodeMermaidSnapshot('data:text/plain;base64,AAAA'), isNull);
    });
  });

  group('mermaid.html 资产', () {
    test('包含渲染与快照入口、双通道消息桥', () async {
      final html = await rootBundle.loadString('assets/mermaid/mermaid.html');
      expect(html, contains('renderMermaid'));
      expect(html, contains('snapshotMermaid'));
      expect(html, contains('window.chrome.webview.postMessage'));
      expect(html, contains('FlutterMermaidChannel'));
      expect(html, contains('ResizeObserver'));
      expect(html, contains('<script src="mermaid.min.js"></script>'));
    });
  });
}
