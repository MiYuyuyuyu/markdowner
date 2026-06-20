import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'latex_support.dart';

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

    return MarkdownWidget(
      data: data,
      padding: const EdgeInsets.all(24),
      selectable: true,
      config: isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig,
      markdownGenerator: MarkdownGenerator(
        generators: [latexGenerator],
        inlineSyntaxList: [LatexSyntax()],
      ),
    );
  }
}
