import 'package:flutter/material.dart';

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

final _headingRegex = RegExp(r'^(#{1,6})\s+(.+)$', multiLine: true);

List<HeadingItem> parseHeadings(String markdown) {
  final headings = <HeadingItem>[];
  var lineIndex = 0;

  for (final line in markdown.split('\n')) {
    final match = _headingRegex.firstMatch(line);
    if (match != null) {
      headings.add(HeadingItem(
        level: match.group(1)!.length,
        title: match.group(2)!.trim(),
        lineIndex: lineIndex,
      ));
    }
    lineIndex++;
  }

  return headings;
}

class TocPanel extends StatelessWidget {
  final String markdownData;
  final ValueChanged<int>? onHeadingTap;
  final VoidCallback? onClose;

  const TocPanel({
    super.key,
    required this.markdownData,
    this.onHeadingTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final headings = parseHeadings(markdownData);

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
          Expanded(child: _buildHeadingList(context, headings, colorScheme)),
        ],
      ),
    );
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
          if (onClose != null)
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                onPressed: onClose,
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: headings.length,
      itemBuilder: (context, index) => _buildHeadingItem(
        context,
        headings[index],
        colorScheme,
      ),
    );
  }

  Widget _buildHeadingItem(
    BuildContext context,
    HeadingItem heading,
    ColorScheme colorScheme,
  ) {
    final indent = (heading.level - 1) * 16.0;

    return InkWell(
      onTap: () => onHeadingTap?.call(heading.lineIndex),
      child: Container(
        padding: EdgeInsets.only(
          left: 12 + indent,
          right: 12,
          top: 6,
          bottom: 6,
        ),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Colors.transparent,
              width: 2,
            ),
          ),
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
