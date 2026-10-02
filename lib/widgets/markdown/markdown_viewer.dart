import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_widget/markdown_widget.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import 'alert_support.dart';
import 'code_block_support.dart';
import 'image_support.dart';
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
  ValueChanged<String>? onLinkTap,
  String? filePath,
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
      PreConfig(
        textStyle: baseStyle,
        wrapper: wrapCodeBlock,
      ),
      ImgConfig(
        builder: (url, attributes) =>
            buildMarkdownImage(url, attributes, basePath: filePath),
      ),
      // 覆盖默认链接行为:不接管的链接(如相对路径)会被当作系统
      // URL 打开,ShellExecute 报错且应用内无法跳转
      if (onLinkTap != null) LinkConfig(onTap: onLinkTap),
      TableConfig(
        // 注意:此处必须使用 FlexColumnWidth。
        // IntrinsicColumnWidth 会对单元格做固有尺寸测量,而公式中
        // \bar/\hat 等重音符号经 flutter_math_fork 渲染时内部含
        // LayoutBuilder(不支持 intrinsic 测量),数学笔记必崩。
        defaultColumnWidth: const FlexColumnWidth(),
        headerStyle: baseStyle.copyWith(fontWeight: FontWeight.w700),
        bodyStyle: baseStyle,
        border: TableBorder.all(
          color: isDark ? const Color(0xFF444C56) : const Color(0xFFD0D7DE),
          width: 1,
          borderRadius: BorderRadius.circular(6),
        ),
        headerRowDecoration: BoxDecoration(
          color: isDark ? const Color(0xFF2B313A) : const Color(0xFFF6F8FA),
        ),
        headPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        bodyPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        wrapper: (table) => LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            return SizedBox(
              key: tableWrapperKey,
              width: width,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: width),
                  child: table,
                ),
              ),
            );
          },
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

  /// 当前文档路径,用于把相对链接/图片解析为本地绝对路径
  final String? filePath;

  /// 链接点击回调;为 null 时保持 markdown_widget 默认行为(系统打开)
  final ValueChanged<String>? onLinkTap;

  const MarkdownViewer({
    super.key,
    required this.data,
    this.preprocessed = false,
    this.initialScrollOffset = 0,
    this.onScrollChanged,
    this.tocController,
    this.filePath,
    this.onLinkTap,
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
    // 只统计最外层的纵向滚动;行内公式等嵌套横向滚动的通知(depth > 0)
    // 不能写入阅读进度,否则横向拖动公式会污染纵向位置。
    if (notification.depth == 0) {
      widget.onScrollChanged?.call(notification.metrics.pixels);
    }
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
      onLinkTap: widget.onLinkTap,
      filePath: widget.filePath,
    );

    final mermaidData = widget.preprocessed ? widget.data : normalizeMermaidBlocks(widget.data);
    final processedData = widget.preprocessed ? widget.data : normalizeMarkdownForParsing(mermaidData);

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
            generators: [latexGenerator, mermaidGenerator, alertGenerator],
            inlineSyntaxList: [
              LatexSyntax(),
              MermaidSyntax(),
              md.EmojiSyntax(),
            ],
            blockSyntaxList: [const md.AlertBlockSyntax()],
            richTextBuilder: _buildMarkdownBlock,
          ),
        ),
      ),
    );
  }
}
