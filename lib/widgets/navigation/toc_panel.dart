import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

class HeadingItem {
  final int level;
  final String title;
  final int lineIndex;

  const HeadingItem({
    required this.level,
    required this.title,
    required this.lineIndex,
  });
}

final _headingRegex = RegExp(r'^ {0,3}(#{1,6})\s+(.+)$');
final _fenceOpenerRegex = RegExp(r'^ {0,3}(`{3,}|~{3,})');
final _setextH1Regex = RegExp(r'^ {0,3}=+\s*$');
final _setextH2Regex = RegExp(r'^ {0,3}-+\s*$');
final _listMarkerRegex = RegExp(r'^ {0,3}(?:[-*+]|\d{1,9}[.)])(\s|$)');
// 仅识别顶层列表项内的标题;更深嵌套的罕见写法暂不跟踪
final _listHeadingRegex =
    RegExp(r'^ {0,3}(?:[-*+]|\d{1,9}[.)])\s+(#{1,6})\s+(.+)$');

String? _fenceOpenerOf(String line) {
  final match = _fenceOpenerRegex.firstMatch(line);
  if (match == null) return null;
  final run = match.group(1)!;
  // 同一行出现闭合围栏符(如行内 ```code```)不是围栏开头
  if (line.substring(match.end).contains(run[0] * 3)) return null;
  return run;
}

bool _isFenceClose(String line, String opener) {
  final trimmed = line.trim();
  if (trimmed.length < opener.length) return false;
  final char = opener[0];
  for (final unit in trimmed.codeUnits) {
    if (unit != char.codeUnitAt(0)) return false;
  }
  return true;
}

/// 去掉 blockquote 前缀(如 "> > # 标题"),让目录与真实渲染结果一致。
/// 非 blockquote 行原样返回,保留前导空格供缩进判断。
String _stripBlockquote(String line) {
  var content = line;
  while (content.trimLeft().startsWith('>')) {
    content = content.substring(content.indexOf('>') + 1);
    if (content.startsWith(' ')) content = content.substring(1);
  }
  return content;
}

/// 解析文档标题,供目录/搜索跳转与 markdown_widget 的 TocController
/// 列表按下标对应。除 ATX(`#`)外还识别:
/// - setext 标题(`标题` 下一行 `===`/`---`),行号取段落首行;
/// - 列表项内的 ATX 标题(`- # 标题`);
/// - 引用块内的以上各形态。
/// 注意:与渲染端(markdown 包)的解析保持一致的边界,如 `---` 紧跟
/// 普通段落是 setext h2 而非分隔线、空行/列表行之后不是 setext。
List<HeadingItem> parseHeadings(String markdown) {
  final headings = <HeadingItem>[];
  var lineIndex = 0;
  String? fenceOpener;
  // setext 支持:跟踪当前普通段落(首行行号、累计文本、是否在引用块内)
  int? paragraphStartLine;
  bool paragraphInBlockquote = false;
  final paragraphTitle = StringBuffer();

  void resetParagraph() {
    paragraphStartLine = null;
    paragraphInBlockquote = false;
    paragraphTitle.clear();
  }

  for (final line in markdown.split('\n')) {
    if (fenceOpener != null) {
      if (_isFenceClose(line, fenceOpener)) fenceOpener = null;
      resetParagraph();
      lineIndex++;
      continue;
    }

    final opener = _fenceOpenerOf(line);
    if (opener != null) {
      fenceOpener = opener;
      resetParagraph();
      lineIndex++;
      continue;
    }

    final inBlockquote = line.trimLeft().startsWith('>');
    final stripped = _stripBlockquote(line);

    // 引用块内外切换会打断段落(两侧不可能构成 setext)
    if (paragraphStartLine != null &&
        inBlockquote != paragraphInBlockquote) {
      resetParagraph();
    }

    // setext 下划线:仅当紧跟同层级普通段落时成立,
    // 否则是主题分隔线/普通段落内容
    final paragraphStart = paragraphStartLine;
    if (paragraphStart != null) {
      final setextLevel = _setextH1Regex.hasMatch(stripped)
          ? 1
          : _setextH2Regex.hasMatch(stripped)
              ? 2
              : 0;
      if (setextLevel > 0) {
        headings.add(HeadingItem(
          level: setextLevel,
          title: paragraphTitle.toString(),
          lineIndex: paragraphStart,
        ));
        resetParagraph();
        lineIndex++;
        continue;
      }
    }

    final atxMatch = _headingRegex.firstMatch(stripped);
    final listMatch = atxMatch == null
        ? _listHeadingRegex.firstMatch(stripped)
        : null;
    final headingMatch = atxMatch ?? listMatch;
    if (headingMatch != null) {
      headings.add(HeadingItem(
        level: headingMatch.group(1)!.length,
        title: headingMatch.group(2)!.trim(),
        lineIndex: lineIndex,
      ));
      resetParagraph();
      lineIndex++;
      continue;
    }

    final trimmed = stripped.trim();
    if (trimmed.isEmpty || _listMarkerRegex.hasMatch(stripped)) {
      // 空行或列表行:不可能成为 setext 之前的段落内容
      resetParagraph();
    } else {
      paragraphStartLine ??= lineIndex;
      paragraphInBlockquote = inBlockquote;
      if (paragraphTitle.isNotEmpty) paragraphTitle.write(' ');
      paragraphTitle.write(trimmed);
    }
    lineIndex++;
  }

  return headings;
}

