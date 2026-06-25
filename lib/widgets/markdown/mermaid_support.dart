import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_widget/markdown_widget.dart';

const _mermaidTag = 'mermaid';

SpanNodeGeneratorWithTag mermaidGenerator = SpanNodeGeneratorWithTag(
  tag: _mermaidTag,
  generator: (e, config, _) => MermaidNode(e.attributes, e.textContent),
);

class MermaidSyntax extends md.InlineSyntax {
  MermaidSyntax() : super(r'<mermaid>(.+?)</mermaid>');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final code = match.group(1)!;
    final el = md.Element.text(_mermaidTag, '');
    el.attributes['code'] = code;
    parser.addNode(el);
    return true;
  }
}

String mermaidInkUrl(String code) {
  final decoded = utf8.decode(base64Url.decode(code));
  final encoded = base64Url.encode(utf8.encode(decoded));
  return 'https://mermaid.ink/img/$encoded';
}

final _mermaidUrlRegex = RegExp(
  r'<mermaid>(.+?)</mermaid>',
  dotAll: true,
);

List<ImageProvider> extractMermaidImageProviders(String processedData) {
  return _mermaidUrlRegex
      .allMatches(processedData)
      .map((m) => NetworkImage(mermaidInkUrl(m.group(1)!)))
      .toList();
}

class MermaidNode extends SpanNode {
  final Map<String, String> attributes;
  final String textContent;

  MermaidNode(this.attributes, this.textContent);

  @override
  InlineSpan build() {
    final code = attributes['code'] ?? '';
    if (code.isEmpty) return const TextSpan(text: '');

    final url = mermaidInkUrl(code);
    final style = parentStyle;

    return WidgetSpan(
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Mermaid 图表渲染失败', style: TextStyle(color: Colors.red)),
                  ),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Mermaid',
                  style: (style ?? const TextStyle()).copyWith(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
