import 'dart:math' as math;
import 'dart:ui';

import '../../../core/i18n/i18n.dart';
import '../../tracking/data/tracking_models.dart';

/// Çiçek türü: dersin grubuna göre.
enum FlowerKind {
  daisy, // Matematik: papatya
  tulip, // Türkçe / Edebiyat / Yabancı dil: lale
  bell, // Fen: mavi çan çiçeği
  sunflower, // Sosyal: ayçiçeği
  cosmos; // Ders seçilmemiş: pembe kozmos

  String get label => switch (this) {
    daisy => tr('Matematik'),
    tulip => tr('Türkçe, Edebiyat, Dil'),
    bell => tr('Fen'),
    sunflower => tr('Sosyal'),
    cosmos => tr('Ders seçilmemiş'),
  };

  String get flowerName => switch (this) {
    daisy => tr('Papatya'),
    tulip => tr('Lale'),
    bell => tr('Çan çiçeği'),
    sunflower => tr('Ayçiçeği'),
    cosmos => tr('Kozmos'),
  };

  Color get petal => switch (this) {
    daisy => const Color(0xFFFFFFFF),
    tulip => const Color(0xFFFF4D6D),
    bell => const Color(0xFF5B8CFF),
    sunflower => const Color(0xFFFFC233),
    cosmos => const Color(0xFFFF8FD1),
  };

  Color get center => switch (this) {
    daisy => const Color(0xFFFFC233),
    tulip => const Color(0xFFB0183D),
    bell => const Color(0xFFFFF4C2),
    sunflower => const Color(0xFF6B3A12),
    cosmos => const Color(0xFFFFE066),
  };

  static FlowerKind of(String? subjectCode) {
    if (subjectCode == null) return cosmos;
    final c = subjectCode.toUpperCase();
    if (c.contains('MAT')) return daisy;
    if (c.contains('FIZ') || c.contains('KIM') || c.contains('BIY')) {
      return bell;
    }
    if (c.contains('TUR') || c.contains('EDB') || c.startsWith('YDT')) {
      return tulip;
    }
    return sunflower;
  }
}

/// Oturumun büyüklüğü: süre uzadıkça çiçek büyür; yarıda bırakılan
/// pomodoro solar.
enum FlowerSize {
  wilted,
  sprout,
  bud,
  bloom,
  grand;

  static FlowerSize of(StudySession s) {
    final min = s.durationSec / 60;
    if (s.type == SessionType.pomodoro && min < 20) return wilted;
    if (min < 10) return sprout;
    if (min < 25) return bud;
    if (min < 50) return bloom;
    return grand;
  }

  String get label => switch (this) {
    wilted => tr('Yarıda kaldı (soldu)'),
    sprout => tr('Filiz (10 dk altı)'),
    bud => tr('Tomurcuk (10-25 dk)'),
    bloom => tr('Çiçek (25-50 dk)'),
    grand => tr('Dev çiçek (50 dk+)'),
  };
}

/// Bahçedeki bir çiçek: oturum + bahçedeki yeri.
class GardenFlower {
  const GardenFlower({
    required this.session,
    required this.kind,
    required this.size,
    required this.position,
    required this.phase,
  });

  final StudySession session;
  final FlowerKind kind;
  final FlowerSize size;

  /// Tarladaki yeri (piksel).
  final Offset position;

  /// Rüzgârda sallanma için faz (0..1).
  final double phase;
}

/// Oturumlardan bahçe yerleşimi. En yeni çiçekler önde (altta); yerler
/// oturum kimliğinden üretilir, her açılışta aynıdır.
class GardenLayout {
  GardenLayout._(this.flowers, this.size);

  factory GardenLayout.of(List<StudySession> sessions, double width) {
    // Aynı anda başlayan oturumlar kimliğe göre: yerleşim her açılışta aynı.
    final sorted = [...sessions]
      ..sort((a, b) {
        final c = a.startedAt.compareTo(b.startedAt);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    final cols = math.max(4, (width / 74).floor());
    const rowH = 76.0;
    final cellW = width / cols;
    final rows = (sorted.length / cols).ceil();
    final flowers = <GardenFlower>[];
    for (var i = 0; i < sorted.length; i++) {
      final s = sorted[i];
      final rnd = math.Random(s.id.hashCode);
      final row = i ~/ cols;
      final col = i % cols;
      // Satırlar şaşırtmalı; hücre içinde rastgele kayma.
      final x =
          cellW * (col + 0.5 + (row.isOdd ? 0.25 : -0.15)) +
          (rnd.nextDouble() - 0.5) * cellW * 0.45;
      final y = 90 + row * rowH + (rnd.nextDouble() - 0.5) * 22;
      flowers.add(
        GardenFlower(
          session: s,
          kind: FlowerKind.of(s.subjectCode),
          size: FlowerSize.of(s),
          position: Offset(x.clamp(18, width - 18), y),
          phase: rnd.nextDouble(),
        ),
      );
    }
    // Arkadakiler (eskiler, üstte) önce çizilsin.
    flowers.sort((a, b) {
      final c = a.position.dy.compareTo(b.position.dy);
      return c != 0 ? c : a.session.id.compareTo(b.session.id);
    });
    return GardenLayout._(flowers, Size(width, 150 + rows * rowH));
  }

  final List<GardenFlower> flowers;
  final Size size;

  /// Dokunulan noktadaki çiçek (en öndeki).
  GardenFlower? hit(Offset p) {
    for (final f in flowers.reversed) {
      final d = p - (f.position - const Offset(0, 26));
      if (d.dx.abs() < 26 && d.dy.abs() < 34) return f;
    }
    return null;
  }
}