/// 找到 [lineIndex] 之前(含)最近的标题下标;没有任何更早的标题返回 -1
int nearestHeadingIndexForLine(List<HeadingItem> headings, int lineIndex) {
  var best = -1;
  for (final heading in headings) {
    if (heading.lineIndex > lineIndex) break;
    best++;
  }
  return best;
}

/// 跳转到第 [headingIndex] 个标题;目录尚未就绪(渲染未完成)时不跳转
void jumpToHeading(TocController? controller, int headingIndex) {
  final tocList = controller?.tocList;
  if (tocList == null || headingIndex < 0 || headingIndex >= tocList.length) {
    return;
  }
  try {
    controller!.jumpToIndex(tocList.elementAt(headingIndex).widgetIndex);
  } catch (_) {
    // 树已卸载(如关闭全部标签)时 scroll_to_index 内部可能抛错,忽略
  }
}

class TocPanel extends StatefulWidget {
  final String markdownData;
  final TocController? tocController;
  final VoidCallback? onClose;

  /// 面板宽度(由拖动分隔条调整,持久化于设置)
  final double width;

  const TocPanel({
    super.key,
    required this.markdownData,
    this.tocController,
    this.onClose,
    this.width = 240,
  });

  @override
  State<TocPanel> createState() => _TocPanelState();
}

class _TocPanelState extends State<TocPanel> {
  late List<HeadingItem> _headings = parseHeadings(widget.markdownData);

  @override
  void didUpdateWidget(TocPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 宽度变化等重建不需要重新解析标题
    if (oldWidget.markdownData != widget.markdownData) {
      _headings = parseHeadings(widget.markdownData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final headings = _headings;

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, colorScheme),
          const Divider(height: 1),
          Expanded(
            child: _buildHeadingList(context, headings, colorScheme),
          ),
        ],
      ),
    );
  }

  void _jumpToHeading(int headingIndex) {
    final tocList = widget.tocController?.tocList;
    if (tocList == null || headingIndex >= tocList.length) return;
    final widgetIndex = tocList.elementAt(headingIndex).widgetIndex;
    widget.tocController?.jumpToIndex(widgetIndex);
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Icon(Icons.list, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '文档目录',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          if (widget.onClose != null)
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: widget.onClose,
                icon: Icon(Icons.close, size: 18,
                    color: colorScheme.onSurfaceVariant),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeadingList(
    BuildContext context,
    List<HeadingItem> headings,
    ColorScheme colorScheme,
  ) {
    if (headings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '当前文档无标题',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final tocController = widget.tocController;
    if (tocController != null) {
      return TocWidget(controller: tocController);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: headings.length,
      itemBuilder: (context, index) => _buildHeadingItem(
        context,
        headings[index],
        index,
        colorScheme,
      ),
    );
  }

  Widget _buildHeadingItem(
    BuildContext context,
    HeadingItem heading,
    int index,
    ColorScheme colorScheme,
  ) {
    final indent = (heading.level - 1) * 16.0;

    return InkWell(
      onTap: () => _jumpToHeading(index),
      child: Container(
        padding: EdgeInsets.only(
          left: 12 + indent,
          right: 12,
          top: 6,
          bottom: 6,
        ),
        child: Text(
          heading.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: heading.level <= 2
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
            fontWeight:
                heading.level <= 1 ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
