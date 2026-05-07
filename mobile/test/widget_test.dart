// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:issa_wholesale_mobile/src/app/app.dart';
import 'package:issa_wholesale_mobile/src/core/storage/secure_kv.dart';

class _TestSecureKv implements SecureKv {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}

void main() {
  testWidgets('App builds and shows the login screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [secureKvProvider.overrideWithValue(_TestSecureKv())],
        child: const App(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Issa Wholesale'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsOneWidget);
  });
}
