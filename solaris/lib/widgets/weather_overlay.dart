import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class WeatherOverlay extends StatefulWidget {
  final int weatherCode;
  final double cloudCover; // Clouds coverage percentage (0-100)

  const WeatherOverlay({
    super.key,
    required this.weatherCode,
    this.cloudCover = 0,
  });

  @override
  State<WeatherOverlay> createState() => _WeatherOverlayState();
}

class _Particle {
  double x;
  double y;
  double speed;
  double size;
  double angle;
  double wobblePhase;
  double wobbleSpeed;
  double thickness;

  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.angle,
    required this.wobblePhase,
    required this.wobbleSpeed,
    required this.thickness,
  });
}

class _Cloud {
  double x;
  double y;
  double speed;
  double scale;
  double opacity;
  double floatPhase;
  double floatSpeed;
  late List<Offset> offsets;
  late List<double> radii;

  _Cloud({
    required this.x,
    required this.y,
    required this.speed,
    required this.scale,
    required this.opacity,
    required this.floatPhase,
    required this.floatSpeed,
  }) {
    // Generate a horizontal, elongated puffy cloud shape
    offsets = [
      const Offset(-25, 5),    // Left bottom
      const Offset(25, 5),     // Right bottom
      const Offset(0, 10),     // Middle bottom (slightly lower)
      const Offset(-12, -10),  // Top left puff
      const Offset(15, -8),    // Top right puff
      const Offset(-40, 2),    // Far left small puff
      const Offset(40, 2),     // Far right small puff
    ];
    radii = [
      20.0, // Left bottom
      22.0, // Right bottom
      18.0, // Middle bottom
      16.0, // Top left
      18.0, // Top right
      12.0, // Far left
      13.0, // Far right
    ];
  }
}

