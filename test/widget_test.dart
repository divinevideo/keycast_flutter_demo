// ABOUTME: Basic widget test for Keycast Flutter Demo
// ABOUTME: Verifies the app builds successfully

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keycast_flutter_demo/main.dart';

void main() {
  testWidgets('App builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: KeycastDemoApp()),
    );

    expect(find.text('Keycast Flutter Demo'), findsOneWidget);
  });
}
