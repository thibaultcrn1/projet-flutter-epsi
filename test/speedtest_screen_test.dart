import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speedtest_app/speedtest/speedtest_screen.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SpeedtestScreen(isDarkMode: true, onToggleTheme: () {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('affiche les elements principaux de l ecran', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Speedtest'), findsOneWidget);
    expect(find.text('GO'), findsOneWidget);
    expect(find.text('PING'), findsOneWidget);
    expect(find.text('DOWNLOAD'), findsOneWidget);
    expect(find.text('UPLOAD'), findsOneWidget);
    expect(find.text('Test jauge'), findsOneWidget);
  });

  testWidgets('le switch manuel active puis desactive le mode manuel', (
    tester,
  ) async {
    await pumpScreen(tester);

    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);

    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(find.textContaining('Mode manuel'), findsOneWidget);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(find.textContaining('Appuie sur GO'), findsOneWidget);
  });
}

