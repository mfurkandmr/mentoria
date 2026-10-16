import 'dart:math';

import '../../../core/constants/exam_subjects.dart';

class SubjectResult {
  const SubjectResult({
    required this.code,
    required this.correct,
    required this.wrong,
    required this.blank,
  });

  final String code;
  final int correct;
  final int wrong;
  final int blank;

  double get net => calculateNet(correct, wrong);
  ExamSubject get subject => subjectByCode(code);
}

class Exam {
  const Exam({
    required this.id,
    required this.examType,
    required this.name,
    required this.takenOn,
    required this.results,
    this.field,
    this.publisher,
    this.createdAt,
  });

  final String id;
  final ExamType examType;
  final FieldType? field;
  final String name;
  final String? publisher;
  final DateTime takenOn;
  final List<SubjectResult> results;

  /// Kaydın girildiği an. Aynı güne birden çok deneme girilince hangisinin
  /// "son" olduğunu bu belirler (taken_on saat içermez).
  final DateTime? createdAt;

  double get totalNet => results.fold(0, (sum, r) => sum + r.net);

  /// Girildikten sonraki düzeltme süresi; sonra silinemez ve değiştirilemez
  /// (sunucudaki exam_editable ile aynı).
  static const editWindow = Duration(days: 7);

  /// Hâlâ silinebilir/düzeltilebilir mi. Giriş zamanı bilinmiyorsa hayır.
  bool get editable =>
      createdAt != null && DateTime.now().difference(createdAt!) < editWindow;

  /// Eskiden yeniye: önce deneme tarihi, aynı günse giriş zamanı.
  static int byDate(Exam a, Exam b) {
    final day = a.takenOn.compareTo(b.takenOn);
    if (day != 0) return day;
    return (a.createdAt ?? a.takenOn).compareTo(b.createdAt ?? b.takenOn);
  }
}

/// Yeni deneme kaydı.
class ExamDraft {
  const ExamDraft({
    required this.examType,
    required this.name,
    required this.takenOn,
    required this.results,
    this.field,
    this.publisher,
    this.imported = false,
    this.batchId,
  });

  /// Dosyadan toplu yüklendiyse true (veritabanında source = 'import').
  final bool imported;

  /// Aynı yüklemedeki tüm öğrencilerin denemeleri aynı paket kimliğini
  /// taşır (Denemeler ekranında tek satır, tek seferde silinir). Boşsa
  /// deneme kendi paketidir.
  final String? batchId;

  final ExamType examType;
  final FieldType? field;
  final String name;
  final String? publisher;
  final DateTime takenOn;
  final List<SubjectResult> results;
}

/// Bir sınav türündeki denemelerin özeti. [exams] tarihe göre eskiden yeniye.
class ExamStats {
  ExamStats(List<Exam> exams) : exams = [...exams]..sort(Exam.byDate);

  final List<Exam> exams;

  bool get isEmpty => exams.isEmpty;

  Exam? get last => exams.isEmpty ? null : exams.last;

  /// Son denemenin bir öncekine göre farkı.
  double? get lastChange => exams.length < 2
      ? null
      : exams.last.totalNet - exams[exams.length - 2].totalNet;

  /// Son 5 denemenin ortalama toplam neti.
  double? get recentAverage {
    if (exams.isEmpty) return null;
    final recent = exams.reversed.take(5);
    return recent.fold<double>(0, (s, e) => s + e.totalNet) / recent.length;
  }

  double? get best => exams.isEmpty
      ? null
      : exams.map((e) => e.totalNet).reduce((a, b) => a > b ? a : b);

  /// Bir denemenin kendisinden önceki aynı türdeki denemeye göre farkı.
  double? changeFor(Exam exam) {
    final i = exams.indexWhere((e) => e.id == exam.id);
    if (i <= 0) return null;
    return exam.totalNet - exams[i - 1].totalNet;
  }

  /// Son 5 denemede ders bazlı ortalama net (yalnızca girilen dersler).
  Map<String, double> recentSubjectAverages() {
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (final exam in exams.reversed.take(5)) {
      for (final r in exam.results) {
        sums[r.code] = (sums[r.code] ?? 0) + r.net;
        counts[r.code] = (counts[r.code] ?? 0) + 1;
      }
    }
    return {for (final c in sums.keys) c: sums[c]! / counts[c]!};
  }
}

/// Bir yükleme: aynı anda girilen deneme(ler). Excel yüklemesinde bir paket
/// birçok öğrencinin denemesini içerir.
class ExamBatch {
  const ExamBatch({
    required this.id,
    required this.name,
    required this.examType,
    required this.takenOn,
    required this.uploadedAt,
    required this.studentCount,
    required this.avgNet,
    required this.editableUntil,
    required this.editable,
    this.field,
    this.publisher,
    this.imported = false,
  });

  factory ExamBatch.fromJson(Map<String, dynamic> j) => ExamBatch(
    id: j['batch_id'] as String,
    name: j['name'] as String,
    examType: ExamType.fromDb(j['exam_type'] as String),
    field: FieldType.fromDb(j['field'] as String?),
    publisher: j['publisher'] as String?,
    takenOn: DateTime.parse(j['taken_on'] as String),
    imported: j['source'] == 'import',
    uploadedAt: DateTime.parse(j['uploaded_at'] as String).toLocal(),
    studentCount: j['student_count'] as int,
    avgNet: (j['avg_net'] as num?)?.toDouble() ?? 0,
    editableUntil: DateTime.parse(j['editable_until'] as String).toLocal(),
    editable: j['editable'] as bool? ?? false,
  );

  final String id;
  final String name;
  final ExamType examType;
  final FieldType? field;
  final String? publisher;
  final DateTime takenOn;

  /// Excel'den toplu yüklendi (değilse elle girildi).
  final bool imported;
  final DateTime uploadedAt;
  final int studentCount;
  final double avgNet;

  /// Bu ana kadar silinebilir; sonra kilitlenir.
  final DateTime editableUntil;
  final bool editable;
}

/// Düzeltme süresi (7 gün) geçmiş deneme silinmek/değiştirilmek istendi.
class ExamLockedException implements Exception {
  const ExamLockedException();
}

/// Yeni paket kimliği (UUID v4).
String newBatchId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
