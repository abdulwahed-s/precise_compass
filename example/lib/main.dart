import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:precise_compass/precise_compass.dart';

void main() => runApp(const PreciseCompassApp());

class PreciseCompassApp extends StatelessWidget {
  const PreciseCompassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'precise_compass',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const CompassPage(),
    );
  }
}

class CompassPage extends StatefulWidget {
  const CompassPage({super.key});

  @override
  State<CompassPage> createState() => _CompassPageState();
}

class _CompassPageState extends State<CompassPage> {
  CompassConfig _config = const CompassConfig();
  late Stream<CompassReading> _stream = PreciseCompass.headingStream(
    config: _config,
  );
  CompassCapabilities? _capabilities;
  bool _hasLocation = false;

  @override
  void initState() {
    super.initState();
    _refreshPermission();
    PreciseCompass.capabilities().then((caps) {
      if (mounted) setState(() => _capabilities = caps);
    });
  }

  Future<void> _refreshPermission() async {
    final status = await Permission.locationWhenInUse.status;
    if (mounted) setState(() => _hasLocation = status.isGranted);
  }

  void _updateConfig(CompassConfig config) {
    setState(() {
      _config = config;
      _stream = PreciseCompass.headingStream(config: config);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('precise_compass'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Enable true heading (location)',
            onPressed: () async {
              await Permission.locationWhenInUse.request();
              await _refreshPermission();
            },
          ),
        ],
      ),
      body: StreamBuilder<CompassReading>(
        stream: _stream,
        builder: (context, snapshot) {
          final reading = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_hasLocation)
                const _InfoBanner(
                  icon: Icons.info_outline,
                  text: 'Grant location (top-right) for TRUE north; '
                      'magnetic north works without it.',
                ),
              if (reading != null && reading.shouldCalibrate)
                const CalibrationBanner(),
              const SizedBox(height: 8),
              CompassDialView(reading: reading),
              const SizedBox(height: 24),
              if (reading != null) ReadingDetails(reading: reading),
              const SizedBox(height: 16),
              ConfigControls(config: _config, onChanged: _updateConfig),
              const SizedBox(height: 16),
              if (_capabilities != null)
                CapabilitiesView(capabilities: _capabilities!),
            ],
          );
        },
      ),
    );
  }
}

/// The rotating compass rose with a fixed pointer at the top.
class CompassDialView extends StatelessWidget {
  const CompassDialView({required this.reading, super.key});

  final CompassReading? reading;

