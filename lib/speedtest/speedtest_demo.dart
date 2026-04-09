import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

enum DemoPhase { idle, ping, download, upload, done, error }

class DemoMetrics {
  const DemoMetrics({this.pingMs, this.downloadMbps, this.uploadMbps});

  final double? pingMs;
  final double? downloadMbps;
  final double? uploadMbps;

  DemoMetrics copyWith({
    double? pingMs,
    double? downloadMbps,
    double? uploadMbps,
  }) {
    return DemoMetrics(
      pingMs: pingMs ?? this.pingMs,
      downloadMbps: downloadMbps ?? this.downloadMbps,
      uploadMbps: uploadMbps ?? this.uploadMbps,
    );
  }
}

class SpeedtestDemoController extends ChangeNotifier {
  SpeedtestDemoController({Random? random}) : _random = random ?? Random();

  final Random _random;
  HttpClient? _client;
  int _runId = 0;

  DemoPhase phase = DemoPhase.idle;
  bool isRunning = false;
  double gaugeValueMbps = 0;
  DemoMetrics metrics = const DemoMetrics();
  String? errorMessage;

  bool manualMode = false;

  static const Duration _downloadDuration = Duration(seconds: 10);
  static const Duration _uploadDuration = Duration(seconds: 10);
  static const Duration _sampleEvery = Duration(milliseconds: 120);

  static final List<Uri> _downloadUrls = [
    Uri.parse('https://speed.hetzner.de/100MB.bin'),
    Uri.parse('https://proof.ovh.net/files/100Mb.dat'),
    Uri.parse('https://ash-speed.hetzner.com/100MB.bin'),
  ];
  static final List<Uri> _uploadUrls = [
    Uri.parse('https://httpbin.org/post'),
    Uri.parse('https://postman-echo.com/post'),
  ];

  void setManualMode(bool v) {
    manualMode = v;
    if (manualMode) {
      stop();
      phase = DemoPhase.idle;
      metrics = const DemoMetrics();
      gaugeValueMbps = 0;
      errorMessage = null;
    }
    notifyListeners();
  }

  void setManualValue(double mbps) {
    gaugeValueMbps = mbps;
    notifyListeners();
  }

  void reset() {
    stop();
    phase = DemoPhase.idle;
    isRunning = false;
    gaugeValueMbps = 0;
    metrics = const DemoMetrics();
    errorMessage = null;
    notifyListeners();
  }

  void startOrStop() {
    if (manualMode) return;
    if (isRunning) {
      stop();
      return;
    }
    unawaited(_startRealTest());
  }

  void stop() {
    _runId++;
    _client?.close(force: true);
    _client = null;
    isRunning = false;
    notifyListeners();
  }

  Future<void> _startRealTest() async {
    stop();

    final run = _runId;
    _client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 5);

    isRunning = true;
    phase = DemoPhase.ping;
    gaugeValueMbps = 0;
    metrics = const DemoMetrics();
    errorMessage = null;
    notifyListeners();

