// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:speedtest_app/main.dart';

void main() {
  testWidgets('L app affiche le design Speedtest', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Laisse le premier frame se stabiliser.
    await tester.pump();

    expect(find.text('Speedtest'), findsOneWidget);
    expect(find.text('GO'), findsOneWidget);
  });
}
