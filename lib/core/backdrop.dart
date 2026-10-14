import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mini_game.dart';
import 'theme.dart';

/// Açık olan oyunun vurgu rengini alt widget'lara taşır (HUD, oyun sonu paneli).
class GameAccent extends InheritedWidget {
  const GameAccent({super.key, required this.color, required super.child});

  final Color color;

  static Color of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<GameAccent>();
    return w?.color ?? AppColors.accent;
  }

  @override
  bool updateShouldNotify(GameAccent oldWidget) => oldWidget.color != color;
}

/// Oyun ekranı için yumuşak geçişli açılış rotası; oyunun rengiyle boyanmış
/// canlı arka plan ekler. Ana menü ve "sürpriz" düğmeleri bunu kullanır.
Route<void> gameRoute(MiniGame game) {
  return PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => GameAccent(
      color: game.color,
      child: AmbientBackground(color: game.color, child: game.builder()),
    ),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Koyu gradyan zemin + yavaşça kayan renkli ışık lekeleri + süzülen toz
/// parçacıkları. Tek bir [CustomPainter] ile çizilir, oyunun kendi
/// yeniden çizimlerinden bağımsızdır.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({
    super.key,
    required this.color,
    required this.child,
  });

  final Color color;
  final Widget child;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _AmbientPainter(_c, widget.color),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.t, this.color) : super(repaint: t);

  final Animation<double> t;
  final Color color;

  static const int _dots = 26;

  static double _frac(double v) => v - v.floorToDouble();

  void _glow(Canvas canvas, Offset c, double radius, Color col) {
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [col, col.withAlpha(0)],
        ).createShader(Rect.fromCircle(center: c, radius: radius)),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF191C2A), AppColors.bgDeep],
        ).createShader(rect),
    );

    final a = t.value * 2 * math.pi;
    final side = size.shortestSide;
    _glow(
      canvas,
      Offset(size.width * (0.18 + 0.10 * math.sin(a)), size.height * (0.10 + 0.04 * math.cos(a))),
      side * 0.95,
      color.withAlpha(58),
    );
    _glow(
      canvas,
      Offset(size.width * (0.85 + 0.08 * math.cos(a)), size.height * (0.88 + 0.04 * math.sin(a))),
      side * 0.85,
      AppColors.violet.withAlpha(34),
    );

    // Süzülen toz: her parçacık döngü boyunca tam sayıda tur attığı için
    // animasyon kesintisiz tekrar eder.
    final dot = Paint();
    for (var i = 0; i < _dots; i++) {
      final x = _frac(math.sin(i * 12.9898) * 43758.5453);
      final y0 = _frac(math.sin(i * 78.233) * 24634.6345);
      final cycles = 1 + (i % 3);
      final y = _frac(y0 - t.value * cycles);
      final twinkle = 0.5 + 0.5 * math.sin(a * (1 + i % 2) + i);
      final r = 0.8 + (i % 4) * 0.45;
      dot.color = Colors.white.withAlpha((14 + 36 * twinkle).round());
      canvas.drawCircle(Offset(x * size.width, y * size.height), r, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) => old.color != color;
}
