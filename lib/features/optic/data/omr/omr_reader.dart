import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../../core/constants/exam_subjects.dart';
import 'homography.dart';
import 'optic_template.dart';

/// Fotoğraf okunamadığında neden.
enum OmrProblem {
  /// Dosya resim değil ya da bozuk.
  notImage,

  /// Dört köşe işareti bulunamadı (kâğıt kadraja sığmamış, karanlık,
  /// bulanık ya da yanlış form).
  anchorsNotFound,
}

class OmrException implements Exception {
  const OmrException(this.problem);
  final OmrProblem problem;

  @override
  String toString() => 'OmrException($problem)';
}

/// Okuyucunun emin olamadığı soru: koç tek dokunuşla düzeltir.
class UncertainMark {
  const UncertainMark({
    required this.subject,
    required this.number,
    required this.candidates,
  });

  final String subject;

  /// Dersin içindeki soru numarası (1'den).
  final int number;

  /// İşaretli görünen şıklar (iki ya da daha çok işaret) ya da tek silik
  /// işaret.
  final String candidates;
}

class OmrResult {
  const OmrResult({
    required this.answers,
    required this.uncertain,
    this.studentNumber,
    this.numberUncertain = false,
    this.session,
    this.booklet,
    this.bookletUncertain = false,
  });

  /// Ders kodu → soru soru işaret (`null` boş ya da belirsiz). Numaralar
  /// öğrencinin kendi kitapçığındaki sıradır.
  final Map<String, List<String?>> answers;
  final List<UncertainMark> uncertain;

  /// Formdaki öğrenci numarası (boş hanelerden arınmış); alan yoksa `null`.
  final String? studentNumber;
  final bool numberUncertain;

  /// Formda işaretlenen oturum (TYT / AYT); işaret yoksa ya da belirsizse
  /// `null`.
  final String? session;

  /// Kitapçık türü (A / B); işaret yoksa `null`.
  final String? booklet;
  final bool bookletUncertain;
}

/// İşaretin aynı sıradaki boş baloncuklardan (ortanca) en az ne kadar koyu
/// olması gerektiği (0–1).
const _margin = 0.2;

/// Bu kâğıttaki tipik işaretin en az bu kadarı kadar koyu olan işaret dolu,
/// daha açığı silik (silinmiş ya da hafif dokunulmuş) sayılır.
const _filledShare = 0.7;

/// Telefon fotoğrafını (JPEG/PNG baytları) [template]'e göre, [type]
/// sınavının ders düzeniyle okur. Ağır iş; arayüzden `compute` ile çağrılır.
OmrResult readOptic(Uint8List bytes, OpticTemplate template, ExamType type) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) throw const OmrException(OmrProblem.notImage);
  // Telefonlar yönü EXIF'e yazar; pikselleri döndürmeden okursak kâğıt yan
  // durur.
  return readOpticImage(img.bakeOrientation(decoded), template, type);
}

