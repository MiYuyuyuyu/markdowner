import 'dart:convert';

const latexPipeToken = '@@LATEX_PIPE@@';

final _mermaidBlockRegex = RegExp(
  r'```mermaid\s*\n(.*?)\n\s*```',
  dotAll: true,
);

String normalizeMermaidBlocks(String data) {
  return data.replaceAllMapped(_mermaidBlockRegex, (match) {
    final code = match.group(1)!.trim();
    final encoded = base64Url.encode(utf8.encode(code));
    return '<mermaid>$encoded</mermaid>';
  });
}

String preprocessMarkdownData(String rawData) {
  return normalizeMarkdownForParsing(normalizeMermaidBlocks(rawData));
}

String normalizeMarkdownForParsing(String data) {
  final buffer = StringBuffer();
  var index = 0;
  var inInlineMath = false;
  var inBlockMath = false;

  while (index < data.length) {
    final current = data[index];
    final next = index + 1 < data.length ? data[index + 1] : '';

    if (current == r'$' && next == r'$') {
      inBlockMath = !inBlockMath;
      buffer.write(r'$$');
      index += 2;
      continue;
    }

    if (current == r'$' && !inBlockMath) {
      inInlineMath = !inInlineMath;
      buffer.write(r'$');
      index++;
      continue;
    }

    if (current == '|' && (inInlineMath || inBlockMath)) {
      buffer.write(latexPipeToken);
      index++;
      continue;
    }

    buffer.write(current);
    index++;
  }

  return buffer.toString();
}
