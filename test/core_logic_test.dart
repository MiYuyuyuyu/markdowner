import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_app/models/reading_session.dart';
import 'package:markdown_app/models/tab_item.dart';
import 'package:markdown_app/providers/settings_provider.dart';
import 'package:markdown_app/providers/tab_manager.dart';
import 'package:markdown_app/services/file_service.dart';
import 'package:markdown_app/services/storage_service.dart';
import 'package:markdown_app/widgets/navigation/toc_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _hasUnpairedSurrogate(String text) {
  final units = text.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      final hasNextPair =
          i + 1 < units.length && units[i + 1] >= 0xDC00 && units[i + 1] <= 0xDFFF;
      if (!hasNextPair) return true;
    }
    if (unit >= 0xDC00 && unit <= 0xDFFF) {
      final hasPrevPair =
          i > 0 && units[i - 1] >= 0xD800 && units[i - 1] <= 0xDBFF;
      if (!hasPrevPair) return true;
    }
  }
  return false;
}

void main() {
  group('parseHeadings', () {
    test('accepts up to three leading spaces like markdown does', () {
      final headings = parseHeadings('  ## 缩进标题');
      expect(headings, hasLength(1));
      expect(headings.single.title, '缩进标题');
    });

    test('still ignores four-space indented pseudo headings', () {
      final headings = parseHeadings('    ## 这是代码块');
      expect(headings, isEmpty);
    });

    test('recognizes headings inside blockquotes', () {
      final headings = parseHeadings('> # 引用标题');
      expect(headings, hasLength(1));
      expect(headings.single.level, 1);
    });

    test('fence tracking does not mix backtick and tilde fences', () {
      const data = '~~~\n```dart\n# 不是标题\n~~~\n# 真标题';
      final headings = parseHeadings(data);
      expect(headings.map((h) => h.title), ['真标题']);
    });

    test('inline triple backticks do not open a fence', () {
      const data = '行内 ```code``` 用法\n# 真标题';
      final headings = parseHeadings(data);
      expect(headings.map((h) => h.title), ['真标题']);
    });
  });

  group('FileService.extractFileName', () {

    test('handles forward slashes on any platform', () {
      expect(FileService.extractFileName(r'C:/notes/diary.md'), 'diary.md');
    });

    test('handles backslashes', () {
      expect(FileService.extractFileName(r'C:\notes\diary.md'), 'diary.md');
    });

    test('handles mixed separators', () {
      expect(FileService.extractFileName(r'C:\notes/sub\diary.md'), 'diary.md');
    });
  });

  group('ReadingSession.fromJson tolerance', () {
    test('string scrollOffset does not destroy the whole session', () {
      final session = ReadingSession.fromJson({
        'openTabs': [
          {'path': 'a.md', 'scrollOffset': '120'},
          {'path': 'b.md', 'scrollOffset': 40},
        ],
        'activePath': 'a.md',
      });
      expect(session.openTabs, hasLength(2));
      expect(session.openTabs[0].scrollOffset, 120.0);
      expect(session.openTabs[1].scrollOffset, 40.0);
    });

    test('a malformed tab is skipped without dropping the good ones', () {
      final session = ReadingSession.fromJson({
        'openTabs': [
          'junk-entry',
          {'path': 'good.md'},
        ],
      });
      expect(session.openTabs, hasLength(1));
      expect(session.openTabs.single.path, 'good.md');
    });

    test('non-boolean ui flags fall back to defaults', () {
      final session = ReadingSession.fromJson({
        'openTabs': <Object>[],
        'showSidebar': 'not-a-bool',
      });
      expect(session.showSidebar, isTrue);
      expect(session.showToc, isFalse);
    });
  });

  group('SettingsProvider font size boundaries', () {
    test('clamps oversized stored value on startup', () async {
      SharedPreferences.setMockInitialValues({'font_size': 99.0});
      final storageService = await StorageService.init();
      final settings = SettingsProvider(storageService);
      expect(settings.fontSize, 32.0);
    });

    test('clamps undersized stored value on startup', () async {
      SharedPreferences.setMockInitialValues({'font_size': 1.0});
      final storageService = await StorageService.init();
      final settings = SettingsProvider(storageService);
      expect(settings.fontSize, 12.0);
    });
  });

  group('TabItem.displayTitle', () {
    test('never truncates in the middle of a surrogate pair', () {
      final tab = TabItem(id: '1', title: '😀' * 25);
      expect(tab.displayTitle, endsWith('...'));
      expect(_hasUnpairedSurrogate(tab.displayTitle), isFalse);
    });
  });

  group('TabManager recent files handling', () {
    test('keeps recent entry when an existing file fails to open', () async {
      final tempDir = await Directory.systemTemp.createTemp('markdown_app_gbk_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final badFile =
          File('${tempDir.path}${Platform.pathSeparator}gbk.md');
      // GBK bytes for 中文 — not decodable as strict UTF-8.
      await badFile.writeAsBytes([0xD6, 0xD0, 0xCE, 0xC4]);

      SharedPreferences.setMockInitialValues({});
      final storageService = await StorageService.init();
      await storageService.addRecentFile(badFile.path);

      final tabManager = TabManager(FileService(), storageService);
      await tabManager.openFileFromPath(badFile.path);

      expect(tabManager.hasTabs, isFalse);
      expect(storageService.getRecentFiles(), contains(badFile.path));
    });

    test('still removes recent entry when the file is gone', () async {
      SharedPreferences.setMockInitialValues({});
      final storageService = await StorageService.init();
      final missingPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}definitely_missing.md';
      await storageService.addRecentFile(missingPath);

      final tabManager = TabManager(FileService(), storageService);
      await tabManager.openFileFromPath(missingPath);

      expect(storageService.getRecentFiles(), isNot(contains(missingPath)));
    });

    test('generates unique tab ids when opening files in the same millisecond',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('markdown_app_ids_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      SharedPreferences.setMockInitialValues({});
      final storageService = await StorageService.init();
      final tabManager = TabManager(FileService(), storageService);

      final files = List.generate(3, (i) {
        final file =
            File('${tempDir.path}${Platform.pathSeparator}note$i.md');
        file.writeAsStringSync('# note $i');
        return file;
      });
      for (final file in files) {
        await tabManager.openFileFromPath(file.path);
      }

      final ids = tabManager.tabs.map((tab) => tab.id).toSet();
      expect(ids, hasLength(tabManager.tabs.length));
    });
  });
}
