import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import 'markdown_preprocessor.dart';
import 'markdown_render_keys.dart';

const _latexTag = 'latex';
const _inlineMathScaleFactor = 1.12;

SpanNodeGeneratorWithTag latexGenerator = SpanNodeGeneratorWithTag(
  tag: _latexTag,
  generator: (e, config, visitor) =>
      LatexNode(e.attributes, e.textContent, config),
);

class LatexSyntax extends md.InlineSyntax {
  // 行内公式不允许跨行:否则相邻行的普通文本(如含货币符号的行)会被吞进同一个坏公式。
  // 同时支持 $...$、$$...$$、\(...\)、\[...\] 四种定界符。
  LatexSyntax()
      : super(r'(\$\$[^$]+\$\$)|(\\\[[\s\S]*?\\\])|(\$[^$\n]+\$)|(\\\(.*?\\\))');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final matchValue = match.input.substring(match.start, match.end);
    String content = '';
    bool isInline = true;

    if (matchValue.startsWith(r'$$') &&
        matchValue.endsWith(r'$$') &&
        matchValue.length > 4) {
      content = matchValue.substring(2, matchValue.length - 2);
      isInline = false;
    } else if (matchValue.startsWith(r'\[') &&
        matchValue.endsWith(r'\]') &&
        matchValue.length > 4) {
      content = matchValue.substring(2, matchValue.length - 2);
      isInline = false;
    } else if (matchValue.startsWith(r'\(') &&
        matchValue.endsWith(r'\)') &&
        matchValue.length > 4) {
      content = matchValue.substring(2, matchValue.length - 2);
      isInline = true;
    } else if (matchValue.startsWith(r'$') &&
        matchValue.endsWith(r'$') &&
        matchValue.length > 2) {
      content = matchValue.substring(1, matchValue.length - 1);
      isInline = true;
    }

    final el = md.Element.text(_latexTag, matchValue);
    el.attributes['content'] = content;
    el.attributes['isInline'] = '$isInline';
    parser.addNode(el);
    return true;
  }
}

class LatexNode extends SpanNode {
  final Map<String, String> attributes;
  final String textContent;
  final MarkdownConfig config;

  LatexNode(this.attributes, this.textContent, this.config);

  @override
  InlineSpan build() {
    final content = (attributes['content'] ?? '').replaceAll(
      latexPipeToken,
      '|',
    );
    final isInline = attributes['isInline'] == 'true';
    // 紧凑列表/引用块等场景没有 p 节点,parentStyle 是 fontSize 为 null 的空样式,
    // 必须以用户正文字号兜底,否则 Math.tex 会回退到固定的默认字号。
    final style = config.p.textStyle.merge(parentStyle);
    // textContent 是未还原管道 token 的原始文本,展示前必须还原
    final displayText = textContent.replaceAll(latexPipeToken, '|');

    if (content.isEmpty) {
      return TextSpan(style: style, text: displayText);
    }

    final latex = isInline
        ? Math.tex(
            content,
            mathStyle: MathStyle.text,
            textStyle: style,
            textScaleFactor: _inlineMathScaleFactor,
            onErrorFallback: (error) => _buildErrorFallback(displayText, style),
          )
        : _buildBlockMath(content, displayText, style);

    if (isInline) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: latex,
        ),
      );
    }

    return WidgetSpan(child: latex);
  }

  /// 块级公式:优先按 TeX 断行点拆分为 Wrap 自动换行;不适用或异常时回落为横向滚动。
  Widget _buildBlockMath(
    String content,
    String displayText,
    TextStyle style,
  ) {
    final math = Math.tex(
      content,
      mathStyle: MathStyle.display,
      textStyle: style,
      onErrorFallback: (error) => _buildErrorFallback(displayText, style),
    );

    Widget child;
    try {
      final breaks = math.texBreak();
      if (breaks.parts.length > 1) {
        child = Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: breaks.parts.toList(growable: false),
        );
      } else {
        child = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: math,
        );
      }
    } catch (_) {
      child = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: math,
      );
    }

    final margin = (style.fontSize ?? 16) * 0.8;
    return Container(
      key: blockLatexKey,
      width: double.infinity,
      alignment: Alignment.center,
      margin: EdgeInsets.symmetric(vertical: margin),
      child: child,
    );
  }

  /// 解析失败兜底:圆角浅底 + 等宽字体展示原始文本,便于定位问题公式。
  Widget _buildErrorFallback(String displayText, TextStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Text(
        displayText,
        style: style.copyWith(
          color: Colors.red,
          fontFamily: 'monospace',
          fontSize: (style.fontSize ?? 16) * 0.9,
        ),
      ),
    );
  }
}
