import 'dart:math' as math;

import 'package:flutter/painting.dart' show Color;

/// 8 bit sRGB renk (Flutter'ın Color sürüm farklarından bağımsız tutulur).
class Rgb {
  const Rgb(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;

  Color toColor() => Color.fromARGB(255, r, g, b);

  /// 0..1 arası algısal parlaklık (metin rengi seçimi için).
  double get luminance {
    double lin(int c) {
      final v = c / 255.0;
      return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
  }

  @override
  bool operator ==(Object other) =>
      other is Rgb && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(r, g, b);

  @override
  String toString() => 'Rgb($r, $g, $b)';
}

/// CIELAB renk (D65).
class Lab {
  const Lab(this.l, this.a, this.b);

  final double l;
  final double a;
  final double b;
}

class ColorUtils {
  ColorUtils._();

  // D65 beyaz noktası
  static const double _xn = 0.95047;
  static const double _yn = 1.0;
  static const double _zn = 1.08883;

  static double _toLinear(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  static double _fromLinear(double c) => c <= 0.0031308
      ? 12.92 * c
      : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;

  static double _f(double t) {
    const d = 6 / 29;
    return t > d * d * d ? math.pow(t, 1 / 3).toDouble() : t / (3 * d * d) + 4 / 29;
  }

  static double _fInv(double t) {
    const d = 6 / 29;
    return t > d ? t * t * t : 3 * d * d * (t - 4 / 29);
  }

  static Lab rgbToLab(Rgb c) {
    final r = _toLinear(c.r / 255.0);
    final g = _toLinear(c.g / 255.0);
    final b = _toLinear(c.b / 255.0);

    final x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b;
    final y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b;
    final z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b;

    final fx = _f(x / _xn);
    final fy = _f(y / _yn);
    final fz = _f(z / _zn);

    return Lab(116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
  }

  /// LAB -> sRGB. Renk sRGB gamutunun dışındaysa null döner.
  static Rgb? labToRgb(Lab c) {
    final fy = (c.l + 16) / 116;
    final fx = fy + c.a / 500;
    final fz = fy - c.b / 200;

    final x = _xn * _fInv(fx);
    final y = _yn * _fInv(fy);
    final z = _zn * _fInv(fz);

    final rl = 3.2404542 * x - 1.5371385 * y - 0.4985314 * z;
    final gl = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z;
    final bl = 0.0556434 * x - 0.2040259 * y + 1.0572252 * z;

    const eps = 0.002;
    if (rl < -eps || rl > 1 + eps || gl < -eps || gl > 1 + eps || bl < -eps || bl > 1 + eps) {
      return null;
    }

    int to8(double v) =>
        (_fromLinear(v.clamp(0.0, 1.0).toDouble()) * 255).round().clamp(0, 255);

    return Rgb(to8(rl), to8(gl), to8(bl));
  }

  /// CIE76 renk farkı (ΔE). 2 civarı gözle zor ayırt edilir.
  static double deltaE(Lab p, Lab q) {
    final dl = p.l - q.l;
    final da = p.a - q.a;
    final db = p.b - q.b;
    return math.sqrt(dl * dl + da * da + db * db);
  }

  static double deltaERgb(Rgb p, Rgb q) => deltaE(rgbToLab(p), rgbToLab(q));

  /// HSL -> Rgb (h: 0..360, s/l: 0..1)
  static Rgb hslToRgb(double h, double s, double l) {
    final c = (1 - (2 * l - 1).abs()) * s;
    final hp = (h % 360) / 60;
    final x = c * (1 - ((hp % 2) - 1).abs());
    double r = 0, g = 0, b = 0;
    if (hp < 1) {
      r = c;
      g = x;
    } else if (hp < 2) {
      r = x;
      g = c;
    } else if (hp < 3) {
      g = c;
      b = x;
    } else if (hp < 4) {
      g = x;
      b = c;
    } else if (hp < 5) {
      r = x;
      b = c;
    } else {
      r = c;
      b = x;
    }
    final m = l - c / 2;
    int to8(double v) => ((v + m) * 255).round().clamp(0, 255);
    return Rgb(to8(r), to8(g), to8(b));
  }
}
