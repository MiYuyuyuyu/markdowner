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

List<HeadingItem> parseHeadings(String markdown) {
  final headings = <HeadingItem>[];
  var lineIndex = 0;
  String? fenceOpener;

  for (final line in markdown.split('\n')) {
    if (fenceOpener != null) {
      if (_isFenceClose(line, fenceOpener)) fenceOpener = null;
    } else {
      final opener = _fenceOpenerOf(line);
      if (opener != null) {
        fenceOpener = opener;
      } else {
        final match = _headingRegex.firstMatch(_stripBlockquote(line));
        if (match != null) {
          headings.add(HeadingItem(
            level: match.group(1)!.length,
            title: match.group(2)!.trim(),
            lineIndex: lineIndex,
          ));
        }
      }
    }
    lineIndex++;
  }

  return headings;
}

class TocPanel extends StatefulWidget {
  final String markdownData;
  final TocController? tocController;
  final VoidCallback? onClose;

  const TocPanel({
    super.key,
    required this.markdownData,
    this.tocController,
    this.onClose,
  });

  @override
  State<TocPanel> createState() => _TocPanelState();
}

class _TocPanelState extends State<TocPanel> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final headings = parseHeadings(widget.markdownData);

    return Container(
      width: 240,
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
              width: 32,
              height: 32,
              child: IconButton(
                onPressed: widget.onClose,
                icon: Icon(Icons.close, size: 16, color: colorScheme.onSurfaceVariant),
                splashRadius: 14,
                visualDensity: VisualDensity.compact,
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
