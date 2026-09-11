import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_app/providers/settings_provider.dart';
import 'package:markdown_app/services/storage_service.dart';
import 'package:markdown_app/widgets/markdown/markdown_viewer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('DIAG: real 概率论知识.md renders, scrolls, no exception', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    final settings = SettingsProvider(storageService);

    final doc = File('D:/Home_Work/考研/高数/概率论知识.md').readAsStringSync();
    debugPrint('DOC LENGTH: ${doc.length}');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MarkdownViewer(data: doc),
          ),
        ),
      ),
    );

    // 分帧泵,观察首帧与后续帧的异常
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final ex = tester.takeException();
      if (ex != null) {
        debugPrint('!!! EXCEPTION AT FRAME $i: $ex');
      }
    }

    // 正文可见性:文档开头的标题应在树中
    debugPrint('H1 visible: ${find.textContaining('考研数学一').evaluate().length}');
    debugPrint(
        'mermaid imgs: ${find.byType(Image).evaluate().length}');

    // 模拟滚轮滚动
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    debugPrint('after wheel exception: ${tester.takeException()}');

    // 再滚动
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    debugPrint('after wheel2 exception: ${tester.takeException()}');
    debugPrint('content visible after scroll: ${find.textContaining('条件概率').evaluate().length}');
  });
}
