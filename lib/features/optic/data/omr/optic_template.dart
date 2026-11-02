import 'dart:math' as math;

import '../../../../core/constants/exam_subjects.dart';

/// Şablon sayfasında bir nokta (sayfa birimi; sol üst köşe 0,0).
typedef PagePoint = ({double x, double y});

/// Bir optik formun düzeni: köşe işaretleri, öğrenci numarası, oturum ve
/// kitapçık alanları ve soru blokları. Koordinatlar formun kendi biriminde
/// (A4 için 1000 × 1414); okuyucu fotoğrafı bu düzleme oturtur.
///
/// Aynı kâğıt birden çok sınavda kullanılabilir (TYT ve AYT aynı ızgarada,
/// farklı derslerle): [layouts] sınav türüne göre blokları verir.
/// Yeni bir form = [opticTemplates]'e yeni bir şablon.
class OpticTemplate {
  const OpticTemplate({
    required this.id,
    required this.trName,
    required this.width,
    required this.height,
    this.anchors = const [],
    this.anchorSize = 0,
    this.track,
    required this.bubbleRadius,
    required this.layouts,
    this.studentNumber,
    this.session,
    this.booklet,
    this.orientationMark,
    this.orientationMarkSize = 0,
  });

  /// Veritabanındaki `answer_keys.template_id` (küçük harf, rakam, `_`).
  final String id;
  final String trName;
  final double width;
  final double height;

  /// Hizalama, iki yoldan biriyle:
  ///  * [anchors]: dört köşedeki dolu kareler (sol üst, sağ üst, sağ alt,
  ///    sol alt). Kamera için en sağlamı; Mentoria formu bunu kullanır.
  ///  * [track]: kenardaki zamanlama çizgileri (optik okuyucu makinesi için
  ///    basılmış yayınevi / dershane formları).
  final List<PagePoint> anchors;

  /// Köşe işaretinin kenar uzunluğu.
  final double anchorSize;
  final TimingTrack? track;
  final double bubbleRadius;
  final Map<ExamType, List<AnswerBlock>> layouts;
  final NumberField? studentNumber;

  /// "1. Oturum TYT / 2. Oturum AYT" işareti (değerler: [ExamType.db]).
  final ChoiceField? session;

  /// Kitapçık türü (değerler: A, B).
  final ChoiceField? booklet;

  /// Sol üst köşe işaretinin yanındaki küçük kare: kâğıt ters ya da yan
  /// çekilse de hangi köşenin sol üst olduğu buradan anlaşılır.
  final PagePoint? orientationMark;
  final double orientationMarkSize;

  Iterable<ExamType> get examTypes => layouts.keys;

  List<AnswerBlock> blocksFor(ExamType type) => layouts[type] ?? const [];

  /// [type] sınavında şablonun kapsadığı dersler (blok sırasıyla).
  List<String> subjectCodes(ExamType type) => [
    for (final b in blocksFor(type)) ...b.subjects,
  ];
}

/// Kâğıdın kenarındaki zamanlama çizgileri: eşit aralıklı, aynı boyda
/// kısa siyah çubuklar (şablonda dikey bir sıra; içerik sağ taraftadır).
class TimingTrack {
  const TimingTrack({
    required this.x,
    required this.firstY,
    required this.dy,
    required this.count,
    required this.barWidth,
    required this.barHeight,
  });

  /// Çubukların merkez x'i ve ilk çubuğun merkez y'si.
  final double x;
  final double firstY;
  final double dy;
  final int count;
  final double barWidth;
  final double barHeight;

  PagePoint bar(int i) => (x: x, y: firstY + i * dy);
}

/// Alt alta dizilmiş sorular. Birden çok ders arka arkaya gelebilir (ör.
/// Sosyal Bilimler testi: Tarih 5 + Coğrafya 5 + Felsefe 5 + Din 5); her
/// dersin soru sayısı [examSubjects]'ten gelir. Uzun testler
/// [perColumn] soruda bir yan sütuna geçer.
class AnswerBlock {
  const AnswerBlock({
    required this.subjects,
    required this.x,
    required this.y,
    required this.optionDx,
    required this.rowDy,
    this.perColumn,
    this.columnDx = 0,
    this.options = 'ABCDE',
    this.trTitle,
  });

