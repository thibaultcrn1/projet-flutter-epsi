import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

enum SpeedtestPhase { idle, ping, download, upload, done, error }

class SpeedtestMetrics {
  const SpeedtestMetrics({this.pingMs, this.downloadMbps, this.uploadMbps});

  final double? pingMs;
  final double? downloadMbps;
  final double? uploadMbps;

  SpeedtestMetrics copyWith({
    double? pingMs,
    double? downloadMbps,
    double? uploadMbps,
  }) {
    return SpeedtestMetrics(
      pingMs: pingMs ?? this.pingMs,
      downloadMbps: downloadMbps ?? this.downloadMbps,
      uploadMbps: uploadMbps ?? this.uploadMbps,
    );
  }
}

class SpeedtestController extends ChangeNotifier {
  SpeedtestController({Random? random}) : _random = random ?? Random();

  final Random _random;
  HttpClient? _client;
  int _runId = 0;

  SpeedtestPhase phase = SpeedtestPhase.idle;
  bool isRunning = false;
  double gaugeValueMbps = 0;
  SpeedtestMetrics metrics = const SpeedtestMetrics();
  String? errorMessage;

  bool manualMode = false;

  static const Duration _downloadDuration = Duration(seconds: 10);
  static const Duration _uploadDuration = Duration(seconds: 10);
  static const Duration _sampleEvery = Duration(milliseconds: 120);
  static const int _downloadWorkers = 3;
  static const int _uploadWorkers = 2;

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
      phase = SpeedtestPhase.idle;
      metrics = const SpeedtestMetrics();
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
    phase = SpeedtestPhase.idle;
    isRunning = false;
    gaugeValueMbps = 0;
    metrics = const SpeedtestMetrics();
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
    phase = SpeedtestPhase.ping;
    gaugeValueMbps = 0;
    metrics = const SpeedtestMetrics();
    errorMessage = null;
    notifyListeners();

    try {
      await _runPing(run);
      if (!_isCurrentRun(run)) return;

      await _runDownload(run);
      if (!_isCurrentRun(run)) return;

      await _runUpload(run);
      if (!_isCurrentRun(run)) return;

      phase = SpeedtestPhase.done;
      gaugeValueMbps = 0;
      isRunning = false;
      notifyListeners();
    } catch (e) {
      if (!_isCurrentRun(run)) return;
      phase = SpeedtestPhase.error;
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
      phase = SpeedtestPhase.ping;
      gaugeValueMbps = 0;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _runDownload(int run) async {
    phase = SpeedtestPhase.download;
    gaugeValueMbps = 0;
    notifyListeners();

    final client = _client;
    if (client == null) return;

    final start = DateTime.now();
    var totalBytes = 0;
    var lastSampleAt = start;
    var lastSampleBytes = 0;
    var ema = 0.0;
    var requestIndex = 0;
    var failures = 0;
    final samples = <double>[];

    Future<void> worker() async {
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
          final res = await req.close().timeout(const Duration(seconds: 12));
          if (res.statusCode < 200 || res.statusCode >= 300) {
            failures++;
            continue;
          }
          await for (final chunk in res.timeout(const Duration(seconds: 6))) {
            if (!_isCurrentRun(run)) return;
            totalBytes += chunk.length;
            if (DateTime.now().difference(start) >= _downloadDuration) break;
          }
        } on Exception {
          failures++;
        }
      }
    }

    final jobs = List.generate(_downloadWorkers, (_) => worker());

    while (_isCurrentRun(run) &&
        DateTime.now().difference(start) < _downloadDuration) {
      await Future<void>.delayed(_sampleEvery);
      final now = DateTime.now();
      final dt = now.difference(lastSampleAt).inMicroseconds / 1e6;
      final db = (totalBytes - lastSampleBytes).toDouble();
      final instMbps = dt <= 0 ? 0.0 : (db * 8) / dt / 1e6;
      if (instMbps > 0) samples.add(instMbps);
      ema = ema == 0 ? instMbps : (ema * 0.78 + instMbps * 0.22);
      lastSampleAt = now;
      lastSampleBytes = totalBytes;
      gaugeValueMbps = ema;
      metrics = metrics.copyWith(downloadMbps: ema);
      notifyListeners();
    }

    await Future.wait(jobs);

    if (totalBytes == 0) {
      throw Exception('Download impossible: aucun octet recu.');
    }
    if (failures > 20 && samples.isEmpty) {
      throw Exception('Download instable: trop d echecs reseau.');
    }

    final stable = _stableRate(samples);
    gaugeValueMbps = stable;
    metrics = metrics.copyWith(downloadMbps: stable);
    notifyListeners();
  }

  Future<void> _runUpload(int run) async {
    phase = SpeedtestPhase.upload;
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
    var requestIndex = 0;
    var failures = 0;
    final samples = <double>[];

    Future<void> worker() async {
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
            failures++;
            continue;
          }
          totalBytes += payload.length;
        } on Exception {
          failures++;
        }
      }
    }

    final jobs = List.generate(_uploadWorkers, (_) => worker());

    while (_isCurrentRun(run) &&
        DateTime.now().difference(start) < _uploadDuration) {
      await Future<void>.delayed(_sampleEvery);
      final now = DateTime.now();
      final dt = now.difference(lastSampleAt).inMicroseconds / 1e6;
      final db = (totalBytes - lastSampleBytes).toDouble();
      final instMbps = dt <= 0 ? 0.0 : (db * 8) / dt / 1e6;
      if (instMbps > 0) samples.add(instMbps);
      ema = ema == 0 ? instMbps : (ema * 0.78 + instMbps * 0.22);
      lastSampleAt = now;
      lastSampleBytes = totalBytes;
      gaugeValueMbps = ema;
      metrics = metrics.copyWith(uploadMbps: ema);
      notifyListeners();
    }

    await Future.wait(jobs);

    if (totalBytes == 0) {
      throw Exception('Upload impossible: aucun envoi valide.');
    }
    if (failures > 20 && samples.isEmpty) {
      throw Exception('Upload instable: trop d echecs reseau.');
    }

    final stable = _stableRate(samples);
    gaugeValueMbps = stable;
    metrics = metrics.copyWith(uploadMbps: stable);
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

  static double _stableRate(List<double> values) {
    if (values.isEmpty) return 0;
    final cleaned = [...values]..sort();
    final from = min(2, cleaned.length - 1);
    final trimmed = cleaned.sublist(from);
    if (trimmed.length == 1) return trimmed.first;
    final p70Index = ((trimmed.length - 1) * 0.70).round();
    final p85Index = ((trimmed.length - 1) * 0.85).round();
    return (trimmed[p70Index] + trimmed[p85Index]) / 2.0;
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

