import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class WeatherOverlay extends StatefulWidget {
  final int weatherCode;

  const WeatherOverlay({super.key, required this.weatherCode});

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

class _WeatherOverlayState extends State<WeatherOverlay> with TickerProviderStateMixin {
  late Ticker _ticker;
  late AnimationController _thunderController;
  final Random _random = Random();
  bool _isLightningStricking = false;

  List<_Particle> _particles = [];
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
    if (oldWidget.weatherCode != widget.weatherCode) {
      _updateWeatherFlags();
    }
  }

  void _updateWeatherFlags() {
    int code = widget.weatherCode;
    _isRain = (code >= 50 && code <= 69) ||
        (code >= 80 && code <= 82) ||
        (code >= 95 && code <= 99);

    _isSnow = (code >= 70 && code <= 79) ||
        (code >= 85 && code <= 86);

    _isHeavy = code == 65 || code == 82 || code >= 95 || code == 75 || code == 77 || code == 86;
    _isLight = code == 50 || code == 51 || code == 56 || code == 80 || code == 71 || code == 85;

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

    setState(() {});
  }

  _Particle _spawnParticle(double width, double height, {bool randomizeY = false}) {
    double x = _random.nextDouble() * (width + 100) - 50;
    double y = randomizeY ? _random.nextDouble() * height : -50.0;
    
    double speed;
    double size;
    double angle = 0.0;
    double wobblePhase = _random.nextDouble() * pi * 2;
    double wobbleSpeed = 0.0;
    double thickness;

    if (_isSnow) {
      speed = (_isHeavy ? 150.0 : _isLight ? 60.0 : 100.0) + _random.nextDouble() * 50.0;
      size = (_isHeavy ? 3.0 : _isLight ? 1.5 : 2.5) + _random.nextDouble() * 1.5; 
      wobbleSpeed = 1.0 + _random.nextDouble() * 2.0;
      thickness = 0.0;
    } else {
      speed = (_isHeavy ? 700.0 : _isLight ? 300.0 : 500.0) + _random.nextDouble() * 200.0;
      size = (_isHeavy ? 20.0 : _isLight ? 8.0 : 15.0) + _random.nextDouble() * 10.0; 
      angle = _isHeavy ? (0.2 + _random.nextDouble() * 0.1) : _isLight ? (0.05 + _random.nextDouble() * 0.05) : (0.1 + _random.nextDouble() * 0.05);
      thickness = _isHeavy ? 2.5 : _isLight ? 1.0 : 1.5;
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

  void _respawnParticle(_Particle p, double width, double height, {bool topOnly = false}) {
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
    if (!_isRain && !_isSnow && !_isLightningStricking) return const SizedBox.shrink();

    return Stack(
      children: [
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
                    color: Colors.white.withOpacity(_thunderController.value * 0.6),
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
