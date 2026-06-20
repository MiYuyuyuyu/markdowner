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

  String get displayTitle =>
      title.length > 24 ? '${title.substring(0, 21)}...' : title;
}
