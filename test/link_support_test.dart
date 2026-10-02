import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_app/widgets/markdown/link_support.dart';
import 'package:markdown_app/widgets/navigation/toc_panel.dart';

void main() {
  final sep = Platform.pathSeparator;
  String join(String prefix, List<String> segments) =>
      '$prefix$sep${segments.join(sep)}';

  group('parseMarkdownLink 外部链接', () {
    test('http/https/mailto 识别为外部链接', () {
      for (final href in [
        'https://flutter.cn',
        'http://example.com/a?b=1',
        'mailto:a@b.com',
      ]) {
        final link = parseMarkdownLink(href, null);
        expect(link?.kind, MarkdownLinkKind.external, reason: href);
        expect(link?.target, href);
      }
    });

    test('Windows 盘符不是协议', () {
      final link = parseMarkdownLink(r'C:\notes\a.md', null);
      expect(link?.kind, MarkdownLinkKind.localFile);
    });
  });

  group('parseMarkdownLink 本地路径', () {
    test('纯锚点', () {
      final link = parseMarkdownLink('#第1节-函数与极限', null);
      expect(link?.kind, MarkdownLinkKind.anchor);
      expect(link?.target, '第1节-函数与极限');
    });

    test('空锚点视为无效链接', () {
      expect(parseMarkdownLink('#', null), isNull);
      expect(parseMarkdownLink('', null), isNull);
    });

    test('相对路径基于当前文档目录解析(中文不编码)', () {
      final current = join('D:', ['笔记', 'index.md']);
      final link = parseMarkdownLink('高等数学/01-函数极限连续.md', current);
      expect(link?.kind, MarkdownLinkKind.localFile);
      expect(
        link?.target,
        join('D:', ['笔记', '高等数学', '01-函数极限连续.md']),
      );
    });

    test('百分号编码的相对路径先解码再解析', () {
      final current = join('D:', ['笔记', 'index.md']);
      final link = parseMarkdownLink(
        '%E9%AB%98%E7%AD%89%E6%95%B0%E5%AD%A6/'
        '01-%E5%87%BD%E6%95%B0%E6%9E%81%E9%99%90%E8%BF%9E%E7%BB%AD.md',
        current,
      );
      expect(link?.kind, MarkdownLinkKind.localFile);
      expect(
        link?.target,
        join('D:', ['笔记', '高等数学', '01-函数极限连续.md']),
      );
    });

    test('.. 折叠到上级目录', () {
      final current = join('D:', ['笔记', '高等数学', '01.md']);
      final link = parseMarkdownLink('../附录/公式表.md', current);
      expect(
        link?.target,
        join('D:', ['笔记', '附录', '公式表.md']),
      );
    });

    test('./ 与多余斜杠', () {
      final current = join('D:', ['笔记', 'index.md']);
      final link = parseMarkdownLink('./高等数学//01.md', current);
      expect(
        link?.target,
        join('D:', ['笔记', '高等数学', '01.md']),
      );
    });

    test('无当前文件时相对路径不可解析', () {
      expect(parseMarkdownLink('高等数学/01.md', null), isNull);
    });

    test('文档链接带锚点', () {
      final current = join('D:', ['笔记', 'index.md']);
      final link = parseMarkdownLink('高等数学/01.md#第2节 极限', current);
      expect(link?.kind, MarkdownLinkKind.localFile);
      expect(link?.anchor, '第2节 极限');
      expect(link?.target, endsWith('01.md'));
    });

    test('file:// 协议转本地路径', () {
      final uri = Uri.parse('file:///D:/notes/a.md');
      final expected = uri.toFilePath(windows: Platform.isWindows);
      final link = parseMarkdownLink('file:///D:/notes/a.md', null);
      expect(link?.kind, MarkdownLinkKind.localFile);
      expect(link?.target, expected);
    });

    test('查询参数被剥离', () {
      final current = join('D:', ['笔记', 'index.md']);
      final link = parseMarkdownLink('01.md?v=1', current);
      expect(link?.target, endsWith('01.md'));
    });

    test('非法百分号序列按原文处理', () {
      final current = join('D:', ['笔记', 'index.md']);
      final link = parseMarkdownLink('100%.md', current);
      expect(link?.target, endsWith('100%.md'));
    });
  });

  group('githubSlug / headingIndexForAnchor', () {
    test('基础 slug 规则', () {
      expect(githubSlug('1. 函数与极限'), '1-函数与极限');
      expect(githubSlug('Hello World!'), 'hello-world');
      expect(githubSlug('  C++  与  Dart  '), 'c-与-dart');
    });

    test('重复标题按 -1/-2 命名', () {
      final headings = [
        const HeadingItem(level: 2, title: '例题', lineIndex: 0),
        const HeadingItem(level: 2, title: '例题', lineIndex: 4),
        const HeadingItem(level: 2, title: '小结', lineIndex: 8),
      ];
      expect(headingIndexForAnchor(headings, '例题'), 0);
      expect(headingIndexForAnchor(headings, '例题-1'), 1);
      expect(headingIndexForAnchor(headings, '小结'), 2);
      expect(headingIndexForAnchor(headings, '不存在'), -1);
    });
  });
}
