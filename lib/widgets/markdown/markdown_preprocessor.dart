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

/// [openIndex] 处的单个 $ 能否开启行内公式:行内需存在配对 $,且配对
/// 内容须"公式样"(含数字/空白之外的字符,如字母、反斜杠、括号)。
/// 仅由数字/空白/小数点/千分位/百分号/管道组成的串(如 "100 | ")更
/// 可能是价格文本——尤其要防止 "| $100 | $50 |" 把表格分隔管道当成
/// 公式内容替换掉,破坏表格结构并泄漏占位符。
bool _opensInlineMath(String line, int openIndex) {
  final closeIndex = line.indexOf(r'$', openIndex + 1);
  if (closeIndex < 0) return false;
  final content = line.substring(openIndex + 1, closeIndex);
  return content.isNotEmpty && !_priceLikePattern.hasMatch(content);
}

final _priceLikePattern = RegExp(r'^[\s\d.,|%]+$');

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
    // \] 结束 \[ 开启的块公式
    if (line.startsWith(r'\]', index) && inside) {
      inside = false;
      buffer.write(r'\]');
      index += 2;
      continue;
    }
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

    // 反斜杠转义:原样透传。其中 \( \) \[ \] 是公式定界符,参与公式状态切换
    if (current == '\\') {
      final nextChar = index + 1 < line.length ? line[index + 1] : '';
      switch (nextChar) {
        case '(':
          inInlineMath = true;
        case ')':
          inInlineMath = false;
        case '[':
          if (!inBlockMath) inBlockMath = true;
        case ']':
          if (inBlockMath) inBlockMath = false;
      }
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
        if (inBlockMath) {
          // 块公式内:$$ 关闭
          inBlockMath = false;
          buffer.write(r'$$');
          index += 2;
          continue;
        }
        final closeIdx = line.indexOf(r'$$', index + 2);
        if (index <= leadingWhitespaceEnd || closeIdx >= 0) {
          // 行首开启(可跨行)或行中自包含($$...$$ 在同一行闭合):
          // 内容中的 | 保护为 token。自包含不改变全局块状态;
          // 行首且未在同行闭合时开启跨行块公式。
          final end = closeIdx >= 0 ? closeIdx + 2 : line.length;
          for (var i = index; i < end; i++) {
            if (line[i] == '|') {
              buffer.write(latexPipeToken);
            } else {
              buffer.write(line[i]);
            }
          }
          if (closeIdx < 0) {
            inBlockMath = true;
          }
          index = end;
          continue;
        }
        // 行中孤立的 $$:原样保留,不开启状态(防止污染后续表格)
        buffer.write(r'$$');
        index += 2;
        continue;
      }
      // 单个 $ 仅在行内存在配对 $ 时才开启公式态(与 LatexSyntax 的
      // 行内正则一致),否则货币符号等孤立 $ 会让其后的表格管道被
      // 误替换("| 单价 | $100 |" 会因此少一列并泄漏占位符)。
      if (!inBlockMath &&
          (inInlineMath || _opensInlineMath(line, index))) {
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
