import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../shared/format.dart';
import '../../exams/data/yks_score.dart';
import '../../schedule_generator/presentation/schedule_export.dart'
    show jpegPagesToPdf;
import '../data/exam_report_repository.dart';
import '../domain/outcome_analysis.dart';

/// Karnedeki tahmini ham puan. TYT kendi netleriyle; AYT/YDT puanı TYT'nin
/// %40 payını içerdiği için öğrencinin aynı gün ya da önceki en yakın TYT
/// denemesinin netleriyle hesaplanır (TYT denemesi yoksa gösterilmez).
/// Puan türü öğrencinin alanından; alan yoksa AYT'de girilen derslere en çok
/// uyan tür (eşitlikte yüksek puan) seçilir.
({ScoreType type, double score})? estimatedScore(ReportCard c) {
  final own = {for (final s in c.subjects) s.subject: s.net};
  if (c.examType == ExamType.tyt) {
    return (type: ScoreType.tyt, score: computeScore(ScoreType.tyt, own).raw);
  }
  if (c.tytNets.isEmpty) return null;
  final nets = {...c.tytNets, ...own};
  final List<ScoreType> types = c.examType == ExamType.ydt
      ? const [ScoreType.dil]
      : switch (c.field) {
          FieldType.say => const [ScoreType.say],
          FieldType.ea => const [ScoreType.ea],
          FieldType.soz => const [ScoreType.soz],
          _ => const [ScoreType.say, ScoreType.ea, ScoreType.soz],
        };
  ({ScoreType type, double score})? best;
  var bestHits = -1;
  for (final t in types) {
    final hits = scoreSubjects(
      t,
    ).where((s) => !s.startsWith('TYT_') && own.containsKey(s)).length;
    if (hits == 0 && types.length > 1) continue;
    final score = computeScore(t, nets).raw;
    if (hits > bestHits || (hits == bestHits && score > best!.score)) {
      best = (type: t, score: score);
      bestHits = hits;
    }
  }
  return best;
}

/// "Tahmini puan" kutusunun başlığı (TYT dışında puan türüyle).
String scoreLabel(ScoreType t) => t == ScoreType.tyt
    ? tr('Tahmini puan')
    : tr('Tahmini {t} puanı', {'t': t.label});

String rankText(int? rank, int? count) => rank == null
    ? '—'
    : count == null
    ? '$rank.'
    : '$rank / $count';

/// Karneler: öğrenci başına bir A4 dikey sayfa (sınıf toplu çıktısı da).
Future<Uint8List> renderReportCardsPdf(
  List<ReportCard> cards, {
  String? fontFamily,
  String? orgName,
}) async {
  final pages = <(Uint8List, int, int)>[];
  for (final c in cards) {
    pages.add(await _page(c, fontFamily: fontFamily, orgName: orgName));
  }
  return jpegPagesToPdf(pages);
}

