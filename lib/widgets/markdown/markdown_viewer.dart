import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import 'latex_support.dart';
import 'markdown_preprocessor.dart';

class MarkdownViewer extends StatelessWidget {
  final String data;
  final double initialScrollOffset;
  final ValueChanged<double>? onScrollChanged;

  const MarkdownViewer({
    super.key,
    required this.data,
    this.initialScrollOffset = 0,
    this.onScrollChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    final fontStyle = TextStyle(fontSize: settings.fontSize, height: 1.6);
    final config =
        (isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig)
            .copy(
              configs: [
                PConfig(textStyle: fontStyle),
                TableConfig(
                  headerStyle: fontStyle.copyWith(fontWeight: FontWeight.w700),
                  bodyStyle: fontStyle,
                ),
              ],
            );

    return MarkdownWidget(
      data: normalizeMarkdownForParsing(data),
      padding: const EdgeInsets.all(24),
      selectable: true,
      config: config,
      markdownGenerator: MarkdownGenerator(
        generators: [latexGenerator],
        inlineSyntaxList: [LatexSyntax()],
      ),
    );
  }
}
