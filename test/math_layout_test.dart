import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_app/providers/settings_provider.dart';
import 'package:markdown_app/services/storage_service.dart';
import 'package:markdown_app/widgets/markdown/markdown_viewer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// 复现用户日志中的 flutter_math_fork 布局断言:
/// RenderResetDimension does not meet its constraints
/// (含分式的公式,用户字号 14,height 1.6)
void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  Future<SettingsProvider> pumpViewer(
    WidgetTester tester,
    String markdown,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    final settings = SettingsProvider(storageService);
    settings.setFontSize(14);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ],
        child: MaterialApp(
          home: Scaffold(body: MarkdownViewer(data: markdown)),
        ),
      ),
    );
    return settings;
  }

  testWidgets('block frac math renders without layout assertion', (
    tester,
  ) async {
    await pumpViewer(
      tester,
      r'''
$$\frac{+13}{0\;0001101}$$

$$\frac{1}{2}$$

$$x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}$$

$$0.1\mathrm{M} \times 2^{-126}$$

$$\sum_{i=1}^{n} a_i \cdot \bar{x} + \hat{y}$$

$$\frac{\frac{1}{2}}{\frac{3}{4}} \pm \frac{\bar{x}}{\sqrt{2}}$$

$$N \le 2^k - 1,\quad 2^k \ge n + k + 1$$

$$[-13]_{补} = 1\;1110011$$
''',
    );

    Object? exception;
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      exception ??= tester.takeException();
    }
    // ignore: avoid_print
    print('MATH PROBE exception: $exception');
    expect(exception, isNull);
  });

  testWidgets('inline frac math renders without layout assertion', (
    tester,
  ) async {
    await pumpViewer(
      tester,
      r'行内公式 $\frac{1}{2}$ 与 $f(x) = \frac{x^2}{x-1}$ 混排文本。'
      r'重音 $\bar{x}_1$、$\hat{y}$、$\bar{x} \pm \hat{z}$、'
      r'$\frac{\bar{x}}{2}$、补码 $[-13]_{补}$、浮点 $0.1\mathrm{M} \times 2^{-126}$。',
    );

    Object? exception;
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      exception ??= tester.takeException();
    }
    // ignore: avoid_print
    print('MATH PROBE inline exception: $exception');
    expect(exception, isNull);
  });
}