class _WeatherOverlayState extends State<WeatherOverlay>
    with TickerProviderStateMixin {
  late Ticker _ticker;
  late AnimationController _thunderController;
  final Random _random = Random();
  bool _isLightningStricking = false;

  List<_Particle> _particles = [];
  List<_Cloud> _clouds = [];
  Duration _lastElapsed = Duration.zero;

  bool _isRain = false;
  bool _isSnow = false;
  bool _isHeavy = false;
  bool _isLight = false;
  int _targetParticleCount = 0;

  @override
  void initState() {
    super.initState();
    _updateWeatherFlags();

    _ticker = createTicker(_onTick)..start();

    _thunderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scheduleNextLightning();
  }

  @override
  void didUpdateWidget(WeatherOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weatherCode != widget.weatherCode ||
        oldWidget.cloudCover != widget.cloudCover) {
      _updateWeatherFlags();
    }
  }

  void _updateWeatherFlags() {
    int code = widget.weatherCode;
    _isRain =
        (code >= 50 && code <= 69) ||
        (code >= 80 && code <= 82) ||
        (code >= 95 && code <= 99);

    _isSnow = (code >= 70 && code <= 79) || (code >= 85 && code <= 86);

    _isHeavy =
        code == 65 ||
        code == 82 ||
        code >= 95 ||
        code == 75 ||
        code == 77 ||
        code == 86;
    _isLight =
        code == 50 ||
        code == 51 ||
        code == 56 ||
        code == 80 ||
        code == 71 ||
        code == 85;

    if (_isRain || _isSnow) {
      if (_isHeavy) {
        _targetParticleCount = _isSnow ? 300 : 250;
      } else if (_isLight) {
        _targetParticleCount = _isSnow ? 80 : 60;
      } else {
        _targetParticleCount = _isSnow ? 150 : 120;
      }
    } else {
      _targetParticleCount = 0;
    }
  }

  void _updateCloudCount(double width, double height) {
    // User requested: "if cloudiness is strong, then there will be fewer clouds and smaller"
    // We'll interpret this as: 
    // cloudCover 0 -> 0 clouds
    // cloudCover 1-30 -> 10 clouds (large)
    // cloudCover 30-70 -> 6 clouds (medium)
    // cloudCover 70-100 -> 3 clouds (small)
    
    int targetCloudCount;
    if (widget.cloudCover <= 0) {
      targetCloudCount = 0;
    } else if (widget.cloudCover < 30) {
      targetCloudCount = 10;
    } else if (widget.cloudCover < 70) {
      targetCloudCount = 6;
    } else {
      targetCloudCount = 3;
    }

    if (_clouds.length < targetCloudCount) {
      int toAdd = targetCloudCount - _clouds.length;
      for (int i = 0; i < toAdd; i++) {
        _clouds.add(_spawnCloud(width, height, randomizeX: true));
      }
    } else if (_clouds.length > targetCloudCount) {
      _clouds.removeRange(targetCloudCount, _clouds.length);
    }
  }

  _Cloud _spawnCloud(double width, double height, {bool randomizeX = false}) {
    // Base scale modified by cloud cover as requested
    double baseScale = 0.8 + _random.nextDouble() * 0.8;
    if (widget.cloudCover > 70) {
      baseScale *= 0.6; // Smaller for strong cloudiness
    } else if (widget.cloudCover > 30) {
      baseScale *= 0.8;
    }

    return _Cloud(
      x: randomizeX ? _random.nextDouble() * width : -100,
      y: _random.nextDouble() * (height * 0.6), // Upper half mostly
      speed: 10.0 + _random.nextDouble() * 20.0,
      scale: baseScale,
      opacity: 0.5 + _random.nextDouble() * 0.3, // Slightly more opaque to see the outline
      floatPhase: _random.nextDouble() * pi * 2,
      floatSpeed: 0.5 + _random.nextDouble() * 1.0,
    );
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }

    final double dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    final size = MediaQuery.maybeSizeOf(context) ?? const Size(400, 800);
    final width = size.width;
    final height = size.height;

    _updateCloudCount(width, height);

    if (_particles.length < _targetParticleCount) {
      int toAdd = _targetParticleCount - _particles.length;
      for (int i = 0; i < toAdd; i++) {
        _particles.add(_spawnParticle(width, height, randomizeY: true));
      }
    } else if (_particles.length > _targetParticleCount) {
      _particles.removeRange(_targetParticleCount, _particles.length);
    }

    for (var p in _particles) {
      if (_isSnow) {
        p.y += p.speed * dt;
        p.wobblePhase += p.wobbleSpeed * dt;
      } else {
        p.x += sin(p.angle) * p.speed * dt;
        p.y += cos(p.angle) * p.speed * dt;
      }

      if (p.y > height + 50) {
        _respawnParticle(p, width, height, topOnly: true);
      }
      if (p.x < -50) {
        p.x = width + 50;
      } else if (p.x > width + 50) {
        p.x = -50;
      }
    }

    for (var c in _clouds) {
      c.x += c.speed * dt;
      c.floatPhase += c.floatSpeed * dt;

      if (c.x > width + 100) {
        c.x = -100;
        c.y = _random.nextDouble() * (height * 0.6);
      }
    }

    setState(() {});
  }

  _Particle _spawnParticle(
    double width,
    double height, {
    bool randomizeY = false,
  }) {
    double x = _random.nextDouble() * (width + 100) - 50;
    double y = randomizeY ? _random.nextDouble() * height : -50.0;

    double speed;
    double size;
    double angle = 0.0;
    double wobblePhase = _random.nextDouble() * pi * 2;
    double wobbleSpeed = 0.0;
    double thickness;

    if (_isSnow) {
      speed =
          (_isHeavy
              ? 150.0
              : _isLight
              ? 60.0
              : 100.0) +
          _random.nextDouble() * 50.0;
      size =
          (_isHeavy
              ? 3.0
              : _isLight
              ? 1.5
              : 2.5) +
          _random.nextDouble() * 1.5;
      wobbleSpeed = 1.0 + _random.nextDouble() * 2.0;
      thickness = 0.0;
    } else {
      speed =
          (_isHeavy
              ? 700.0
              : _isLight
              ? 300.0
              : 500.0) +
          _random.nextDouble() * 200.0;
      size =
          (_isHeavy
              ? 20.0
              : _isLight
              ? 8.0
              : 15.0) +
          _random.nextDouble() * 10.0;
      angle = _isHeavy
          ? (0.2 + _random.nextDouble() * 0.1)
          : _isLight
          ? (0.05 + _random.nextDouble() * 0.05)
          : (0.1 + _random.nextDouble() * 0.05);
      thickness = _isHeavy
          ? 2.5
          : _isLight
          ? 1.0
          : 1.5;
    }

    return _Particle(
      x: x,
      y: y,
      speed: speed,
      size: size,
      angle: angle,
      wobblePhase: wobblePhase,
      wobbleSpeed: wobbleSpeed,
      thickness: thickness,
    );
  }

  void _respawnParticle(
    _Particle p,
    double width,
    double height, {
    bool topOnly = false,
  }) {
    final fresh = _spawnParticle(width, height, randomizeY: !topOnly);
    p.x = fresh.x;
    p.y = topOnly ? -50 : fresh.y;
    p.speed = fresh.speed;
    p.size = fresh.size;
    p.angle = fresh.angle;
    p.wobblePhase = fresh.wobblePhase;
    p.wobbleSpeed = fresh.wobbleSpeed;
    p.thickness = fresh.thickness;
  }

  void _scheduleNextLightning() {
    if (!mounted) return;
    if (widget.weatherCode >= 95 && widget.weatherCode <= 99) {
      final nextDelay = Duration(milliseconds: 2000 + _random.nextInt(5000));
      Future.delayed(nextDelay, () {
        if (!mounted) return;
        _strikeLightning();
        _scheduleNextLightning();
      });
    }
  }

  Future<void> _strikeLightning() async {
    if (!mounted) return;
    setState(() => _isLightningStricking = true);
    await _thunderController.forward(from: 0.0);
    await _thunderController.reverse();
    if (mounted) setState(() => _isLightningStricking = false);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _thunderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRain && !_isSnow && !_isLightningStricking && _clouds.isEmpty)
      return const SizedBox.shrink();

    return Stack(
      children: [
        if (_clouds.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: CloudPainter(clouds: _clouds),
                willChange: true,
              ),
            ),
          ),
        if (_isRain || _isSnow)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: PrecipitationSystemPainter(
                  particles: _particles,
                  isSnow: _isSnow,
                ),
                willChange: true,
              ),
            ),
          ),
        if (_isLightningStricking)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _thunderController,
                builder: (context, child) {
                  return Container(
                    color: Colors.white.withOpacity(
                      _thunderController.value * 0.6,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class PrecipitationSystemPainter extends CustomPainter {
  final List<_Particle> particles;
  final bool isSnow;

  PrecipitationSystemPainter({required this.particles, required this.isSnow});

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;

    final paint = Paint()
      ..color = Colors.white.withOpacity(isSnow ? 0.7 : 0.4)
      ..strokeCap = StrokeCap.round;

    for (var p in particles) {
      if (isSnow) {
        paint.style = PaintingStyle.fill;
        double wobbleOffset = sin(p.wobblePhase) * 15.0;
        canvas.drawCircle(Offset(p.x + wobbleOffset, p.y), p.size, paint);
      } else {
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = p.thickness;
        double dx = sin(p.angle) * p.size;
        double dy = cos(p.angle) * p.size;
        canvas.drawLine(Offset(p.x, p.y), Offset(p.x - dx, p.y - dy), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PrecipitationSystemPainter oldDelegate) {
    return true;
  }
}

class CloudPainter extends CustomPainter {
  final List<_Cloud> clouds;

  CloudPainter({required this.clouds});

  @override
  void paint(Canvas canvas, Size size) {
    for (var cloud in clouds) {
      final floatOffset = sin(cloud.floatPhase) * 5.0;

      // To draw a single outline for the whole shape, we must UNION the paths
      Path cloudPath = Path();
      for (int i = 0; i < cloud.offsets.length; i++) {
        final center = Offset(
          cloud.x + cloud.offsets[i].dx * cloud.scale,
          cloud.y + (cloud.offsets[i].dy + floatOffset) * cloud.scale,
        );
        final Path circlePath = Path();
        circlePath.addOval(Rect.fromCircle(
          center: center,
          radius: cloud.radii[i] * cloud.scale,
        ));
        
        // Combine paths to create a single silhouette
        cloudPath = Path.combine(PathOperation.union, cloudPath, circlePath);
      }

      // 1. Draw the Body (Greyish, blurred for soft appearance)
      final bodyPaint = Paint()
        ..color = const Color(0xFF94A3B8).withOpacity(cloud.opacity) // Elegant slate grey
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(cloudPath, bodyPaint);

      // 2. Draw the Outline (Single continuous line)
      final outlinePaint = Paint()
        ..color = const Color(0xFF1E293B).withOpacity(0.5) // Darker slate for outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(cloudPath, outlinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CloudPainter oldDelegate) => true;
}
