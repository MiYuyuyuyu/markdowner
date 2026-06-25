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

class MarkdownViewer extends StatefulWidget {
  final String data;
  final bool preprocessed;
  final double initialScrollOffset;
  final ValueChanged<double>? onScrollChanged;
  final TocController? tocController;

  const MarkdownViewer({
    super.key,
    required this.data,
    this.preprocessed = false,
    this.initialScrollOffset = 0,
    this.onScrollChanged,
    this.tocController,
  });

  @override
  State<MarkdownViewer> createState() => _MarkdownViewerState();
}

class _MarkdownViewerState extends State<MarkdownViewer> {
  final _scrollHostKey = GlobalKey();
  bool _initialOffsetRestored = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreInitialOffset();
    });
  }

  @override
  void didUpdateWidget(MarkdownViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _initialOffsetRestored = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreInitialOffset();
      });
    }
  }

  void _restoreInitialOffset() {
    if (!mounted || _initialOffsetRestored || widget.initialScrollOffset <= 0) {
      return;
    }
    final position = _findScrollablePosition(_scrollHostKey.currentContext);
    if (position == null || !position.hasPixels || position.maxScrollExtent <= 0) {
      return;
    }
    _initialOffsetRestored = true;
    position.jumpTo(widget.initialScrollOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    ));
  }

  ScrollPosition? _findScrollablePosition(BuildContext? context) {
    if (context == null) return null;
    ScrollPosition? result;

    void visitor(Element element) {
      if (result != null) return;
      if (element.widget is Scrollable) {
        final state = (element as StatefulElement).state;
        if (state is ScrollableState) {
          result = state.position;
          return;
        }
      }
      element.visitChildElements(visitor);
    }

    (context as Element).visitChildElements(visitor);
    return result;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    widget.onScrollChanged?.call(notification.metrics.pixels);
    return false;
  }

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

    final mermaidData = widget.preprocessed ? widget.data : normalizeMermaidBlocks(widget.data);
    final processedData = widget.preprocessed ? widget.data : normalizeMarkdownForParsing(mermaidData);

    final providers = extractMermaidImageProviders(mermaidData);
    if (providers.isNotEmpty && !Platform.environment.containsKey('FLUTTER_TEST')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final provider in providers) {
          precacheImage(provider, context);
        }
      });
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: KeyedSubtree(
        key: _scrollHostKey,
        child: MarkdownWidget(
          data: processedData,
          padding: const EdgeInsets.all(24),
          selectable: true,
          config: config,
          tocController: widget.tocController,
          markdownGenerator: MarkdownGenerator(
            generators: [latexGenerator, mermaidGenerator],
            inlineSyntaxList: [LatexSyntax(), MermaidSyntax()],
            richTextBuilder: _buildMarkdownBlock,
          ),
        ),
      ),
    );
  }
}