  final List<String> subjects;

  /// Yazdırılan formdaki test başlığı (ör. "Sosyal Bilimler-2").
  final String? trTitle;

  /// İlk sorunun A şıkkının merkezi.
  final double x;
  final double y;

  /// Şıklar arası yatay, sorular arası dikey mesafe.
  final double optionDx;
  final double rowDy;
  final int? perColumn;
  final double columnDx;
  final String options;

  int get questionCount =>
      subjects.fold(0, (n, c) => n + subjectByCode(c).questionCount);

  /// Bloğun [index]. sorusunun (0'dan) [option]. şıkkının merkezi.
  PagePoint bubble(int index, int option) {
    final per = perColumn ?? questionCount;
    final col = index ~/ per;
    final row = index % per;
    return (x: x + col * columnDx + option * optionDx, y: y + row * rowDy);
  }

  /// Bloğun [index]. sorusu hangi dersin kaçıncı sorusu.
  ({String subject, int number}) questionAt(int index) {
    var i = index;
    for (final code in subjects) {
      final n = subjectByCode(code).questionCount;
      if (i < n) return (subject: code, number: i + 1);
      i -= n;
    }
    throw RangeError.index(index, this);
  }
}

/// Öğrenci numarası: her hane bir sütun, sütunda yukarıdan aşağı 0–9.
class NumberField {
  const NumberField({
    required this.x,
    required this.y,
    required this.digits,
    required this.dx,
    required this.dy,
  });

  /// İlk sütunun 0 baloncuğunun merkezi.
  final double x;
  final double y;
  final int digits;
  final double dx;
  final double dy;

  PagePoint bubble(int digit, int value) =>
      (x: x + digit * dx, y: y + value * dy);
}

/// Birkaç seçenekten biri (oturum, kitapçık türü).
class ChoiceField {
  const ChoiceField({required this.values, required this.bubbles});

  final List<String> values;
  final List<PagePoint> bubbles;
}

/// YKS ızgarası: 4 sütun × 40 satır. TYT ve AYT aynı kutucukları farklı
/// derslerle kullanır (ÖSYM cevap kâğıdındaki gibi); TYT'de Sosyal ve Fen
/// sütunlarının yalnızca ilk 20 satırı dolar. [columnX]: her sütunun A
/// şıkkının x'i.
Map<ExamType, List<AnswerBlock>> yksLayouts({
  required List<double> columnX,
  required double y,
  required double optionDx,
  required double rowDy,
}) {
  AnswerBlock column(int i, String title, List<String> subjects) => AnswerBlock(
    trTitle: title,
    subjects: subjects,
    x: columnX[i],
    y: y,
    optionDx: optionDx,
    rowDy: rowDy,
  );
  return {
    ExamType.tyt: [
      column(0, 'Türkçe', const ['TYT_TUR']),
      column(1, 'Sosyal Bilimler', const [
        'TYT_TAR',
        'TYT_COG',
        'TYT_FEL',
        'TYT_DIN',
      ]),
      column(2, 'Temel Matematik', const ['TYT_MAT']),
      column(3, 'Fen Bilimleri', const ['TYT_FIZ', 'TYT_KIM', 'TYT_BIY']),
    ],
    ExamType.ayt: [
      column(0, 'Edebiyat–Sosyal-1', const ['AYT_EDB', 'AYT_TAR1', 'AYT_COG1']),
      column(1, 'Sosyal Bilimler-2', const [
        'AYT_TAR2',
        'AYT_COG2',
        'AYT_FELG',
        'AYT_DIN',
      ]),
      column(2, 'Matematik', const ['AYT_MAT']),
      column(3, 'Fen Bilimleri', const ['AYT_FIZ', 'AYT_KIM', 'AYT_BIY']),
    ],
  };
}

