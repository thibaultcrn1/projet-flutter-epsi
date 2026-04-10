import 'package:flutter_test/flutter_test.dart';

import 'package:speedtest_app/main.dart';

void main() {
  testWidgets('L app affiche le design Speedtest', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Speedtest'), findsOneWidget);
    expect(find.text('GO'), findsOneWidget);
  });
}
