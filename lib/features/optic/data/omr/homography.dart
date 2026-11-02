import 'dart:math' as math;

/// Düzlemden düzleme perspektif dönüşümü (3×3, h33 = 1).
///
/// Fotoğraftaki kâğıt eğik ya da yamuk çekilse de şablondaki bir noktanın
/// fotoğrafta nereye düştüğünü dört karşılıklı noktadan hesaplar.
class Homography {
  const Homography._(this._h);

  final List<double> _h;

  /// [from] noktalarını [to] noktalarına götüren dönüşüm. Dört nokta
  /// gerekir; üçü aynı doğru üzerindeyse [StateError].
  factory Homography.fromPoints(
    List<({double x, double y})> from,
    List<({double x, double y})> to,
  ) {
    if (from.length != 4 || to.length != 4) {
      throw ArgumentError('Dört nokta gerekir');
    }
    // A · h = b (8 bilinmeyen).
    final a = List.generate(8, (_) => List.filled(9, 0.0));
    for (var i = 0; i < 4; i++) {
      final (x, y) = (from[i].x, from[i].y);
      final (u, v) = (to[i].x, to[i].y);
      a[2 * i]
        ..setAll(0, [x, y, 1, 0, 0, 0, -u * x, -u * y])
        ..[8] = u;
      a[2 * i + 1]
        ..setAll(0, [0, 0, 0, x, y, 1, -v * x, -v * y])
        ..[8] = v;
    }
    return Homography._([..._solve(a), 1]);
  }

  /// Çok sayıda (≥ 4) karşılıklı noktaya en küçük kareler dönüşümü.
  /// Sayısal kararlılık için noktalar önce merkezlenip ölçeklenir.
  factory Homography.fit(
    List<({double x, double y})> from,
    List<({double x, double y})> to,
  ) {
    if (from.length < 4 || from.length != to.length) {
      throw ArgumentError('En az dört nokta gerekir');
    }
    ({double cx, double cy, double s}) norm(List<({double x, double y})> p) {
      var cx = 0.0, cy = 0.0;
      for (final q in p) {
        cx += q.x;
        cy += q.y;
      }
      cx /= p.length;
      cy /= p.length;
      var d = 0.0;
      for (final q in p) {
        d += ((q.x - cx) * (q.x - cx) + (q.y - cy) * (q.y - cy));
      }
      // Ortalama uzaklık 1 olacak ölçek.
      return (cx: cx, cy: cy, s: d == 0 ? 1.0 : 1 / math.sqrt(d / p.length));
    }

    final nf = norm(from), nt = norm(to);
    // Normal denklemler: (AᵀA) h = Aᵀb, 8 bilinmeyen.
    final m = List.generate(8, (_) => List.filled(9, 0.0));
    void add(List<double> row, double rhs) {
      for (var i = 0; i < 8; i++) {
        for (var j = 0; j < 8; j++) {
          m[i][j] += row[i] * row[j];
        }
        m[i][8] += row[i] * rhs;
      }
    }

    for (var i = 0; i < from.length; i++) {
      final x = (from[i].x - nf.cx) * nf.s, y = (from[i].y - nf.cy) * nf.s;
      final u = (to[i].x - nt.cx) * nt.s, v = (to[i].y - nt.cy) * nt.s;
      add([x, y, 1, 0, 0, 0, -u * x, -u * y], u);
      add([0, 0, 0, x, y, 1, -v * x, -v * y], v);
    }
    final h = [..._solve(m), 1.0];
    // Normalizasyonu geri al: H = Tₜ⁻¹ · Hₙ · T_f.
    final tf = [
      nf.s,
      0.0,
      -nf.s * nf.cx,
      0.0,
      nf.s,
      -nf.s * nf.cy,
      0.0,
      0.0,
      1.0,
    ];
    final ti = [1 / nt.s, 0.0, nt.cx, 0.0, 1 / nt.s, nt.cy, 0.0, 0.0, 1.0];
    final r = _mul(_mul(ti, h), tf);
    return Homography._([for (final v in r) v / r[8]]);
  }

  static List<double> _mul(List<double> a, List<double> b) => [
    for (var r = 0; r < 3; r++)
      for (var c = 0; c < 3; c++)
        a[r * 3] * b[c] + a[r * 3 + 1] * b[3 + c] + a[r * 3 + 2] * b[6 + c],
  ];

  ({double x, double y}) map(double x, double y) {
    final h = _h;
    final w = h[6] * x + h[7] * y + h[8];
    return (
      x: (h[0] * x + h[1] * y + h[2]) / w,
      y: (h[3] * x + h[4] * y + h[5]) / w,
    );
  }

  /// Kısmi pivotlamalı Gauss eliminasyonu ([a]: 8 × 9 genişletilmiş matris).
  static List<double> _solve(List<List<double>> a) {
    const n = 8;
    for (var c = 0; c < n; c++) {
      var p = c;
      for (var r = c + 1; r < n; r++) {
        if (a[r][c].abs() > a[p][c].abs()) p = r;
      }
      if (a[p][c].abs() < 1e-12) throw StateError('Noktalar dönüşüm vermiyor');
      final t = a[c];
      a[c] = a[p];
      a[p] = t;
      for (var r = 0; r < n; r++) {
        if (r == c) continue;
        final f = a[r][c] / a[c][c];
        if (f == 0) continue;
        for (var k = c; k <= n; k++) {
          a[r][k] -= f * a[c][k];
        }
      }
    }
    return [for (var r = 0; r < n; r++) a[r][n] / a[r][r]];
  }
}
