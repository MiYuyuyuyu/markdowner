import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import 'markdown_preprocessor.dart';

const _latexTag = 'latex';

SpanNodeGeneratorWithTag latexGenerator = SpanNodeGeneratorWithTag(
  tag: _latexTag,
  generator: (e, config, visitor) =>
      LatexNode(e.attributes, e.textContent, config),
);

class LatexSyntax extends md.InlineSyntax {
  LatexSyntax() : super(r'(\$\$[^\$]+\$\$)|(\$[^\$]+\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final matchValue = match.input.substring(match.start, match.end);
    String content = '';
    bool isInline = true;

    if (matchValue.startsWith('\$\$') &&
        matchValue.endsWith('\$\$') &&
        matchValue.length > 4) {
      content = matchValue.substring(2, matchValue.length - 2);
      isInline = false;
    } else if (matchValue.startsWith('\$') &&
        matchValue.endsWith('\$') &&
        matchValue.length > 2) {
      content = matchValue.substring(1, matchValue.length - 1);
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
    final style = parentStyle ?? config.p.textStyle;

    if (content.isEmpty) {
      return TextSpan(style: style, text: textContent);
    }

    final latex = Math.tex(
      content,
      mathStyle: isInline ? MathStyle.text : MathStyle.display,
      textStyle: style,
      textScaleFactor: 1,
      onErrorFallback: (error) {
        return Text(textContent, style: style.copyWith(color: Colors.red));
      },
    );

    if (isInline) {
      return WidgetSpan(child: latex, alignment: PlaceholderAlignment.middle);
    }

    return WidgetSpan(
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: latex,
      ),
    );
  }
}
