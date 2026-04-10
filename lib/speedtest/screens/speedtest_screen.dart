import 'package:flutter/material.dart';

import '../controllers/speedtest_controller.dart';
import '../widgets/metric_card.dart';
import '../widgets/speed_gauge.dart';

class SpeedtestScreen extends StatefulWidget {
  const SpeedtestScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<SpeedtestScreen> createState() => _SpeedtestScreenState();
}

class _SpeedtestScreenState extends State<SpeedtestScreen> {
  late final SpeedtestController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SpeedtestController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _phaseLabel(SpeedtestPhase phase) {
    switch (phase) {
      case SpeedtestPhase.idle:
        return 'Prêt';
      case SpeedtestPhase.ping:
        return 'Ping';
      case SpeedtestPhase.download:
        return 'Download';
      case SpeedtestPhase.upload:
        return 'Upload';
      case SpeedtestPhase.done:
        return 'Terminé';
      case SpeedtestPhase.error:
        return 'Erreur';
    }
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.55),
                  radius: 1.05,
                  colors: isDark
                      ? [const Color(0xFF0B1734), const Color(0xFF070B14)]
                      : [const Color(0xFFDDE8FF), const Color(0xFFF4F8FF)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (isDark ? Colors.black : Colors.white).withValues(
                      alpha: 0.00,
                    ),
                    (isDark ? Colors.black : Colors.white).withValues(
                      alpha: isDark ? 0.38 : 0.32,
                    ),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Column(
                    children: [
                      SizedBox(height: safe.top == 0 ? 14 : 6),
                      _TopBar(
                        isRunning: _controller.isRunning,
                        onReset: _controller.reset,
                        isDarkMode: widget.isDarkMode,
                        onToggleTheme: widget.onToggleTheme,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 460,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SpeedGauge(
                                          valueMbps: _controller.gaugeValueMbps,
                                          phaseLabel: _phaseLabel(
                                            _controller.phase,
                                          ),
                                          maxMbps: 1000,
                                          isRunning: _controller.isRunning,
                                          onTap: _controller.startOrStop,
                                        ),
                                        const SizedBox(height: 16),
                                        _MetricsGrid(
                                          metrics: _controller.metrics,
                                        ),
                                        const SizedBox(height: 14),
                                        _DemoControls(controller: _controller),
                                        const SizedBox(height: 14),
                                        if (_controller.phase ==
                                                SpeedtestPhase.error &&
                                            (_controller.errorMessage ?? '')
                                                .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: Text(
                                              _controller.errorMessage!,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error
                                                    .withValues(alpha: 0.90),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          _controller.manualMode
                                              ? 'Mode manuel: bouge la jauge avec le slider'
                                              : (_controller.isRunning
                                                    ? 'Test de connexion en cours…'
                                                    : 'Appuie sur GO pour lancer un test'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                color: Colors.white.withValues(
                                                  alpha: isDark ? 0.62 : 0.82,
                                                ),
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      _BottomHint(isRunning: _controller.isRunning),
                      const SizedBox(height: 14),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isRunning,
    required this.onReset,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isRunning;
  final VoidCallback onReset;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Speedtest',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onToggleTheme,
          tooltip: isDarkMode ? 'Passer en clair' : 'Passer en sombre',
          icon: Icon(
            isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
        IconButton(
          onPressed: isRunning ? null : onReset,
          tooltip: 'Réinitialiser',
          icon: Icon(
            Icons.refresh_rounded,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final SpeedtestMetrics metrics;

  String _fmtMs(double? v) {
    if (v == null) return '—';
    return v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0);
  }

  String _fmtMbps(double? v) {
    if (v == null) return '—';
    if (v >= 100) return v.toStringAsFixed(0);
    if (v >= 10) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCols = constraints.maxWidth >= 360;
        final children = [
          MetricCard(
            title: 'Ping',
            value: _fmtMs(metrics.pingMs),
            unit: 'ms',
            icon: Icons.bolt_rounded,
            accent: const Color(0xFF22C55E),
          ),
          MetricCard(
            title: 'Download',
            value: _fmtMbps(metrics.downloadMbps),
            unit: 'Mbps',
            icon: Icons.download_rounded,
            accent: const Color(0xFF60A5FA),
          ),
          MetricCard(
            title: 'Upload',
            value: _fmtMbps(metrics.uploadMbps),
            unit: 'Mbps',
            icon: Icons.upload_rounded,
            accent: const Color(0xFFA855F7),
          ),
        ];

        if (twoCols) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: children[0]),
                  const SizedBox(width: 12),
                  Expanded(child: children[1]),
                ],
              ),
              const SizedBox(height: 12),
              children[2],
            ],
          );
        }

        return Column(
          children: [
            children[0],
            const SizedBox(height: 12),
            children[1],
            const SizedBox(height: 12),
            children[2],
          ],
        );
      },
    );
  }
}

class _BottomHint extends StatelessWidget {
  const _BottomHint({required this.isRunning});

  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.10)),
        color: scheme.onSurface.withValues(alpha: 0.03),
      ),
      child: Row(
        children: [
          Icon(
            isRunning
                ? Icons.wifi_tethering_rounded
                : Icons.info_outline_rounded,
            size: 18,
            color: scheme.onSurface.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isRunning
                  ? 'Mesure reseau en cours (ping/download/upload).'
                  : 'Mode reel actif. Tu peux aussi passer en mode manuel.',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoControls extends StatelessWidget {
  const _DemoControls({required this.controller});

  final SpeedtestController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        color: Colors.white.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Test jauge',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                'Manuel',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: controller.manualMode,
                onChanged: controller.isRunning
                    ? null
                    : controller.setManualMode,
              ),
            ],
          ),
          if (controller.manualMode) ...[
            const SizedBox(height: 8),
            Slider(
              value: controller.gaugeValueMbps.clamp(0.0, 1000.0),
              min: 0,
              max: 1000,
              divisions: 100,
              label: controller.gaugeValueMbps.toStringAsFixed(0),
              onChanged: controller.setManualValue,
            ),
          ],
        ],
      ),
    );
  }
}