  @override
  Widget build(BuildContext context) {
    final heading = reading?.hasHeading ?? false ? reading!.heading : null;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (heading == null)
            const Center(child: Text('Waiting for compass…'))
          else
            TweenAnimationBuilder<double>(
              tween: Tween(begin: heading, end: heading),
              duration: const Duration(milliseconds: 120),
              builder: (context, value, _) => CustomPaint(
                size: Size.infinite,
                painter: _DialPainter(
                  heading: value,
                  color: Theme.of(context).colorScheme.primary,
                  onSurface: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          if (heading != null)
            Text(
              '${heading.round()}°',
              style: Theme.of(context).textTheme.displaySmall,
            ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.heading,
    required this.color,
    required this.onSurface,
  });

  final double heading;
  final Color color;
  final Color onSurface;

  static const List<String> _marks = ['N', 'E', 'S', 'W'];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = onSurface.withValues(alpha: 0.2);
    canvas.drawCircle(center, radius, ring);

    // Fixed pointer at the top (the direction the device faces).
    final pointer = Paint()..color = color;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius - 2)
      ..lineTo(center.dx - 10, center.dy - radius + 18)
      ..lineTo(center.dx + 10, center.dy - radius + 18)
      ..close();
    canvas.drawPath(path, pointer);

    // Rotate the rose so north points to actual north.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading * math.pi / 180);
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2 - math.pi / 2;
      final isNorth = i == 0;
      final tp = TextPainter(
        text: TextSpan(
          text: _marks[i],
          style: TextStyle(
            color: isNorth ? Colors.red : onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final offset = Offset(
        math.cos(angle) * (radius - 22) - tp.width / 2,
        math.sin(angle) * (radius - 22) - tp.height / 2,
      );
      tp.paint(canvas, offset);
    }
    for (var deg = 0; deg < 360; deg += 15) {
      final angle = deg * math.pi / 180 - math.pi / 2;
      final isMajor = deg % 45 == 0;
      final tick = Paint()
        ..color = onSurface.withValues(alpha: isMajor ? 0.5 : 0.2)
        ..strokeWidth = isMajor ? 2 : 1;
      final inner = radius - (isMajor ? 14 : 8);
      canvas.drawLine(
        Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        Offset(math.cos(angle) * radius, math.sin(angle) * radius),
        tick,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.heading != heading;
}

/// Numeric heading, accuracy chip and a confidence meter.
class ReadingDetails extends StatelessWidget {
  const ReadingDetails({required this.reading, super.key});

  final CompassReading reading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final acc = reading.accuracyDegrees.clamp(0, 999).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Tag(
              label: reading.headingTrue != null ? 'TRUE' : 'MAGNETIC',
              color: theme.colorScheme.primaryContainer,
            ),
            _Tag(
              label: '± $acc°  ${reading.accuracy.name}',
              color: _accuracyColor(reading.accuracy),
            ),
            _Tag(
              label: reading.source.name,
              color: theme.colorScheme.surfaceContainerHighest,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Confidence', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: reading.confidence,
            minHeight: 14,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: Color.lerp(
              Colors.red,
              Colors.green,
              reading.confidence,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('${(reading.confidence * 100).toStringAsFixed(0)}%'),
        if (reading.magneticFieldMagnitude != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Magnetic field: '
              '${reading.magneticFieldMagnitude!.toStringAsFixed(1)} µT '
              '(Earth ≈ 25–65 µT)',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Color _accuracyColor(CompassAccuracy accuracy) => switch (accuracy) {
        CompassAccuracy.high => Colors.green.shade200,
        CompassAccuracy.medium => Colors.lightGreen.shade200,
        CompassAccuracy.low => Colors.orange.shade200,
        CompassAccuracy.unreliable => Colors.red.shade200,
        CompassAccuracy.unknown => Colors.grey.shade300,
      };
}

/// Reference / rate / fusion-mode selectors.
class ConfigControls extends StatelessWidget {
  const ConfigControls({
    required this.config,
    required this.onChanged,
    super.key,
  });

  final CompassConfig config;
  final ValueChanged<CompassConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuration',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _row(
              'Reference',
              DropdownButton<HeadingReference>(
                value: config.reference,
                onChanged: (v) => onChanged(
                  config.copyWith(reference: v ?? config.reference),
                ),
                items: [
                  for (final r in HeadingReference.values)
                    DropdownMenuItem(value: r, child: Text(r.name)),
                ],
              ),
            ),
            _row(
              'Rate',
              DropdownButton<SensorRate>(
                value: config.rate,
                onChanged: (v) =>
                    onChanged(config.copyWith(rate: v ?? config.rate)),
                items: [
                  for (final r in SensorRate.values)
                    DropdownMenuItem(value: r, child: Text(r.name)),
                ],
              ),
            ),
            _row(
              'Fusion',
              DropdownButton<FusionMode>(
                value: config.fusionMode,
                onChanged: (v) => onChanged(
                  config.copyWith(fusionMode: v ?? config.fusionMode),
                ),
                items: [
                  for (final m in FusionMode.values)
                    DropdownMenuItem(value: m, child: Text(m.name)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, Widget control) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), control],
        ),
      );
}

/// Read-only device capability list.
class CapabilitiesView extends StatelessWidget {
  const CapabilitiesView({required this.capabilities, super.key});

  final CompassCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final caps = capabilities;
    final entries = <String, bool>{
      'Rotation vector': caps.hasRotationVector,
      'Geomagnetic RV': caps.hasGeomagneticRotationVector,
      'Magnetometer': caps.hasMagnetometer,
      'Gyroscope': caps.hasGyroscope,
      'Accelerometer': caps.hasAccelerometer,
      'True heading': caps.supportsTrueHeading,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Capabilities — recommended: ${caps.recommendedMode.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final entry in entries.entries)
              Row(
                children: [
                  Icon(
                    entry.value ? Icons.check_circle : Icons.cancel,
                    size: 18,
                    color: entry.value ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(entry.key),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A pulsing banner with an animated figure-8 when calibration is recommended.
class CalibrationBanner extends StatefulWidget {
  const CalibrationBanner({super.key});

  @override
  State<CalibrationBanner> createState() => _CalibrationBannerState();
}

class _CalibrationBannerState extends State<CalibrationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _FigureEightPainter(_controller.value),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Compass needs calibration. Move your device in a '
                'figure-8 motion.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FigureEightPainter extends CustomPainter {
  _FigureEightPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.orange.shade700;
    final path = Path();
    for (var i = 0; i <= 60; i++) {
      final a = i / 60 * 2 * math.pi;
      final x = w / 2 + w / 3 * math.sin(a);
      final y = h / 2 + h / 3 * math.sin(a) * math.cos(a) * 2;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, stroke);

    final a = t * 2 * math.pi;
    final dot = Offset(
      w / 2 + w / 3 * math.sin(a),
      h / 2 + h / 3 * math.sin(a) * math.cos(a) * 2,
    );
    canvas.drawCircle(dot, 4, Paint()..color = Colors.orange.shade900);
  }

  @override
  bool shouldRepaint(_FigureEightPainter old) => old.t != t;
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
