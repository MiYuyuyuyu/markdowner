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

final _fenceOpenerRegex = RegExp(r'^ {0,3}(`{3,}|~{3,})');

String? _fenceOpener(String line) {
  final match = _fenceOpenerRegex.firstMatch(line);
  if (match == null) return null;
  final run = match.group(1)!;
  // 围栏信息串里不允许出现同类型围栏符,出现即视为行内代码而非围栏
  final infoString = line.substring(match.end);
  if (infoString.contains(run[0] * 3)) return null;
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

int _runLength(String line, int start, String char) {
  var end = start;
  while (end < line.length && line[end] == char) {
    end++;
  }
  return end - start;
}

int? _findClosingRun(String line, int from, String char, int length) {
  var index = from;
  while (index <= line.length - length) {
    if (line[index] == char) {
      final run = _runLength(line, index, char);
      if (run == length) return index;
      index += run;
      continue;
    }
    index++;
  }
  return null;
}

/// 返回处理后的文本,以及是否在本行结束时仍处于块公式内。
(String, bool) _processBlockMathLine(String line, bool inBlockMath) {
  final buffer = StringBuffer();
  var index = 0;
  var inside = inBlockMath;
  while (index < line.length) {
    if (line.startsWith(r'$$', index)) {
      inside = !inside;
      buffer.write(r'$$');
      index += 2;
      continue;
    }
    if (inside && line[index] == '|') {
      buffer.write(latexPipeToken);
      index++;
      continue;
    }
    buffer.write(line[index]);
    index++;
  }
  return (buffer.toString(), inside);
}

/// 返回处理后的文本,以及是否在本行结束时仍处于块公式内。
(String, bool) _processNormalLine(String line) {
  final buffer = StringBuffer();
  var index = 0;
  var inInlineMath = false;
  var inBlockMath = false;
  final leadingWhitespaceEnd =
      line.length - line.trimLeft().length;

  while (index < line.length) {
    final current = line[index];

    // 反斜杠转义:原样透传,不触发任何公式状态
    if (current == '\\') {
      buffer.write(current);
      if (index + 1 < line.length) buffer.write(line[index + 1]);
      index += 2;
      continue;
    }

    // 行内代码:整体原样保留,其中的 $ 与 | 不参与公式状态
    if (!inInlineMath && !inBlockMath && current == '`') {
      final runLength = _runLength(line, index, '`');
      final close = _findClosingRun(line, index + runLength, '`', runLength);
      if (close != null) {
        final end = close + runLength;
        buffer.write(line.substring(index, end));
        index = end;
      } else {
        buffer.write(line.substring(index, index + runLength));
        index += runLength;
      }
      continue;
    }

    if (current == r'$') {
      final isDouble = index + 1 < line.length && line[index + 1] == r'$';
      if (isDouble) {
        // 块公式只在行首(允许前导空白)开启,避免正文中杂散的 $$ 劫持全文;
        // 关闭可以在任意位置。
        if (inBlockMath || index <= leadingWhitespaceEnd) {
          inBlockMath = !inBlockMath;
        }
        buffer.write(r'$$');
        index += 2;
        continue;
      }
      if (!inBlockMath) {
        inInlineMath = !inInlineMath;
      }
      buffer.write(current);
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

  // 行内公式不允许跨行(与 LatexSyntax 的行内正则保持一致),
  // 因此孤立的单个 $(如货币符号)不会污染后续行。
  return (buffer.toString(), inBlockMath);
}

String normalizeMarkdownForParsing(String data) {
  final out = StringBuffer();
  var inBlockMath = false;
  String? fenceOpener;

  final lines = data.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (i > 0) out.write('\n');

    if (fenceOpener != null) {
      out.write(line);
      if (_isFenceClose(line, fenceOpener)) fenceOpener = null;
      continue;
    }

    if (!inBlockMath) {
      final opener = _fenceOpener(line);
      if (opener != null) {
        fenceOpener = opener;
        out.write(line);
        continue;
      }
    }

    if (inBlockMath) {
      final (processed, stillInBlockMath) = _processBlockMathLine(line, true);
      out.write(processed);
      inBlockMath = stillInBlockMath;
      continue;
    }

    final (processed, stillInBlockMath) = _processNormalLine(line);
    out.write(processed);
    inBlockMath = stillInBlockMath;
  }

  return out.toString();
}