OmrResult readOpticImage(
  img.Image source,
  OpticTemplate template,
  ExamType type,
) {
  final page = _Page.from(source);
  final blocks = template.blocksFor(type);
  final field = template.studentNumber;

  final mapFor = _align(page, template, type);

  double fill(PagePoint p) {
    final m = mapFor(p);
    final c = m(p.x, p.y);
    // Şablondaki baloncuk yarıçapının fotoğraftaki karşılığı (yerel ölçek).
    final r =
        (_dist(c, m(p.x + template.bubbleRadius, p.y)) +
            _dist(c, m(p.x, p.y + template.bubbleRadius))) /
        2;
    return page.darkness(c.x, c.y, r * 0.7);
  }

  final rows = [
    for (final block in blocks)
      for (var q = 0; q < block.questionCount; q++)
        [
          for (var o = 0; o < block.options.length; o++)
            fill(block.bubble(q, o)),
        ],
  ];
  final digitRows = [
    if (field != null)
      for (var digit = 0; digit < field.digits; digit++)
        [for (var v = 0; v < 10; v++) fill(field.bubble(digit, v))],
  ];
  final level = _markLevel([...rows, ...digitRows]);
  // Az seçenekli alanlarda (oturum, kitapçık) sıra ortancası boş baloncuğu
  // temsil etmez; kâğıdın genelindeki boş baloncuk koyuluğu kullanılır.
  final blank = _median([for (final r in rows) ...r]);

  final answers = <String, List<String?>>{};
  final uncertain = <UncertainMark>[];
  var row = 0;
  for (final block in blocks) {
    for (var q = 0; q < block.questionCount; q++) {
      final at = block.questionAt(q);
      final d = _decide(rows[row++], level);
      final list = answers.putIfAbsent(at.subject, () => []);
      list.add(d.sure ? _letter(block.options, d.picked) : null);
      if (!d.sure && d.candidates.isNotEmpty) {
        uncertain.add(
          UncertainMark(
            subject: at.subject,
            number: at.number,
            candidates: d.candidates.map((i) => block.options[i]).join(),
          ),
        );
      }
    }
  }

  String? number;
  var numberUncertain = false;
  if (field != null) {
    final b = StringBuffer();
    for (final digitRow in digitRows) {
      final d = _decide(digitRow, level);
      if (d.sure && d.picked != null) {
        b.write(d.picked);
      } else if (d.candidates.isNotEmpty) {
        numberUncertain = true;
      }
    }
    number = b.toString();
  }

  ({String? value, bool uncertain}) choice(ChoiceField? f) {
    if (f == null) return (value: null, uncertain: false);
    final d = _decide([for (final p in f.bubbles) fill(p)], level, blank);
    return (
      value: d.sure && d.picked != null ? f.values[d.picked!] : null,
      uncertain: !d.sure,
    );
  }

  final session = choice(template.session);
  final booklet = choice(template.booklet);
  return OmrResult(
    answers: answers,
    uncertain: uncertain,
    studentNumber: number,
    numberUncertain: numberUncertain,
    session: session.value,
    booklet: booklet.value,
    bookletUncertain: booklet.uncertain,
  );
}

/// Her baloncuğun eşlemesi (şablon → küçültülmüş sayfa). Zamanlama çizgili
/// formda gruplara göre düzeltilmiş olabilir.
_MapFn Function(PagePoint) _align(
  _Page page,
  OpticTemplate template,
  ExamType type,
) {
  final blocks = template.blocksFor(type);
  final field = template.studentNumber;
  // Şablondan fotoğrafa: köşe kareleri varsa dört köşeden perspektif
  // dönüşümü; zamanlama çizgili formda çubuklardan başlayıp baloncuklara
  // oturtularak kademeli kurulan perspektif dönüşümü.
  if (template.track != null) {
    final track = _TrackMapper.find(page, template);
    final groups = <List<PagePoint>>[
      for (final b in blocks)
        [
          for (var q = 0; q < b.questionCount; q++)
            for (var o = 0; o < b.options.length; o++) b.bubble(q, o),
        ],
      if (field != null)
        [
          for (var d = 0; d < field.digits; d++)
            for (var v = 0; v < 10; v++) field.bubble(d, v),
        ],
      ...[
        for (final f in [template.session, template.booklet])
          if (f != null) f.bubbles,
      ],
    ];
    // Kaba eşleme (çubuklar, satırlar çubuk sırasına dik varsayılarak)
    // çizgiye yakın baloncukları birkaç birim içinde bulur; uzaklaştıkça
    // perspektif yüzünden hata büyür. Bu yüzden
    // dönüşüm çizgiden dışa doğru kademeli kurulur: her şeritte baloncuklar
    // kendi çerçevelerine oturtulur, o ana kadarki tüm eşleşmelere tek bir
    // perspektif dönüşümü (düz kâğıt için kesin model) oturtulur ve sonraki
    // şerit bu dönüşümle aranır. Tutmayan eşleşmeler atılır. Son turda tüm
    // baloncuklar daha dar aramayla yeniden oturtulur.
    final r = template.bubbleRadius;
    final bubbles = [for (final g in groups) ...g];
    final tx = template.track!.x;
    _MapFn current = track.map;
    final reachOf = [for (final b in bubbles) (b.x - tx).abs()];
    final farthest = reachOf.fold(0.0, math.max);
    final bands = [
      for (var limit = 150.0; limit < farthest; limit += 100) limit,
      farthest,
    ];
    for (final (i, limit) in [...bands, farthest].indexed) {
      final last = i == bands.length;
      final from = <PagePoint>[
        for (var k = 0; k < track.track.count; k++) track.track.bar(k),
      ];
      final to = <PagePoint>[...track.bars];
      for (final (j, b) in bubbles.indexed) {
        if (reachOf[j] > limit) continue;
        final hit = page.snap(current, b, r, last ? 0.6 : 1.3);
        if (hit != null) {
          from.add(b);
          to.add(hit);
        }
      }
      if (from.length < track.track.count + 8) continue;
      current = _fitRobust(from, to, fixed: track.track.count).map;
    }
    final fitted = current;
    return (_) => fitted;
  }
  final h = _orient(page, template, page.findAnchors());
  return (_) => h.map;
}

