import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

/// GitHub 告警块支持(`> [!NOTE]` 等 5 种)。
///
/// markdown 包的 AlertBlockSyntax 会产出 `div.markdown-alert-<type>` 元素,
/// 因此这里以 'div' 为 tag 注册生成器;标题行(markdown-alert-title)由本节点
/// 自绘为图标+标签行,正文子节点原样渲染,从而支持告警块内嵌表格/公式等。

final _alertPattern = RegExp(r'markdown-alert-(\w+)');

const _alertMeta = <String, (IconData, String, Color)>{
  'note': (Icons.info_outline, '注意', Color(0xFF2F6FEB)),
  'tip': (Icons.lightbulb_outline, '建议', Color(0xFF1A7F37)),
  'important': (Icons.priority_high, '重要', Color(0xFF8250DF)),
  'warning': (Icons.warning_amber_rounded, '警告', Color(0xFF9A6700)),
  'caution': (Icons.report_outlined, '小心', Color(0xFFCF222E)),
};

SpanNodeGeneratorWithTag alertGenerator = SpanNodeGeneratorWithTag(
  tag: 'div',
  generator: (e, config, visitor) {
    final match = _alertPattern.firstMatch(e.attributes['class'] ?? '');
    if (match == null) return ConcreteElementNode();
    return AlertNode(match.group(1)!, visitor);
  },
);

class AlertNode extends ElementNode {
  final String type;
  final WidgetVisitor visitor;

  AlertNode(this.type, this.visitor);

  @override
  InlineSpan build() {
    final meta = _alertMeta[type] ?? _alertMeta['note']!;
    final (icon, label, color) = meta;
    // children[0] 是标题段落,已由上方图标行替代
    final contentNodes =
        children.length > 1 ? children.sublist(1) : const <SpanNode>[];

    return WidgetSpan(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            if (contentNodes.isNotEmpty) const SizedBox(height: 4),
            for (final node in contentNodes)
              visitor.richTextBuilder?.call(node.build()) ?? Text.rich(node.build()),
          ],
        ),
      ),
    );
  }
}
