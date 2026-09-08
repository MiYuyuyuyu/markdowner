class TabItem {
  final String id;
  String title;
  String? filePath;
  String content;
  double scrollOffset;

  TabItem({
    required this.id,
    required this.title,
    this.filePath,
    this.content = '',
    this.scrollOffset = 0,
  });

  bool get isUnsaved => filePath == null;

  String get displayTitle {
    if (title.length <= 24) return title;
    // 按字符(而非 UTF-16 码元)截断,避免切断 emoji 等代理对
    final chars = String.fromCharCodes(title.runes.take(21));
    return '$chars...';
  }
}