/// [type] sınavının baloncuklarının fotoğraftaki yeri ([source]
/// pikselleriyle). Okumanın nereye baktığını göstermek ve testlerde
/// hizalamayı ölçmek için.
Map<PagePoint, PagePoint> locateBubbles(
  img.Image source,
  OpticTemplate template,
  ExamType type,
) {
  final page = _Page.from(source);
  final mapFor = _align(page, template, type);
  final k = source.width / page.width;
  return {
    for (final p in allBubbles(template))
      p: () {
        final c = mapFor(p)(p.x, p.y);
        return (x: c.x * k, y: c.y * k);
      }(),
  };
}

/// Şablon noktası → fotoğraf noktası.
typedef _MapFn = ({double x, double y}) Function(double x, double y);

/// Zamanlama çizgili formda kaba eşleme. Her çubuğun fotoğraftaki yeri
/// bilinir; şablondaki bir noktanın y'si iki çubuk arasından, x'i çubuk
/// sırasına dik yönde aynı ölçekle bulunur. Çizgiye yakın yerde doğru,
/// uzaklaştıkça perspektif payı birikir; kesin dönüşüm `_align`'da
/// baloncuklara oturtularak kurulur.
class _TrackMapper {
  _TrackMapper(this.track, this.bars)
    : _fx = _quadratic([for (final b in bars) b.x]),
      _fy = _quadratic([for (final b in bars) b.y]);

  final TimingTrack track;

  /// Çubuk merkezleri (fotoğrafta), şablondaki sırayla.
  final List<PagePoint> bars;

  /// Çubuk merkezlerine oturtulan ikinci derece eğri (x(k), y(k)): piksel
  /// yuvarlamasını yumuşatır, perspektifte aralığın yavaşça değişmesini
  /// izler. Ölçek bu eğrinin türevinden gelir.
  final List<double> _fx, _fy;

  /// v[k] ≈ a + b·k + c·k² en küçük kareler çözümü.
  static List<double> _quadratic(List<double> v) {
    final s = List.filled(5, 0.0), t = List.filled(3, 0.0);
    for (var k = 0; k < v.length; k++) {
      var p = 1.0;
      for (var i = 0; i < 5; i++) {
        s[i] += p;
        if (i < 3) t[i] += p * v[k];
        p *= k;
      }
    }
    // [s0 s1 s2; s1 s2 s3; s2 s3 s4] · [a b c] = t (Cramer).
    double det(List<List<double>> m) =>
        m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
        m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
        m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
    final m = [
      [s[0], s[1], s[2]],
      [s[1], s[2], s[3]],
      [s[2], s[3], s[4]],
    ];
    final d = det(m);
    return [
      for (var c = 0; c < 3; c++)
        det([
              for (var r = 0; r < 3; r++)
                [for (var j = 0; j < 3; j++) j == c ? t[r] : m[r][j]],
            ]) /
            d,
    ];
  }