    try {
      await _runPing(run);
      if (!_isCurrentRun(run)) return;

      await _runDownload(run);
      if (!_isCurrentRun(run)) return;

      await _runUpload(run);
      if (!_isCurrentRun(run)) return;

      phase = DemoPhase.done;
      gaugeValueMbps = 0;
      isRunning = false;
      notifyListeners();
    } catch (e) {
      if (!_isCurrentRun(run)) return;
      phase = DemoPhase.error;
      isRunning = false;
      gaugeValueMbps = 0;
      errorMessage = _prettyError(e);
      notifyListeners();
    } finally {
      _client?.close(force: true);
      _client = null;
    }
  }

  Future<void> _runPing(int run) async {
    final samples = <double>[];
    final hosts = ['1.1.1.1', '8.8.8.8'];

    for (var i = 0; i < 8; i++) {
      if (!_isCurrentRun(run)) return;
      final host = hosts[i % hosts.length];
      final sw = Stopwatch()..start();
      try {
        final socket = await Socket.connect(
          host,
          443,
          timeout: const Duration(seconds: 2),
        );
        socket.destroy();
        sw.stop();
        samples.add(sw.elapsedMicroseconds / 1000.0);
      } catch (_) {
        sw.stop();
      }

      metrics = metrics.copyWith(pingMs: _median(samples));
      phase = DemoPhase.ping;
      gaugeValueMbps = 0;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _runDownload(int run) async {
    phase = DemoPhase.download;
    gaugeValueMbps = 0;
    notifyListeners();

    final client = _client;
    if (client == null) return;

    final start = DateTime.now();
    var totalBytes = 0;
    var lastSampleAt = start;
    var lastSampleBytes = 0;
    var ema = 0.0;
    var requestFailures = 0;
    var requestIndex = 0;

    while (_isCurrentRun(run) &&
        DateTime.now().difference(start) < _downloadDuration) {
      final baseUrl = _downloadUrls[requestIndex % _downloadUrls.length];
      requestIndex++;
      try {
        final req = await client
            .getUrl(
              baseUrl.replace(
                queryParameters: {
                  't': DateTime.now().microsecondsSinceEpoch.toString(),
                },
              ),
            )
            .timeout(const Duration(seconds: 8));
        req.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        final res = await req.close().timeout(const Duration(seconds: 10));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          requestFailures++;
          if (requestFailures > 6) {
            throw Exception('Download HTTP ${res.statusCode}');
          }
          continue;
        }

        await for (final chunk in res.timeout(const Duration(seconds: 6))) {
          if (!_isCurrentRun(run)) return;
          totalBytes += chunk.length;

          final now = DateTime.now();
          if (now.difference(lastSampleAt) >= _sampleEvery) {
            final dt = now.difference(lastSampleAt).inMicroseconds / 1e6;
            final db = (totalBytes - lastSampleBytes).toDouble();
            final instMbps = dt <= 0 ? 0.0 : (db * 8) / dt / 1e6;
            ema = ema == 0 ? instMbps : (ema * 0.72 + instMbps * 0.28);
            lastSampleAt = now;
            lastSampleBytes = totalBytes;

            gaugeValueMbps = ema;
            metrics = metrics.copyWith(downloadMbps: ema);
            notifyListeners();
          }

          if (DateTime.now().difference(start) >= _downloadDuration) break;
        }
      } on Exception {
        requestFailures++;
        if (requestFailures > 6 && totalBytes == 0) {
          rethrow;
        }
      }
    }

    if (totalBytes == 0) {
      throw Exception('Download impossible: aucun octet recu.');
    }

    final seconds = max(
      0.001,
      DateTime.now().difference(start).inMicroseconds / 1e6,
    );
    final avg = (totalBytes * 8) / seconds / 1e6;
    gaugeValueMbps = avg;
    metrics = metrics.copyWith(downloadMbps: avg);
    notifyListeners();
  }

  Future<void> _runUpload(int run) async {
    phase = DemoPhase.upload;
    gaugeValueMbps = 0;
    notifyListeners();

    final client = _client;
    if (client == null) return;

    final payload = Uint8List(512 * 1024);
    for (var i = 0; i < payload.length; i++) {
      payload[i] = _random.nextInt(256);
    }

    final start = DateTime.now();
    var totalBytes = 0;
    var lastSampleAt = start;
    var lastSampleBytes = 0;
    var ema = 0.0;
    var requestFailures = 0;
    var requestIndex = 0;

    while (_isCurrentRun(run) &&
        DateTime.now().difference(start) < _uploadDuration) {
      final baseUrl = _uploadUrls[requestIndex % _uploadUrls.length];
      requestIndex++;
      try {
        final req = await client
            .postUrl(baseUrl)
            .timeout(const Duration(seconds: 8));
        req.headers.contentType = ContentType.binary;
        req.contentLength = payload.length;
        req.add(payload);
        final res = await req.close().timeout(const Duration(seconds: 12));
        await res.drain<void>();
        if (res.statusCode < 200 || res.statusCode >= 300) {
          requestFailures++;
          if (requestFailures > 6) {
            throw Exception('Upload HTTP ${res.statusCode}');
          }
          continue;
        }
        totalBytes += payload.length;
      } on Exception {
        requestFailures++;
        if (requestFailures > 6 && totalBytes == 0) {
          rethrow;
        }
      }

      final now = DateTime.now();
      if (now.difference(lastSampleAt) >= _sampleEvery) {
        final dt = now.difference(lastSampleAt).inMicroseconds / 1e6;
        final db = (totalBytes - lastSampleBytes).toDouble();
        final instMbps = dt <= 0 ? 0.0 : (db * 8) / dt / 1e6;
        ema = ema == 0 ? instMbps : (ema * 0.72 + instMbps * 0.28);
        lastSampleAt = now;
        lastSampleBytes = totalBytes;

        gaugeValueMbps = ema;
        metrics = metrics.copyWith(uploadMbps: ema);
        notifyListeners();
      }
    }

    if (totalBytes == 0) {
      throw Exception('Upload impossible: aucun envoi valide.');
    }

    final seconds = max(
      0.001,
      DateTime.now().difference(start).inMicroseconds / 1e6,
    );
    final avg = (totalBytes * 8) / seconds / 1e6;
    gaugeValueMbps = avg;
    metrics = metrics.copyWith(uploadMbps: avg);
    notifyListeners();
  }

  bool _isCurrentRun(int run) => _runId == run && isRunning;

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  static String _prettyError(Object error) {
    final text = error.toString();
    if (text.contains('HandshakeException')) {
      return 'Echec TLS/SSL: verifie ta connexion ou change de reseau.';
    }
    if (text.contains('SocketException')) {
      return 'Erreur reseau: impossible de joindre le serveur de test.';
    }
    return text;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
