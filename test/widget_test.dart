import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_app/widgets/welcome/welcome_page.dart';
import 'package:provider/provider.dart';
import 'package:markdown_app/providers/tab_manager.dart';
import 'package:markdown_app/services/file_service.dart';
import 'package:markdown_app/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('WelcomePage shows title and open button', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    final fileService = FileService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => TabManager(fileService, storageService),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: WelcomePage())),
      ),
    );

    expect(find.text('Markdown Reader'), findsOneWidget);
    expect(find.text('打开文件'), findsNWidgets(2));
  });
}