  /// Fotoğraftaki çubuk sırasını bulur: aynı doğru üzerinde, eşit
  /// aralıklı, benzer boyda en çok dolu çubuk. Kâğıt ters çekildiyse sıra
  /// içeriğin hangi tarafta kaldığına göre çevrilir.
  static _TrackMapper find(_Page page, OpticTemplate t) {
    final track = t.track!;
    final long = math.max(page.width, page.height).toDouble();
    // Çubuğun uzun kenarı sayfanın en az %1'i: harf ve baloncuk parçaları
    // (alt alta dizilip "çizgi" gibi görünebilir) bunun çok altında kalır.
    final cands = page.blobs(minSide: long * 0.01, maxSide: long * 0.08).where((
      b,
    ) {
      final ratio = math.max(b.w, b.h) / math.min(b.w, b.h);
      return b.solidity >= 0.75 && ratio >= 1.5 && ratio <= 9;
    }).toList();
    if (cands.length < track.count * 0.8) {
      throw const OmrException(OmrProblem.anchorsNotFound);
    }
    final tol = long * 0.006;
    var best = <_Blob>[];
    for (var i = 0; i < cands.length; i++) {
      final a = cands[i];
      for (var j = i + 1; j < cands.length; j++) {
        final b = cands[j];
        final ratio = a.area / b.area;
        if (ratio < 0.6 || ratio > 1.67) continue;
        final len = _dist((x: a.x, y: a.y), (x: b.x, y: b.y));
        if (len < long * 0.3) continue;
        final ux = (b.x - a.x) / len, uy = (b.y - a.y) / len;
        final inliers = [
          for (final c in cands)
            if (((c.x - a.x) * uy - (c.y - a.y) * ux).abs() <= tol &&
                c.area / a.area > 0.5 &&
                c.area / a.area < 2)
              c,
        ];
        if (inliers.length > best.length) best = inliers;
      }
    }
    if (best.length < track.count * 0.8) {
      throw const OmrException(OmrProblem.anchorsNotFound);
    }
    // Doğru boyunca sırala; aralık, ardışık farkların ortancası.
    final a0 = best.first;
    final far = best.reduce(
      (m, c) =>
          _dist((x: c.x, y: c.y), (x: a0.x, y: a0.y)) >
              _dist((x: m.x, y: m.y), (x: a0.x, y: a0.y))
          ? c
          : m,
    );
    final len = _dist((x: far.x, y: far.y), (x: a0.x, y: a0.y));
    final ux = (far.x - a0.x) / len, uy = (far.y - a0.y) / len;
    double along(_Blob c) => (c.x - a0.x) * ux + (c.y - a0.y) * uy;
    best.sort((p, q) => along(p).compareTo(along(q)));
    // Sıra numarası ardışık çubuklar arasından sayılır: perspektifte
    // aralık kâğıt boyunca değişir, tek bir aralığa bölmek ortada şaşar.
    // Eksik çubuk, aralığın yerel aralığın katı olmasından anlaşılır.
    final gaps = [
      for (var i = 1; i < best.length; i++) along(best[i]) - along(best[i - 1]),
    ];
    double localStep(int i) {
      final w = [
        for (var j = math.max(0, i - 4); j < math.min(gaps.length, i + 5); j++)
          gaps[j],
      ]..sort();
      return w[w.length ~/ 2];
    }

    final sorted = [...gaps]..sort();
    final step = sorted[sorted.length ~/ 2];
    final byIndex = <int, PagePoint>{0: (x: best.first.x, y: best.first.y)};
    var k = 0;
    for (var i = 1; i < best.length; i++) {
      k += math.max(1, (gaps[i - 1] / localStep(i - 1)).round());
      byIndex[k] = (x: best[i].x, y: best[i].y);
    }
    final last = byIndex.keys.reduce(math.max);
    if (last != track.count - 1) {
      throw const OmrException(OmrProblem.anchorsNotFound);
    }
    // Eksik çubuklar komşulardan doğrusal tamamlanır.
    final bars = <PagePoint>[];
    for (var k = 0; k < track.count; k++) {
      final hit = byIndex[k];
      if (hit != null) {
        bars.add(hit);
        continue;
      }
      var lo = k - 1, hi = k + 1;
      while (!byIndex.containsKey(lo)) {
        lo--;
      }
      while (!byIndex.containsKey(hi)) {
        hi++;
      }
      final f = (k - lo) / (hi - lo);
      final p = byIndex[lo]!, q = byIndex[hi]!;
      bars.add((x: p.x + (q.x - p.x) * f, y: p.y + (q.y - p.y) * f));
    }
    // İçerik çubukların sağında olmalı (şablonda +x). Değilse kâğıt ters.
    // Önce hangi tarafın kâğıt olduğuna bakılır (öbür yan çoğunlukla masa
    // ya da kadraj dışı, daha karanlık); iki yan da aynı parlaklıktaysa
    // (beyaz masa) içeriğin (baskı, işaret) yoğun olduğu taraf seçilir.
    final m = _TrackMapper(track, bars);
    var lightR = 0.0, lightL = 0.0, inkR = 0.0, inkL = 0.0;
    var n = 0;
    for (var k = 0; k < track.count; k += 3) {
      for (final d in [4.0, 8.0, 12.0]) {
        final r = m.map(track.x + track.dy * d, track.bar(k).y);
        final l = m.map(track.x - track.dy * d, track.bar(k).y);
        lightR += page.light(r.x, r.y);
        lightL += page.light(l.x, l.y);
        inkR += page.darkness(r.x, r.y, step * 2);
        inkL += page.darkness(l.x, l.y, step * 2);
        n++;
      }
    }
    final flip = (lightR - lightL).abs() / n > 25
        ? lightL > lightR
        : inkL > inkR;
    return flip ? _TrackMapper(track, bars.reversed.toList()) : m;
  }

