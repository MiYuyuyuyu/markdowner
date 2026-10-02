import 'dart:io';

import '../navigation/toc_panel.dart' show HeadingItem;

/// Markdown 正文链接点击后的路由结果
enum MarkdownLinkKind {
  /// 外部链接(http/https/mailto 等),交给系统打开
  external,

  /// 本地文档(相对/绝对路径),在应用内打开
  localFile,

  /// 纯锚点(#标题),在当前文档内跳转
  anchor,
}

class ParsedMarkdownLink {
  final MarkdownLinkKind kind;

  /// external: 原始链接;localFile: 解析后的本地路径;anchor: 锚点文本
  final String target;

  /// localFile 附带的锚点(如 `./xx.md#标题`),无锚点为 null
  final String? anchor;

  const ParsedMarkdownLink._(this.kind, this.target, [this.anchor]);
}

final _schemeRegex = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*):');
final _driveRegex = RegExp(r'^([a-zA-Z]:)(?:/(.*))?$');

/// 解析 markdown 链接为路由结果。
///
/// 相对路径基于 [currentFilePath] 所在目录解析;无法定位(空链接、
/// 无当前文件可依据等)返回 null。
ParsedMarkdownLink? parseMarkdownLink(String href, String? currentFilePath) {
  var value = href.trim();
  if (value.isEmpty) return null;

  if (value.startsWith('#')) {
    final anchor = _decodeUriComponent(value.substring(1));
    if (anchor.isEmpty) return null;
    return ParsedMarkdownLink._(MarkdownLinkKind.anchor, anchor);
  }

  if (value.toLowerCase().startsWith('file:')) {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    try {
      value = uri.toFilePath(windows: Platform.isWindows);
    } on ArgumentError {
      return null;
    }
  } else {
    // 长度 > 1 的协议(http/https/mailto)视为外部链接;
    // 单字母"C:"是 Windows 盘符,不是协议
    final scheme = _schemeRegex.firstMatch(value)?.group(1);
    if (scheme != null && scheme.length > 1) {
      return ParsedMarkdownLink._(MarkdownLinkKind.external, value);
    }
    // Obsidian/Typora 等编辑器复制的链接常带百分号编码
    value = _decodeUriComponent(value);
  }

  // 剥离锚点与查询参数,剩余部分为本地文件路径
  String? anchor;
  final hashIndex = value.indexOf('#');
  if (hashIndex >= 0) {
    anchor = _decodeUriComponent(value.substring(hashIndex + 1));
    value = value.substring(0, hashIndex);
  }
  if (anchor != null && anchor.isEmpty) anchor = null;

  final resolved = _normalizeLocalPath(value, currentFilePath);
  if (resolved == null) {
    return anchor == null ? null : ParsedMarkdownLink._(MarkdownLinkKind.anchor, anchor);
  }
  return ParsedMarkdownLink._(MarkdownLinkKind.localFile, resolved, anchor);
}

String _decodeUriComponent(String value) {
  if (!value.contains('%')) return value;
  try {
    return Uri.decodeComponent(value);
  } on ArgumentError {
    // 含未转义的孤立 % 等非法序列,按原文处理
    return value;
  }
}

/// 以 [currentFilePath] 所在目录为基准解析相对路径,
/// 折叠 `.`/`..` 并转换为平台分隔符;无法解析返回 null。
String? _normalizeLocalPath(String path, String? currentFilePath) {
  final unified = path.replaceAll('\\', '/');

  // 查询参数在百分号解码后剥离(本地文件路径基本不含 ?)
  final queryIndex = unified.indexOf('?');
  final withoutQuery = queryIndex >= 0 ? unified.substring(0, queryIndex) : unified;
  if (withoutQuery.isEmpty) return null;

  final driveMatch = _driveRegex.firstMatch(withoutQuery);
  String? prefix; // '/'、'//'、'C:' 或 null(相对路径)
  final segments = <String>[];
  if (driveMatch != null) {
    prefix = driveMatch.group(1)!;
    segments.addAll((driveMatch.group(2) ?? '').split('/'));
  } else if (withoutQuery.startsWith('//')) {
    prefix = '//';
    segments.addAll(withoutQuery.split('/'));
  } else if (withoutQuery.startsWith('/')) {
    prefix = '/';
    segments.addAll(withoutQuery.split('/'));
  } else {
    if (currentFilePath == null) return null;
    final base = _dirnameOf(currentFilePath).replaceAll('\\', '/');
    final baseDrive = _driveRegex.firstMatch(base);
    if (baseDrive != null) {
      prefix = baseDrive.group(1)!;
      segments.addAll((baseDrive.group(2) ?? '').split('/'));
    } else if (base.startsWith('//')) {
      prefix = '//';
      segments.addAll(base.split('/'));
    } else if (base.startsWith('/')) {
      prefix = '/';
      segments.addAll(base.split('/'));
    } else {
      segments.addAll(base.split('/'));
    }
    segments.addAll(withoutQuery.split('/'));
  }

  final resolved = <String>[];
  for (final segment in segments) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (resolved.isNotEmpty) {
        resolved.removeLast();
      } else if (prefix == null) {
        // 相对路径越出可解析的根(如越过盘根),无法定位
        return null;
      }
      continue;
    }
    resolved.add(segment);
  }

  final joined = resolved.join(Platform.pathSeparator);
  if (prefix == null) {
    return joined.isEmpty ? null : joined;
  }
  if (prefix == '/' || prefix == '//') {
    return '$prefix$joined';
  }
  // 盘符前缀后必须跟分隔符:C: + \notes → C:\notes
  return '$prefix${Platform.pathSeparator}$joined';
}

String _dirnameOf(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index <= 0 ? normalized : normalized.substring(0, index);
}

/// GitHub 风格标题锚点 slug:小写、去标点(保留字母/数字/下划线)、
/// 空白折叠为连字符;中日文等 Unicode 字母保留。
String githubSlug(String title) {
  final lowered = title.trim().toLowerCase();
  final stripped =
      lowered.replaceAll(RegExp(r'[^\p{L}\p{N}\s_-]', unicode: true), '');
  return stripped.replaceAll(RegExp(r'\s+'), '-');
}

/// 计算 [anchor] 命中的标题下标;重复标题按 GitHub 规则依次命名
/// (slug、slug-1、slug-2…)。无命中返回 -1。
int headingIndexForAnchor(List<HeadingItem> headings, String anchor) {
  final seen = <String, int>{};
  for (var i = 0; i < headings.length; i++) {
    final base = githubSlug(headings[i].title);
    final count = seen[base] ?? 0;
    seen[base] = count + 1;
    final slug = count == 0 ? base : '$base-$count';
    if (slug == anchor) return i;
  }
  return -1;
}