Future<(Uint8List, int, int)> _page(
  ReportCard c, {
  String? fontFamily,
  String? orgName,
}) async {
  const w = 1240, h = 1754;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w + 0.0, h + 0.0),
    Paint()..color = Colors.white,
  );
  double text(
    String s,
    Offset at, {
    double size = 20,
    FontWeight weight = FontWeight.w500,
    double width = 400,
    Color color = Colors.black87,
    TextAlign align = TextAlign.left,
    int maxLines = 2,
  }) {
    final p = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color,
          fontFamily: fontFamily,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(minWidth: width, maxWidth: width);
    p.paint(canvas, at);
    return p.height;
  }

  const m = 70.0;
  final line = Paint()..color = const Color(0xFFDDDDDD);
  var y = 60.0;
  if (orgName != null) {
    text(orgName, Offset(m, y), size: 22, color: Colors.black54, width: 1100);
    y += 34;
  }
  text(
    tr('Sınav karnesi'),
    Offset(m, y),
    size: 40,
    weight: FontWeight.w800,
    width: 1100,
  );
  y += 60;
  text(
    [
      c.studentName,
      if (c.studentNumber != null) '${tr('No')}: ${c.studentNumber}',
      c.className,
    ].whereType<String>().join('  ·  '),
    Offset(m, y),
    size: 24,
    weight: FontWeight.w700,
    width: 1100,
  );
  y += 38;
  text(
    '${c.examName}  ·  ${formatLongDate(c.takenOn)}  ·  ${c.examType.label}${c.booklet == null ? '' : '  ·  ${tr('{b} kitapçığı', {'b': c.booklet!})}'}',
    Offset(m, y),
    size: 22,
    width: 1100,
  );
  y += 56;

  // Özet kutuları.
  final score = estimatedScore(c);
  final boxes = [
    (tr('Toplam net'), formatNet(c.totalNet)),
    if (score != null) (scoreLabel(score.type), score.score.toStringAsFixed(1)),
    (tr('Kurum sırası'), rankText(c.rankOrg, c.orgCount)),
    (tr('Sınıf sırası'), rankText(c.rankClass, c.classCount)),
  ];
  final bw = (w - 2 * m - (boxes.length - 1) * 16) / boxes.length;
  for (final (i, (label, value)) in boxes.indexed) {
    final x = m + i * (bw + 16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, bw, 110),
        const Radius.circular(16),
      ),
      Paint()..color = const Color(0xFFF3F1EA),
    );
    text(
      value,
      Offset(x, y + 18),
      size: 38,
      weight: FontWeight.w800,
      width: bw,
      align: TextAlign.center,
    );
    text(
      label,
      Offset(x, y + 70),
      size: 18,
      color: Colors.black54,
      width: bw,
      align: TextAlign.center,
    );
  }
  y += 140;

  // Ders tablosu.
  final cols = [
    (tr('Ders'), 300.0),
    (tr('D'), 80.0),
    (tr('Y'), 80.0),
    (tr('B'), 80.0),
    (tr('Net'), 120.0),
    (tr('Sınıf ort.'), 140.0),
    (tr('Kurum ort.'), 140.0),
    (tr('Önceki'), 160.0),
  ];
  var x = m;
  for (final (label, cw) in cols) {
    text(label, Offset(x, y), size: 18, weight: FontWeight.w800, width: cw - 8);
    x += cw;
  }
  y += 34;
  for (final s in c.subjects) {
    canvas.drawLine(Offset(m, y - 4), Offset(w - m, y - 4), line);
    final prev = s.previousNet;
    final arrow = prev == null
        ? '—'
        : s.net > prev
        ? '▲ ${formatNet(prev)}'
        : s.net < prev
        ? '▼ ${formatNet(prev)}'
        : '= ${formatNet(prev)}';
    final cells = [
      subjectByCode(s.subject).name,
      '${s.correct}',
      '${s.wrong}',
      '${s.blank}',
      formatNet(s.net),
      s.classAvg == null ? '—' : formatNet(s.classAvg!),
      s.orgAvg == null ? '—' : formatNet(s.orgAvg!),
      arrow,
    ];
    x = m;
    for (final (i, (_, cw)) in cols.indexed) {
      text(
        cells[i],
        Offset(x, y + 6),
        size: 20,
        weight: i == 4 ? FontWeight.w800 : FontWeight.w500,
        width: cw - 8,
        maxLines: 1,
        color: i == 7 && prev != null
            ? (s.net > prev
                  ? const Color(0xFF1E8A5A)
                  : s.net < prev
                  ? const Color(0xFFC0392B)
                  : Colors.black54)
            : Colors.black87,
      );
      x += cw;
    }
    y += 40;
  }
  y += 30;

  // Net kaybı: en çok kazandıracak konular.
  text(
    tr('En çok net kaybettiren konular'),
    Offset(m, y),
    size: 26,
    weight: FontWeight.w800,
    width: 1100,
  );
  y += 44;
  final loss = lostNetMap(c.outcomes, limit: 10);
  if (loss.isEmpty) {
    text(tr('Kazanım bilgisi yok.'), Offset(m, y), width: 1100);
    y += 36;
  }
  for (final o in loss) {
    canvas.drawLine(Offset(m, y - 4), Offset(w - m, y - 4), line);
    text(
      '${subjectByCode(o.subject).name} · ${o.outcome}',
      Offset(m, y + 4),
      size: 19,
      width: 720,
      maxLines: 1,
    );
    text(
      tr('{c}/{q} doğru · %{p}', {
        'c': o.correct,
        'q': o.questions,
        'p': formatNet(o.successPct),
      }),
      Offset(m + 730, y + 4),
      size: 19,
      width: 220,
      maxLines: 1,
    );
    text(
      tr('−{n} net', {'n': formatNet(o.lostNet)}),
      Offset(m + 960, y + 4),
      size: 19,
      weight: FontWeight.w800,
      color: const Color(0xFFC0392B),
      width: 140,
      maxLines: 1,
    );
    y += 38;
    if (y > h - 260) break;
  }
  y += 24;

  // Yanlış ve boş sorular (kısa liste).
  final missed = [
    for (final r in c.responses)
      if (r.correct != null && r.marked != r.correct) r,
  ];
  if (missed.isNotEmpty && y < h - 200) {
    text(
      tr('Yanlış ve boş sorular'),
      Offset(m, y),
      size: 26,
      weight: FontWeight.w800,
      width: 1100,
    );
    y += 44;
    final bySubject = <String, List<String>>{};
    for (final r in missed) {
      bySubject
          .putIfAbsent(r.subject, () => [])
          .add(
            '${r.shownNumber}${r.marked == null ? '(${tr('boş')})' : '(${r.marked}→${r.correct})'}',
          );
    }
    for (final e in bySubject.entries) {
      final used = text(
        '${subjectByCode(e.key).name}: ${e.value.join('  ')}',
        Offset(m, y),
        size: 18,
        width: 1100,
        maxLines: 3,
      );
      y += used + 10;
      if (y > h - 120) break;
    }
  }

  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  final rgba = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: data!.buffer,
    numChannels: 4,
  );
  return (img.encodeJpg(rgba, quality: 88), w, h);
}