  /// [k] (kesirli) çubuk sırasındaki nokta ve oradaki çubuk aralığı vektörü.
  ({PagePoint at, double vx, double vy}) _along(double k) => (
    at: (
      x: _fx[0] + _fx[1] * k + _fx[2] * k * k,
      y: _fy[0] + _fy[1] * k + _fy[2] * k * k,
    ),
    vx: _fx[1] + 2 * _fx[2] * k,
    vy: _fy[1] + 2 * _fy[2] * k,
  );

  PagePoint map(double x, double y) {
    final a = _along((y - track.firstY) / track.dy);
    // Şablonda çubuk sırası aşağı (+y) doğru; içerik sağda (+x): çubuk
    // yönü (0, 1) iken içerik yönü (1, 0): (vy, -vx).
    final s = 1 / track.dy;
    final dx = (x - track.x) * s;
    return (x: a.at.x + a.vy * dx, y: a.at.y - a.vx * dx);
  }
}

/// Aykırı noktalara dayanıklı perspektif dönüşümü: oturt, uzak kalanları
/// (ortanca hatanın 2,5 katından fazla) at, yeniden oturt. İlk [fixed]
/// nokta (zamanlama çubukları) kesindir: hiç atılmaz ve üç kat sayılır;
/// yanlış satıra oturmuş baloncuklar dönüşümü onlardan koparamaz.
Homography _fitRobust(
  List<PagePoint> from,
  List<PagePoint> to, {
  int fixed = 0,
}) {
  var keep = [for (var i = 0; i < from.length; i++) i];
  late Homography h;
  for (var round = 0; round < 4; round++) {
    final use = [
      for (final i in keep) ...(i < fixed ? [i, i, i] : [i]),
    ];
    h = Homography.fit(
      [for (final i in use) from[i]],
      [for (final i in use) to[i]],
    );
    final err = [
      for (var i = 0; i < from.length; i++)
        _dist(h.map(from[i].x, from[i].y), to[i]),
    ];
    final sorted = [for (final i in keep) err[i]]..sort();
    final limit = math.max(sorted[sorted.length ~/ 2] * 2.5, 1.5);
    final next = [
      for (var i = 0; i < from.length; i++)
        if (i < fixed || err[i] <= limit) i,
    ];
    if (next.length < 8 || next.length == keep.length) break;
    keep = next;
  }
  return h;
}

