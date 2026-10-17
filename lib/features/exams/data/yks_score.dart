import 'dart:math' as math;

import '../../../core/constants/exam_subjects.dart';
import 'exam.dart';

/// YKS puan türleri.
enum ScoreType {
  tyt('TYT'),
  say('SAY'),
  ea('EA'),
  soz('SÖZ'),
  dil('DİL');

  const ScoreType(this.label);
  final String label;

  static ScoreType forField(FieldType? f) => switch (f) {
    FieldType.say => say,
    FieldType.ea => ea,
    FieldType.soz => soz,
    FieldType.dil => dil,
    null => tyt,
  };
}

/// Yaklaşık katsayılar (1 net kaç puan). ÖSYM puanları standart sapmayla
/// hesaplar; bu değerler yıllara göre yayımlanan ortalamalara yakın bir
/// tahmindir. Toplam 100 taban puanla en çok 500 olur.
const _tytCoef = {
  'TYT_TUR': 3.3,
  'TYT_MAT': 3.3,
  'TYT_TAR': 3.4,
  'TYT_COG': 3.4,
  'TYT_FEL': 3.4,
  'TYT_DIN': 3.4,
  'TYT_FIZ': 3.4,
  'TYT_KIM': 3.4,
  'TYT_BIY': 3.4,
};

/// AYT puanlarında TYT'nin payı %40.
const _tytShareInAyt = 0.4;

const _aytCoef = <ScoreType, Map<String, double>>{
  ScoreType.say: {
    'AYT_MAT': 3.0,
    'AYT_FIZ': 2.85,
    'AYT_KIM': 3.07,
    'AYT_BIY': 3.07,
  },
  ScoreType.ea: {
    'AYT_MAT': 3.0,
    'AYT_EDB': 3.0,
    'AYT_TAR1': 2.8,
    'AYT_COG1': 3.33,
  },
  ScoreType.soz: {
    'AYT_EDB': 3.0,
    'AYT_TAR1': 2.8,
    'AYT_COG1': 3.33,
    'AYT_TAR2': 2.91,
    'AYT_COG2': 2.91,
    'AYT_FELG': 3.0,
    'AYT_DIN': 3.33,
  },
  ScoreType.dil: {'YDT_YD': 3.0},
};

/// Puan türünde her dersin 1 netinin değeri.
Map<String, double> scoreCoefficients(ScoreType t) => t == ScoreType.tyt
    ? _tytCoef
    : {
        for (final e in _tytCoef.entries) e.key: e.value * _tytShareInAyt,
        ..._aytCoef[t]!,
      };

/// Puan türü için girilmesi gereken dersler (TYT dersleri dahil).
List<String> scoreSubjects(ScoreType t) => scoreCoefficients(t).keys.toList();

/// Bir dersin en yüksek neti (soru sayısı).
int maxNet(String code) => subjectByCode(code).questionCount;

class YksScore {
  const YksScore({
    required this.type,
    required this.raw,
    required this.placement,
    required this.obpBonus,
  });

  final ScoreType type;

  /// Ham puan (100 + netler × katsayı).
  final double raw;

  /// Yerleştirme puanı (ham + OBP katkısı).
  final double placement;
  final double obpBonus;
}

/// [nets]: ders kodu → net. Eksi netler sıfır sayılır, soru sayısını aşan
/// net kırpılır. [diploma] 50-100 arası; [placedLastYear] ise OBP katkısı
/// yarıya iner.
YksScore computeScore(
  ScoreType type,
  Map<String, double> nets, {
  double? diploma,
  bool placedLastYear = false,
}) {
  var raw = 100.0;
  for (final e in scoreCoefficients(type).entries) {
    final n = (nets[e.key] ?? 0).clamp(0, maxNet(e.key).toDouble());
    raw += n * e.value;
  }
  final obp = diploma == null ? 0.0 : diploma.clamp(50, 100) * 5;
  final bonus = obp * (placedLastYear ? 0.06 : 0.12);
  return YksScore(
    type: type,
    raw: raw,
    placement: raw + bonus,
    obpBonus: bonus,
  );
}

/// Hedefe ulaşmak için tek başına bir dersten gereken net artışı.
class NetGain {
  const NetGain(this.subject, this.coefficient, this.netsNeeded, this.room);
  final String subject;
  final double coefficient;
  final double netsNeeded;

  /// Bu derste daha kazanılabilecek net.
  final double room;

  bool get reachable => netsNeeded <= room + 1e-9;
}

/// [gap] puan için her dersin katkısı; en verimli (1 net en çok puan) önce.
List<NetGain> gainsFor(ScoreType type, Map<String, double> nets, double gap) {
  final out = <NetGain>[];
  for (final e in scoreCoefficients(type).entries) {
    final current = (nets[e.key] ?? 0).clamp(0, maxNet(e.key).toDouble());
    final room = maxNet(e.key) - current;
    if (room <= 0) continue;
    out.add(NetGain(e.key, e.value, gap / e.value, room.toDouble()));
  }
  out.sort((a, b) {
    final c = b.coefficient.compareTo(a.coefficient);
    return c != 0 ? c : b.room.compareTo(a.room);
  });
  return out;
}

/// Son denemelerden başlangıç netleri: her sınav türünün en son denemesi.
Map<String, double> netsFromExams(List<Exam> exams) {
  final out = <String, double>{};
  for (final type in ExamType.values) {
    final latest = exams.where((e) => e.examType == type).toList()
      ..sort(Exam.byDate);
    if (latest.isEmpty) continue;
    for (final r in latest.last.results) {
      out[r.code] = math.max(0, r.net);
    }
  }
  return out;
}
