import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import 'latex_support.dart';
import 'markdown_preprocessor.dart';
import 'markdown_render_keys.dart';
import 'mermaid_support.dart';

List<InlineSpan> _flattenVisibleContent(InlineSpan span) {
  if (span is WidgetSpan) {
    return [span];
  }

  if (span is! TextSpan) {
    return [span];
  }

  final flattened = <InlineSpan>[];
  final text = span.text ?? '';
  if (text.trim().isNotEmpty) {
    flattened.add(span);
    return flattened;
  }

  for (final child in span.children ?? const <InlineSpan>[]) {
    flattened.addAll(_flattenVisibleContent(child));
  }

  return flattened;
}

WidgetSpan? _extractSingleWidgetSpan(InlineSpan span) {
  final flattened = _flattenVisibleContent(span);
  if (flattened.length == 1 && flattened.single is WidgetSpan) {
    final widgetSpan = flattened.single as WidgetSpan;
    final childKey = widgetSpan.child.key;
    if (childKey == tableWrapperKey || childKey == blockLatexKey) {
      return widgetSpan;
    }
  }

  return null;
}

Widget _buildMarkdownBlock(InlineSpan span) {
  final widgetSpan = _extractSingleWidgetSpan(span);
  if (widgetSpan != null) {
    return widgetSpan.child;
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
        defaultColumnWidth: const FlexColumnWidth(),
        headerStyle: baseStyle.copyWith(fontWeight: FontWeight.w700),
        bodyStyle: baseStyle,
        wrapper: (table) => LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            key: tableWrapperKey,
            width: constraints.hasBoundedWidth
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width,
            child: table,
          ),
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

    final mermaidData = normalizeMermaidBlocks(data);
    final processedData = normalizeMarkdownForParsing(mermaidData);

    final providers = extractMermaidImageProviders(mermaidData);
    if (providers.isNotEmpty && !Platform.environment.containsKey('FLUTTER_TEST')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final provider in providers) {
          precacheImage(provider, context);
        }
      });
    }

    return MarkdownWidget(
      data: processedData,
      padding: const EdgeInsets.all(24),
      selectable: true,
      config: config,
      markdownGenerator: MarkdownGenerator(
        generators: [latexGenerator, mermaidGenerator],
        inlineSyntaxList: [LatexSyntax(), MermaidSyntax()],
        richTextBuilder: _buildMarkdownBlock,
      ),
    );
  }
}