/// Bulunan dört köşe işaretinden hangisinin formun sol üstü olduğunu yön
/// işaretinden anlar (kâğıt ters ya da yan çekilmiş olabilir) ve şablondan
/// fotoğrafa dönüşümü döner.
Homography _orient(_Page page, OpticTemplate t, List<PagePoint> corners) {
  final mark = t.orientationMark;
  if (mark == null) return Homography.fromPoints(t.anchors, corners);
  Homography? best;
  var bestFill = -1.0;
  for (var r = 0; r < 4; r++) {
    final h = Homography.fromPoints(t.anchors, [
      for (var i = 0; i < 4; i++) corners[(i + r) % 4],
    ]);
    final c = h.map(mark.x, mark.y);
    final edge = h.map(mark.x + t.orientationMarkSize / 2, mark.y);
    final f = page.darkness(c.x, c.y, _dist(c, edge) * 0.6);
    if (f > bestFill) {
      bestFill = f;
      best = h;
    }
  }
  return best!;
}

String? _letter(String options, int? i) => i == null ? null : options[i];

double _dist(({double x, double y}) a, ({double x, double y}) b) =>
    math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

double _median(List<double> v) => ([...v]..sort())[v.length ~/ 2];

/// Bu kâğıtta tipik bir işaretin koyuluğu: sırasındaki boş baloncuklardan
/// belirgin koyu olan baloncukların ortancası. Kurşun kalemi açık basan
/// öğrencide de koyu basanda da eşik buna göre kayar.
double _markLevel(List<List<double>> rows) {
  final marks = <double>[];
  for (final r in rows) {
    final m = _median(r);
    for (final f in r) {
      if (f - m >= _margin) marks.add(f);
    }
  }
  return marks.isEmpty ? 1 : _median(marks);
}

/// Bir sıradaki baloncuklardan hangisi işaretli. Boş baloncuklar
/// (ortanca) referans alınır: basılı harf ve çerçeve gölgesi boş baloncuğu
/// biraz koyu gösterse de işaretle karışmaz.
({bool sure, int? picked, List<int> candidates}) _decide(
  List<double> fills,
  double level, [
  double? blank,
]) {
  final median = blank ?? _median(fills);
  final marked = <int>[];
  final faint = <int>[];
  for (var i = 0; i < fills.length; i++) {
    final f = fills[i];
    if (f - median < _margin * 0.6) continue;
    if (f >= level * _filledShare && f - median >= _margin) {
      marked.add(i);
    } else {
      faint.add(i);
    }
  }
  if (marked.length == 1 && faint.isEmpty) {
    return (sure: true, picked: marked.single, candidates: marked);
  }
  if (marked.isEmpty && faint.isEmpty) {
    return (sure: true, picked: null, candidates: const []);
  }
  return (sure: false, picked: null, candidates: [...marked, ...faint]..sort());
}

/// Gri tonlu, küçültülmüş sayfa ve koyu piksel maskesi.
class _Page {
  _Page(this.width, this.height, this.dark, this.ink, this.lum);

  final int width;
  final int height;

  /// Gri tonlar (0 siyah – 255 beyaz).
  final Uint8List lum;

  /// (x, y) noktasının parlaklığı; kadraj dışı karanlık sayılır.
  double light(double x, double y) {
    final ix = x.round(), iy = y.round();
    if (ix < 0 || iy < 0 || ix >= width || iy >= height) return 0;
    return lum[iy * width + ix].toDouble();
  }

  /// 1: kâğıda göre koyu (mürekkep, kurşun kalem, köşe işareti).
  final Uint8List dark;

  /// Kâğıda (yerel ortalama) göre koyuluk, 0 (kâğıt) – 255 (siyah).
  final Uint8List ink;

  /// En uzun kenar en çok bu kadar piksele indirilir (hız; isabeti
  /// etkilemez).
  static const _maxSide = 1600;

