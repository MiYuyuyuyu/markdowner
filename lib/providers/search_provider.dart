import '../models/tab_item.dart';

/// 单处搜索命中。行号基于原文(未预处理)的 \n 分行,
/// 与 parseHeadings 的 lineIndex 同一坐标系。
class SearchMatch {
  final int lineIndex;
  final String lineText;
  final int start;
  final int end;

  const SearchMatch({
    required this.lineIndex,
    required this.lineText,
    required this.start,
    required this.end,
  });

  /// 截取命中点附近的预览文本(前后各留 [context] 个字符)
  String preview({int context = 30}) {
    if (lineText.length <= context * 2 + (end - start)) return lineText.trim();
    final from = (start - context).clamp(0, lineText.length);
    final to = (end + context).clamp(0, lineText.length);
    return lineText.substring(from, to).trim();
  }
}

/// 在 [text] 中大小写不敏感地查找 [query] 的所有命中(空 query 返回空列表)。
/// 逐行搜索:若在全文的小写副本上定位,个别字符(如 'İ')转小写后
/// 长度变化会使坐标与原文错位甚至越界。
List<SearchMatch> searchInText(String text, String query) {
  final matches = <SearchMatch>[];
  if (query.isEmpty) return matches;

  final lowerQuery = query.toLowerCase();
  var lineStart = 0;
  var lineIndex = 0;

  while (lineStart <= text.length) {
    final lineEnd = text.indexOf('\n', lineStart);
    final lineEndIndex = lineEnd == -1 ? text.length : lineEnd;
    final lineText = text.substring(lineStart, lineEndIndex);
    final lowerLine = lineText.toLowerCase();
    var from = 0;
    while (true) {
      final idx = lowerLine.indexOf(lowerQuery, from);
      if (idx < 0) break;
      matches.add(SearchMatch(
        lineIndex: lineIndex,
        lineText: lineText,
        start: idx,
        end: idx + lowerQuery.length,
      ));
      from = idx + lowerQuery.length;
    }
    if (lineEnd == -1) break;
    lineStart = lineEnd + 1;
    lineIndex++;
  }
  return matches;
}

/// 跨标签搜索结果:一个标签页及其全部命中
class TabSearchResult {
  final int tabIndex;
  final String title;
  final List<SearchMatch> matches;

  const TabSearchResult({
    required this.tabIndex,
    required this.title,
    required this.matches,
  });
}

/// 在所有已打开标签的全文中搜索,返回有命中的标签(保序)
List<TabSearchResult> searchAcrossTabs(List<TabItem> tabs, String query) {
  final results = <TabSearchResult>[];
  for (var i = 0; i < tabs.length; i++) {
    final matches = searchInText(tabs[i].content, query);
    if (matches.isNotEmpty) {
      results.add(TabSearchResult(
        tabIndex: i,
        title: tabs[i].displayTitle,
        matches: matches,
      ));
    }
  }
  return results;
}

/// 快速打开条目(已打开标签 + 最近文件去重后的统一形态)
class QuickOpenEntry {
  final String title;
  final String subtitle;
  final String? path;
  final bool isOpen;

  const QuickOpenEntry({
    required this.title,
    required this.subtitle,
    required this.path,
    required this.isOpen,
  });
}

/// 汇总已打开标签与最近文件,按文件名去重(已打开优先)
List<QuickOpenEntry> buildQuickOpenEntries({
  required List<TabItem> tabs,
  required List<String> recentPaths,
  required String Function(String path) fileNameOf,
}) {
  final entries = <QuickOpenEntry>[];
  final seenPaths = <String>{};
  for (final tab in tabs) {
    final path = tab.filePath;
    if (path != null) seenPaths.add(path);
    entries.add(QuickOpenEntry(
      title: tab.title,
      subtitle: tab.isUnsaved ? '未保存的标签页' : (path ?? ''),
      path: path,
      isOpen: true,
    ));
  }
  for (final path in recentPaths) {
    if (!seenPaths.add(path)) continue;
    entries.add(QuickOpenEntry(
      title: fileNameOf(path),
      subtitle: path,
      path: path,
      isOpen: false,
    ));
  }
  return entries;
}

/// 按文件名(含路径)大小写不敏感过滤;query 为空返回全部
List<QuickOpenEntry> filterQuickOpen(
  List<QuickOpenEntry> entries,
  String query,
) {
  if (query.isEmpty) return entries;
  final lower = query.toLowerCase();
  return entries
      .where((entry) => entry.title.toLowerCase().contains(lower))
      .toList();
}
