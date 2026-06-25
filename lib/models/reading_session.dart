class ReadingSessionTab {
  final String path;
  final double scrollOffset;

  const ReadingSessionTab({required this.path, this.scrollOffset = 0});

  factory ReadingSessionTab.fromJson(Map<String, dynamic> json) {
    return ReadingSessionTab(
      path: json['path'] as String? ?? '',
      scrollOffset: (json['scrollOffset'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'scrollOffset': scrollOffset,
      };
}

class ReadingSession {
  final List<ReadingSessionTab> openTabs;
  final String? activePath;
  final bool showSidebar;
  final bool showToc;

  const ReadingSession({
    this.openTabs = const [],
    this.activePath,
    this.showSidebar = true,
    this.showToc = false,
  });

  factory ReadingSession.fromJson(Map<String, dynamic> json) {
    final tabsJson = json['openTabs'];
    return ReadingSession(
      openTabs: tabsJson is List
          ? tabsJson
              .whereType<Map>()
              .map((tab) => ReadingSessionTab.fromJson(
                    Map<String, dynamic>.from(tab),
                  ))
              .where((tab) => tab.path.isNotEmpty)
              .toList()
          : const [],
      activePath: json['activePath'] as String?,
      showSidebar: json['showSidebar'] as bool? ?? true,
      showToc: json['showToc'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'openTabs': openTabs.map((tab) => tab.toJson()).toList(),
        'activePath': activePath,
        'showSidebar': showSidebar,
        'showToc': showToc,
      };
}
