import 'package:flutter_test/flutter_test.dart';
import 'package:speedtest_app/speedtest/speedtest_controller.dart';

void main() {
  group('SpeedtestMetrics', () {
    test('copyWith met a jour uniquement les champs fournis', () {
      const initial = SpeedtestMetrics(
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

  group('SpeedtestController', () {
    test('etat initial correct', () {
      final c = SpeedtestController();

      expect(c.phase, SpeedtestPhase.idle);
      expect(c.isRunning, isFalse);
      expect(c.gaugeValueMbps, 0);
      expect(c.metrics.pingMs, isNull);
      expect(c.metrics.downloadMbps, isNull);
      expect(c.metrics.uploadMbps, isNull);

      c.dispose();
    });

    test('mode manuel active reset et garde le controle de jauge', () {
      final c = SpeedtestController();

      c.setManualMode(true);
      c.setManualValue(345.0);

      expect(c.manualMode, isTrue);
      expect(c.gaugeValueMbps, 345.0);
      expect(c.isRunning, isFalse);

      c.dispose();
    });

    test('reset remet l etat a zero', () {
      final c = SpeedtestController();

      c.setManualMode(true);
      c.setManualValue(500.0);
      c.reset();

      expect(c.phase, SpeedtestPhase.idle);
      expect(c.gaugeValueMbps, 0);
      expect(c.metrics.pingMs, isNull);
      expect(c.metrics.downloadMbps, isNull);
      expect(c.metrics.uploadMbps, isNull);

      c.dispose();
    });
  });
}

