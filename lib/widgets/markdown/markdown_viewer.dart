import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import 'latex_support.dart';
import 'markdown_preprocessor.dart';

WidgetSpan? _extractSingleWidgetSpan(InlineSpan span) {
  if (span is WidgetSpan) {
    return span;
  }

  if (span is! TextSpan) {
    return null;
  }

  if ((span.text ?? '').isNotEmpty) {
    return null;
  }

  final children = span.children;
  if (children == null || children.length != 1) {
    return null;
  }

  return _extractSingleWidgetSpan(children.single);
}

bool _containsWidgetSpan(InlineSpan span) {
  if (span is WidgetSpan) {
    return true;
  }

  if (span is! TextSpan) {
    return false;
  }

  final children = span.children;
  if (children == null || children.isEmpty) {
    return false;
  }

  return children.any(_containsWidgetSpan);
}

Widget _buildMarkdownBlock(InlineSpan span) {
  final widgetSpan = _extractSingleWidgetSpan(span);
  if (widgetSpan != null) {
    return widgetSpan.child;
  }

  if (_containsWidgetSpan(span)) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text.rich(span),
    );
  }

  return Text.rich(span);
}

double _scaledHeadingSize(double bodySize, double defaultHeadingSize) {
  return bodySize * (defaultHeadingSize / 16);
}

MarkdownConfig _buildMarkdownConfig({
  required bool isDark,
  required TextStyle baseStyle,
}) {
  final baseConfig =
      isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;

  TextStyle headingStyle(double defaultSize) {
    return baseStyle.copyWith(
      fontSize: _scaledHeadingSize(baseStyle.fontSize!, defaultSize),
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
  }

  return baseConfig.copy(
    configs: [
      PConfig(textStyle: baseStyle),
      H1Config(style: headingStyle(32)),
      H2Config(style: headingStyle(24)),
      H3Config(style: headingStyle(20)),
      H4Config(style: headingStyle(16)),
      H5Config(style: headingStyle(16)),
      H6Config(style: headingStyle(16)),
      PreConfig(textStyle: baseStyle),
      TableConfig(
        headerStyle: baseStyle.copyWith(fontWeight: FontWeight.w700),
        bodyStyle: baseStyle,
        wrapper: (table) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: table,
        ),
      ),
    ],
  );
}

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
    final themeStyle = Theme.of(context).textTheme.bodyMedium;
    final fontStyle = (themeStyle ?? const TextStyle()).copyWith(
      fontSize: settings.fontSize,
      height: 1.6,
    );
    final config = _buildMarkdownConfig(
      isDark: isDark,
      baseStyle: fontStyle,
    );

    return MarkdownWidget(
      data: normalizeMarkdownForParsing(data),
      padding: const EdgeInsets.all(24),
      selectable: true,
      config: config,
      markdownGenerator: MarkdownGenerator(
        generators: [latexGenerator],
        inlineSyntaxList: [LatexSyntax()],
        richTextBuilder: _buildMarkdownBlock,
      ),
    );
  }
}
