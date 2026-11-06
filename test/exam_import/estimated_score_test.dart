import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/features/exam_analysis/data/exam_report_repository.dart';
import 'package:mentoria/features/exam_analysis/presentation/report_card_pdf.dart';
import 'package:mentoria/features/exams/data/yks_score.dart';

ReportCard _card(
  ExamType type,
  Map<String, double> nets, {
  FieldType? field,
  Map<String, double> tyt = const {},
}) => ReportCard(
  examId: 'e',
  studentId: 's',
  examName: 'Deneme',
  examType: type,
  field: field,
  takenOn: DateTime(2026, 11, 1),
  totalNet: nets.values.fold(0, (a, b) => a + b),
  subjects: [
    for (final e in nets.entries)
      CardSubject(
        subject: e.key,
        correct: e.value.round(),
        wrong: 0,
        blank: 0,
        net: e.value,
        weight: 1,
      ),
  ],
  responses: const [],
  outcomes: const [],
  tytNets: tyt,
);

void main() {
  const tyt = {'TYT_TUR': 30.0, 'TYT_MAT': 25.0};

  test('TYT karnesi kendi netleriyle puanlanır', () {
    final s = estimatedScore(_card(ExamType.tyt, tyt))!;
    expect(s.type, ScoreType.tyt);
    expect(s.score, closeTo(computeScore(ScoreType.tyt, tyt).raw, 1e-9));
  });

  test('AYT karnesi TYT denemesi yoksa puan göstermez', () {
    expect(
      estimatedScore(
        _card(ExamType.ayt, {'AYT_MAT': 20}, field: FieldType.say),
      ),
      isNull,
    );
  });

  test('AYT puanı alanına göre TYT netleriyle hesaplanır', () {
    final s = estimatedScore(
      _card(
        ExamType.ayt,
        {'AYT_MAT': 20, 'AYT_FIZ': 7},
        field: FieldType.say,
        tyt: tyt,
      ),
    )!;
    expect(s.type, ScoreType.say);
    expect(
      s.score,
      closeTo(
        computeScore(ScoreType.say, {...tyt, 'AYT_MAT': 20, 'AYT_FIZ': 7}).raw,
        1e-9,
      ),
    );
    expect(scoreLabel(s.type), 'Tahmini SAY puanı');
  });

  test('alan yoksa girilen AYT derslerine uyan tür seçilir', () {
    final s = estimatedScore(
      _card(ExamType.ayt, {'AYT_EDB': 18, 'AYT_TAR1': 6}, tyt: tyt),
    )!;
    expect(s.type, anyOf(ScoreType.ea, ScoreType.soz));
    expect(
      estimatedScore(
        _card(ExamType.ayt, {'AYT_FIZ': 10, 'AYT_KIM': 8}, tyt: tyt),
      )!.type,
      ScoreType.say,
    );
  });

  test('YDT dil puanıdır', () {
    final s = estimatedScore(_card(ExamType.ydt, {'YDT_YD': 60}, tyt: tyt))!;
    expect(s.type, ScoreType.dil);
  });
}