/// Mentoria YKS cevap kâğıdı (A4, kamerayla okunmak üzere tasarlandı):
/// dört köşede siyah kare + sol üstte yön işareti, öğrenci numarası
/// (8 hane), oturum (TYT / AYT), kitapçık (A / B), 4 × 40 soru ızgarası.
/// Uygulama içinden PDF olarak indirilir (`optic_form_print.dart`).
final mentoriaYks = OpticTemplate(
  id: 'mentoria_yks',
  trName: 'Mentoria YKS cevap kâğıdı',
  width: 1000,
  height: 1414,
  anchors: const [
    (x: 45, y: 45),
    (x: 955, y: 45),
    (x: 955, y: 1369),
    (x: 45, y: 1369),
  ],
  anchorSize: 40,
  orientationMark: (x: 102, y: 45),
  orientationMarkSize: 18,
  bubbleRadius: 8.5,
  studentNumber: const NumberField(x: 105, y: 178, digits: 8, dx: 28, dy: 22),
  session: const ChoiceField(
    values: ['TYT', 'AYT'],
    bubbles: [(x: 470, y: 200), (x: 470, y: 236)],
  ),
  booklet: const ChoiceField(
    values: ['A', 'B'],
    bubbles: [(x: 470, y: 322), (x: 530, y: 322)],
  ),
  layouts: yksLayouts(
    columnX: const [115, 337, 559, 781],
    y: 440,
    optionDx: 25,
    rowDy: 22,
  ),
);

/// Standart YKS optik formu: yayınevlerinin optik okuyucu makinesi için
/// bastığı formlar gibi köşe karesi yok, sol kenarda 55 zamanlama çubuğu
/// var (soru satırları çubuklarla hizalı). 10 haneli öğrenci numarası,
/// oturum, kitapçık, 4 × 40 ızgara. Gerçek bir yayınevinin kâğıdı değil;
/// o tarzda bir örnek (yayınevi kâğıtları ayrı şablon olarak eklenir).
final standartYks = OpticTemplate(
  id: 'standart_yks',
  trName: 'Standart YKS optik formu (kenar çizgili)',
  width: 1000,
  height: 1414,
  track: const TimingTrack(
    x: 32,
    firstY: 75,
    dy: 23.5,
    count: 55,
    barWidth: 30,
    barHeight: 9,
  ),
  bubbleRadius: 8,
  studentNumber: const NumberField(
    x: 110,
    y: 122,
    digits: 10,
    dx: 21,
    dy: 23.5,
  ),
  session: const ChoiceField(
    values: ['TYT', 'AYT'],
    bubbles: [(x: 470, y: 145.5), (x: 470, y: 169)],
  ),
  booklet: const ChoiceField(
    values: ['A', 'B'],
    bubbles: [(x: 450, y: 286.5), (x: 500, y: 286.5)],
  ),
  // Satır y'leri çubuklara denk: 14. çubuktan 53. çubuğa.
  layouts: yksLayouts(
    columnX: const [230, 420, 610, 800],
    y: 404,
    optionDx: 23,
    rowDy: 23.5,
  ),
);

/// Uygulamanın tanıdığı formlar (koç yeni denemede bunlardan seçer; ilki
/// varsayılan).
final opticTemplates = <OpticTemplate>[standartYks, mentoriaYks];

OpticTemplate? templateById(String id) =>
    opticTemplates.where((t) => t.id == id).firstOrNull;

/// Şablonun tüm baloncuklarının (her düzen ve alan) sayfa üzerindeki
/// kapladığı alan; şablon tutarlılık testinde kullanılır.
({double minX, double minY, double maxX, double maxY}) templateBounds(
  OpticTemplate t,
) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final p in allBubbles(t)) {
    minX = math.min(minX, p.x);
    minY = math.min(minY, p.y);
    maxX = math.max(maxX, p.x);
    maxY = math.max(maxY, p.y);
  }
  return (minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

/// Kâğıttaki tüm baloncuk merkezleri (TYT ve AYT aynı kutucukları paylaştığı
/// için her biri bir kez).
Set<PagePoint> allBubbles(OpticTemplate t) => {
  for (final blocks in t.layouts.values)
    for (final b in blocks)
      for (var q = 0; q < b.questionCount; q++)
        for (var o = 0; o < b.options.length; o++) b.bubble(q, o),
  if (t.studentNumber case final n?)
    for (var d = 0; d < n.digits; d++)
      for (var v = 0; v < 10; v++) n.bubble(d, v),
  ...?t.session?.bubbles,
  ...?t.booklet?.bubbles,
};