  factory _Page.from(img.Image source) {
    var image = source;
    final long = math.max(image.width, image.height);
    if (long > _maxSide) {
      image = img.copyResize(
        image,
        width: image.width >= image.height ? _maxSide : null,
        height: image.height > image.width ? _maxSide : null,
        interpolation: img.Interpolation.average,
      );
    }
    final w = image.width, h = image.height;
    final lum = Uint8List(w * h);
    for (final p in image) {
      lum[p.y * w + p.x] = p.luminance.toInt().clamp(0, 255);
    }

    // Yerel ortalamaya göre eşikleme: ışık kâğıdın bir yanında daha
    // parlaksa da işaretler ayırt edilir. Pencere köşe işaretinden geniş
    // olmalı, yoksa dolu karenin içi "kâğıt" sanılır.
    final integral = Uint32List((w + 1) * (h + 1));
    for (var y = 0; y < h; y++) {
      var row = 0;
      for (var x = 0; x < w; x++) {
        row += lum[y * w + x];
        integral[(y + 1) * (w + 1) + x + 1] =
            integral[y * (w + 1) + x + 1] + row;
      }
    }
    final r = math.max(16, math.max(w, h) ~/ 24);
    final dark = Uint8List(w * h);
    final ink = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      final y0 = math.max(0, y - r), y1 = math.min(h, y + r + 1);
      for (var x = 0; x < w; x++) {
        final x0 = math.max(0, x - r), x1 = math.min(w, x + r + 1);
        final sum =
            integral[y1 * (w + 1) + x1] -
            integral[y0 * (w + 1) + x1] -
            integral[y1 * (w + 1) + x0] +
            integral[y0 * (w + 1) + x0];
        final mean = sum / ((x1 - x0) * (y1 - y0));
        final v = lum[y * w + x];
        if (v < mean * 0.75 && v < 170) dark[y * w + x] = 1;
        // Kâğıt ışığın en parlak yerinde bile ~ortalamanın biraz üstündedir.
        final paper = math.max(mean * 1.08, 1.0);
        if (v < paper) ink[y * w + x] = ((paper - v) / paper * 255).round();
      }
    }
    return _Page(w, h, dark, ink, lum);
  }

  /// (x, y) merkezli, [radius] yarıçaplı dairenin ortalama koyuluğu (0–1).
  double darkness(double cx, double cy, double radius) {
    final r = math.max(1.0, radius);
    final r2 = r * r;
    var n = 0, d = 0;
    for (var y = (cy - r).floor(); y <= (cy + r).ceil(); y++) {
      if (y < 0 || y >= height) continue;
      for (var x = (cx - r).floor(); x <= (cx + r).ceil(); x++) {
        if (x < 0 || x >= width) continue;
        final dx = x - cx, dy = y - cy;
        if (dx * dx + dy * dy > r2) continue;
        n++;
        d += ink[y * width + x];
      }
    }
    return n == 0 ? 0 : d / n / 255;
  }

  /// (x, y) merkezli, [radius] yarıçaplı çember üzerindeki ortalama
  /// koyuluk (baloncuk çerçevesi aramak için).
  double ring(double cx, double cy, double radius) {
    // Bilineer örnekleme: yarım piksellik kayma puanı sıçratmasın.
    var d = 0.0;
    var n = 0;
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 12;
      final x = cx + radius * math.cos(a), y = cy + radius * math.sin(a);
      final x0 = x.floor(), y0 = y.floor();
      if (x0 < 0 || y0 < 0 || x0 + 1 >= width || y0 + 1 >= height) continue;
      final fx = x - x0, fy = y - y0;
      final i0 = y0 * width + x0;
      d +=
          ink[i0] * (1 - fx) * (1 - fy) +
          ink[i0 + 1] * fx * (1 - fy) +
          ink[i0 + width] * (1 - fx) * fy +
          ink[i0 + width + 1] * fx * fy;
      n++;
    }
    return n == 0 ? 0 : d / n / 255;
  }

  /// Baloncuğun çerçevesini [map]'in tahmini çevresinde arar (± [reach]
  /// yarıçap): içi çevresinden en koyu olan yer. Belirgin bir çerçeve
  /// yoksa ya da en iyi yer arama sınırındaysa `null`.
  PagePoint? snap(_MapFn map, PagePoint b, double radius, double reach) {
    final c = map(b.x, b.y);
    final r = _dist(c, map(b.x + radius, b.y));
    double score(double x, double y) =>
        (ring(x, y, r * 0.35) + ring(x, y, r * 0.7) + ring(x, y, r)) / 3 -
        (ring(x, y, r * 1.4) + ring(x, y, r * 1.65)) / 2;
    final step = r / 4;
    final n = (reach * r / step).ceil();
    var best = -double.infinity;
    var bi = 0, bj = 0;
    for (var i = -n; i <= n; i++) {
      for (var j = -n; j <= n; j++) {
        final v = score(c.x + i * step, c.y + j * step);
        if (v > best) {
          best = v;
          bi = i;
          bj = j;
        }
      }
    }
    if (best < 0.04 || bi.abs() == n || bj.abs() == n) return null;
    return (x: c.x + bi * step, y: c.y + bj * step);
  }

  /// Koyu piksellerin bağlı lekeleri; kenar uzunluğu sınırlar içinde
  /// olanlar.
  List<_Blob> blobs({required double minSide, required double maxSide}) {
    final seen = Uint8List(width * height);
    final blobs = <_Blob>[];
    final stack = <int>[];
    for (var start = 0; start < dark.length; start++) {
      if (dark[start] == 0 || seen[start] == 1) continue;
      var area = 0, sx = 0, sy = 0;
      var minX = width, minY = height, maxX = 0, maxY = 0;
      stack.add(start);
      seen[start] = 1;
      while (stack.isNotEmpty) {
        final i = stack.removeLast();
        final x = i % width, y = i ~/ width;
        area++;
        sx += x;
        sy += y;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        void visit(int j) {
          if (dark[j] == 1 && seen[j] == 0) {
            seen[j] = 1;
            stack.add(j);
          }
        }

        if (x > 0) visit(i - 1);
        if (x < width - 1) visit(i + 1);
        if (y > 0) visit(i - width);
        if (y < height - 1) visit(i + width);
      }
      final bw = maxX - minX + 1, bh = maxY - minY + 1;
      if (math.max(bw, bh) < minSide || math.max(bw, bh) > maxSide) continue;
      blobs.add(_Blob(area, sx / area, sy / area, bw, bh));
    }
    return blobs;
  }

  /// Dört köşedeki dolu kareler: sol üst, sağ üst, sağ alt, sol alt.
  List<PagePoint> findAnchors() {
    final long = math.max(width, height);
    final blobs = this
        .blobs(minSide: long * 0.01, maxSide: long * 0.1)
        .where(
          // Kare: en-boy yakın, kutusunu dolduruyor (daire ~0.79, kare ~1).
          (b) =>
              b.w >= long * 0.01 &&
              b.h >= long * 0.01 &&
              b.w / b.h >= 0.6 &&
              b.w / b.h <= 1.65 &&
              b.solidity >= 0.84,
        )
        .toList();
    if (blobs.length < 4) {
      throw const OmrException(OmrProblem.anchorsNotFound);
    }
    // Köşe işaretleri formdaki en büyük karelerdir; küçükleri (dolu
    // baloncuk, harf parçası) ele.
    final biggest = blobs.map((b) => b.area).reduce(math.max);
    final big = blobs.where((b) => b.area >= biggest * 0.35).toList();

    final corners = [
      (x: 0.0, y: 0.0),
      (x: width.toDouble(), y: 0.0),
      (x: width.toDouble(), y: height.toDouble()),
      (x: 0.0, y: height.toDouble()),
    ];
    final picked = <_Blob>[];
    for (final c in corners) {
      _Blob? best;
      var bestD = double.infinity;
      for (final b in big) {
        if (picked.contains(b)) continue;
        final d = _dist((x: b.x, y: b.y), c);
        if (d < bestD) {
          bestD = d;
          best = b;
        }
      }
      if (best == null) throw const OmrException(OmrProblem.anchorsNotFound);
      picked.add(best);
    }
    // Her işaret kendi çeyreğinde olmalı; değilse kâğıt kadraja sığmamış.
    final qx = [false, true, true, false], qy = [false, false, true, true];
    for (var i = 0; i < 4; i++) {
      if ((picked[i].x > width / 2) != qx[i] ||
          (picked[i].y > height / 2) != qy[i]) {
        throw const OmrException(OmrProblem.anchorsNotFound);
      }
    }
    return [for (final b in picked) (x: b.x, y: b.y)];
  }
}

class _Blob {
  _Blob(this.area, this.x, this.y, this.w, this.h);
  final int area;
  final double x;
  final double y;
  final int w;
  final int h;

  double get solidity => area / (w * h);
}
