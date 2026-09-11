import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_app/widgets/markdown/markdown_preprocessor.dart';

void main() {
  group('normalizeMermaidBlocks', () {
    test('converts mermaid fences to tags', () {
      final result = normalizeMermaidBlocks('```mermaid\ngraph TD\n```');
      expect(result, startsWith('<mermaid>'));
      expect(result, endsWith('</mermaid>'));
    });
  });

  group('normalizeMarkdownForParsing', () {
    test('keeps pipe replacement inside real inline math', () {
      final result = normalizeMarkdownForParsing(r'$a|b$');
      expect(result, contains(latexPipeToken));
    });

    test('keeps pipe replacement inside real block math', () {
      final result = normalizeMarkdownForParsing('\$\$\nx = |y|\n\$\$');
      expect(result, contains(latexPipeToken));
    });

    test(r'inline \( \) math protects pipes', () {
      final result = normalizeMarkdownForParsing(r'\(a|b\)');
      expect(result, contains(latexPipeToken));
    });

    test(r'bracket \[ \] math protects pipes across lines', () {
      final result = normalizeMarkdownForParsing('\\[\nx = a | b\n\\]');
      expect(result, contains(latexPipeToken));
    });

    test(r'escaped \[ outside math does not corrupt pipes', () {
      // \$ 转义不参与状态;成对的 \[...\] 之后表格管道应保持原样
      const data = r'花费 \$5 \[完\] 继续说明' '\n\n| A | B |\n|---|---|\n| 1 | 2 |';
      final result = normalizeMarkdownForParsing(data);
      expect(result, contains('| A | B |'));
    });

    test('does not touch pipes outside math', () {
      const data = '| A | B |\n|---|---|\n| 1 | 2 |';
      final result = normalizeMarkdownForParsing(data);
      expect(result, data);
    });

    test('code fence content is preserved verbatim', () {
      const fence = '```bash\necho \$HOME | wc -l\n```';
      const table = '\n\n| A | B |\n|---|---|\n| 1 | 2 |';
      final result = normalizeMarkdownForParsing('$fence$table');
      expect(result, fence + table);
    });

    test('odd dollar count inside fence does not pollute following table', () {
      const data = '```bash\necho \$HOME | wc -l\n```\n\n'
          '| A | B |\n|---|---|\n| 1 | 2 |';
      final result = normalizeMarkdownForParsing(data);
      expect(result, isNot(contains(latexPipeToken)));
    });

    test('inline code content is preserved verbatim', () {
      const data = '运行 `echo \$USER | wc` 即可';
      final result = normalizeMarkdownForParsing(data);
      expect(result, data);
    });

    test('lone currency dollar does not corrupt following table', () {
      const data = '这件商品价格 \$5 左右\n\n| A | B |\n|---|---|\n| 1 | 2 |';
      final result = normalizeMarkdownForParsing(data);
      expect(result, isNot(contains(latexPipeToken)));
      expect(result, contains('| A | B |'));
    });

    test('escaped dollars do not toggle math state', () {
      const data = r'花费 \$5 | 剩 \$3';
      final result = normalizeMarkdownForParsing(data);
      expect(result, isNot(contains(latexPipeToken)));
      expect(result, contains(r'\$5'));
    });

    test('triple dollar does not permanently desync block math state', () {
      const data = '总共 \$\$\$,明细如下:\n\n| A | B |\n|---|---|\n| 1 | 2 |';
      final result = normalizeMarkdownForParsing(data);
      expect(result, isNot(contains(latexPipeToken)));
    });

    test('unclosed inline dollar does not leak into later lines', () {
      const data = '价格 \$5\n\n| A | B |\n|---|---|\n| 1 | 2 |';
      final result = normalizeMarkdownForParsing(data);
      expect(result, isNot(contains(latexPipeToken)));
    });
  });
}
