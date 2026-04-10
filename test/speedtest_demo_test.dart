import 'package:flutter_test/flutter_test.dart';
import 'package:speedtest_app/speedtest/speedtest_demo.dart';

void main() {
  group('DemoMetrics', () {
    test('copyWith met a jour uniquement les champs fournis', () {
      const initial = DemoMetrics(
        pingMs: 12,
        downloadMbps: 120,
        uploadMbps: 45,
      );

      final updated = initial.copyWith(downloadMbps: 200);

      expect(updated.pingMs, 12);
      expect(updated.downloadMbps, 200);
      expect(updated.uploadMbps, 45);
    });
  });

  group('SpeedtestDemoController', () {
    test('etat initial correct', () {
      final c = SpeedtestDemoController();

      expect(c.phase, DemoPhase.idle);
      expect(c.isRunning, isFalse);
      expect(c.gaugeValueMbps, 0);
      expect(c.metrics.pingMs, isNull);
      expect(c.metrics.downloadMbps, isNull);
      expect(c.metrics.uploadMbps, isNull);

      c.dispose();
    });

    test('mode manuel active reset et garde le controle de jauge', () {
      final c = SpeedtestDemoController();

      c.setManualMode(true);
      c.setManualValue(345.0);

      expect(c.manualMode, isTrue);
      expect(c.gaugeValueMbps, 345.0);
      expect(c.isRunning, isFalse);

      c.dispose();
    });

    test('reset remet l etat a zero', () {
      final c = SpeedtestDemoController();

      c.setManualMode(true);
      c.setManualValue(500.0);
      c.reset();

      expect(c.phase, DemoPhase.idle);
      expect(c.gaugeValueMbps, 0);
      expect(c.metrics.pingMs, isNull);
      expect(c.metrics.downloadMbps, isNull);
      expect(c.metrics.uploadMbps, isNull);

      c.dispose();
    });
  });
}

