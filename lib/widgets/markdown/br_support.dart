import 'package:markdown/markdown.dart' as md;

/// 行内换行标签(`<br>`、`<br/>`、`<br />`,大小写不敏感)→ br 元素。
///
/// markdown 包的 InlineHtmlSyntax 把行内 HTML 作为 Text 节点直通
/// (面向 HTML 输出场景),不会产生 Element('br'),markdown_widget
/// 的 BrNode(tag: 'br',渲染为换行)因此不可达,`<br />` 只能显示
/// 为字面文本;GitHub/VSCode 均按换行渲染。这里在行内语法层把
/// 换行标签转成真正的 br 元素,交由 BrNode 渲染为换行。
class BrSyntax extends md.InlineSyntax {
  BrSyntax() : super(r'<br\s*/?>', caseSensitive: false);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.empty('br'));
    return true;
  }
}
