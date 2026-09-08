class ReadingSessionTab {
  final String path;
  final double scrollOffset;

  const ReadingSessionTab({required this.path, this.scrollOffset = 0});

  factory ReadingSessionTab.fromJson(Map<String, dynamic> json) {
    return ReadingSessionTab(
      path: json['path'] as String? ?? '',
      scrollOffset: _parseOffset(json['scrollOffset']),
    );
  }

  static double _parseOffset(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
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
    // 单个字段/标签损坏时只丢弃该部分,不能让整个会话(所有打开的标签)丢失
    final tabsJson = json['openTabs'];
    final tabs = <ReadingSessionTab>[];
    if (tabsJson is List) {
      for (final tab in tabsJson) {
        if (tab is! Map) continue;
        try {
          final parsed = ReadingSessionTab.fromJson(
            Map<String, dynamic>.from(tab),
          );
          if (parsed.path.isNotEmpty) tabs.add(parsed);
        } catch (_) {
          // 跳过损坏的标签
        }
      }
    }
    final activePath = json['activePath'];
    return ReadingSession(
      openTabs: tabs,
      activePath: activePath is String ? activePath : null,
      showSidebar: _parseBool(json['showSidebar'], fallback: true),
      showToc: _parseBool(json['showToc'], fallback: false),
    );
  }

  static bool _parseBool(Object? value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is String) return bool.tryParse(value) ?? fallback;
    if (value is num) return value != 0;
    return fallback;
  }

  Map<String, dynamic> toJson() => {
        'openTabs': openTabs.map((tab) => tab.toJson()).toList(),
        'activePath': activePath,
        'showSidebar': showSidebar,
        'showToc': showToc,
      };
}
