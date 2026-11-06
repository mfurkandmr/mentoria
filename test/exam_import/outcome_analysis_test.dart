import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/dev/demo_exam_center.dart';
import 'package:mentoria/features/exam_analysis/domain/outcome_analysis.dart';
import 'package:mentoria/features/exam_import/data/exam_admin_repository.dart';
import 'package:mentoria/features/exam_import/domain/exam_definition.dart';
import 'package:mentoria/features/exam_import/domain/exam_scorer.dart';
import 'package:mentoria/features/exam_import/domain/import_plan.dart';

QuestionResponse r(
  int n,
  ResponseResult res,
  String outcome, {
  String s = 'TYT_MAT',
}) => QuestionResponse(
  subject: s,
  number: n,
  result: res,
  outcome: outcome,
  marked: res == ResponseResult.blank ? null : 'A',
  correct: res == ResponseResult.cancelled ? null : 'A',
);

void main() {
  group('kazanım analizi', () {
    test('3 soruluk kazanımda 1 doğru 2 yanlış → %33,3', () {
      final stats = outcomeStats(
        [
          r(1, ResponseResult.correct, 'Problemler'),
          r(2, ResponseResult.wrong, 'Problemler'),
          r(3, ResponseResult.wrong, 'problemler '),
          r(4, ResponseResult.cancelled, 'Problemler'),
          r(5, ResponseResult.blank, 'Sayılar'),
        ],
        penalty: 0.25,
        weights: const {'TYT_MAT': 1.5},
      );
      final p = stats.firstWhere((s) => s.outcome == 'Problemler');
      expect((p.questions, p.correct, p.wrong), (3, 1, 2));
      expect(p.successPct, 33.3);
      expect(p.lostNet, 3.75, reason: '2 × 1,25 × 1,5');
      expect(stats.firstWhere((s) => s.outcome == 'Sayılar').lostNet, 1.5);
    });

    test('zayıf kazanımlar başarıya, net kaybı haritası nete göre', () {
      final stats = outcomeStats([
        r(1, ResponseResult.wrong, 'A konu'),
        r(2, ResponseResult.correct, 'B konu'),
        r(3, ResponseResult.blank, 'B konu'),
        r(4, ResponseResult.blank, 'B konu'),
        r(5, ResponseResult.correct, 'C konu'),
      ], penalty: 0.25);
      expect(weakestOutcomes(stats).map((s) => s.outcome), [
        'A konu',
        'B konu',
      ]);
      expect(lostNetMap(stats).map((s) => s.outcome), ['B konu', 'A konu']);
    });

    test('trend: iki sınavda ölçülen kazanım, kötüleşen önce', () {
      OutcomeStat s(String exam, int day, String o, int c) => OutcomeStat(
        subject: 'TYT_MAT',
        outcomeKey: o,
        outcome: o,
        questions: 4,
        correct: c,
        wrong: 4 - c,
        blank: 0,
        lostNet: 0,
        examId: exam,
        takenOn: DateTime(2026, 10, day),
      );
      final t = outcomeTrends([
        s('e2', 20, 'x', 1),
        s('e1', 1, 'x', 4),
        s('e1', 1, 'y', 1),
        s('e2', 20, 'y', 3),
        s('e1', 1, 'z', 2),
      ]);
      expect(t.map((x) => x.outcomeKey), ['x', 'y']);
      expect(t.first.direction, TrendDirection.worsening);
      expect(t.last.direction, TrendDirection.improving);
    });
  });

  group('bellekteki kurum sınavı', () {
    const roster = [
      RosterStudent(id: 's1', name: 'Ayşe', number: '1'),
      RosterStudent(id: 's2', name: 'Can', number: '2'),
    ];
    ExamDefinition def() => ExamDefinition(
      name: 'Deneme',
      examType: ExamType.tyt,
      takenOn: DateTime(2026, 11, 1),
      subjects: const [ExamSubjectDef(code: 'TYT_MAT', questionCount: 3)],
      questions: const [
        KeyQuestion(subject: 'TYT_MAT', number: 1, correct: 'A', outcome: 'P'),
        KeyQuestion(subject: 'TYT_MAT', number: 2, correct: 'B', outcome: 'P'),
        KeyQuestion(subject: 'TYT_MAT', number: 3, correct: 'C', outcome: 'P'),
      ],
    );

    test('aynı dosya iki kez yüklenince kopya oluşmaz, güncellenir', () async {
      final c = InMemoryExamCenter(roster: roster);
      final id = await c.saveExam(def());
      Future<ImportOutcome> upload(List<String?> s1) => c.importSheets(
        examId: id,
        fileName: 'optik.xlsx',
        stats: const {},
        sheets: [
          SheetUpload(studentId: 's1', booklet: 'A', answers: {'TYT_MAT': s1}),
          const SheetUpload(
            studentId: 'yok',
            booklet: 'A',
            answers: {
              'TYT_MAT': ['A'],
            },
          ),
        ],
      );
      final first = await upload(['A', 'C', 'C']);
      expect((first.saved, first.published), (1, false));
      expect(first.skipped, ['yok']);
      expect(await c.fetchCards('s1'), isEmpty, reason: 'taslak görünmez');
      expect(await c.publishExam(id), 1);
      expect((await c.fetchCards('s1')).single.totalNet, 1.75);

      final again = await upload(['A', 'B', 'C']);
      expect(again.sheets, 1, reason: 'kopya oluşmadı');
      final cards = await c.fetchCards('s1');
      expect(cards.single.totalNet, 3, reason: 'güncellendi');
      final card = await c.fetchCard(cards.single.examId);
      expect(card.outcomes.single.successPct, 100);
    });

    test('yayındaki sınavda soru iptal edilince yeniden puanlanır', () async {
      final c = InMemoryExamCenter(roster: roster);
      final id = await c.saveExam(def());
      await c.publishExam(id);
      await c.importSheets(
        examId: id,
        fileName: 'x',
        stats: const {},
        sheets: const [
          SheetUpload(
            studentId: 's1',
            booklet: 'A',
            answers: {
              'TYT_MAT': ['A', 'A', 'A'],
            },
          ),
        ],
      );
      expect((await c.fetchCards('s1')).single.totalNet, 0.5);
      final e = await c.fetchExam(id);
      await c.saveExam(
        e.copyWith(
          questions: [
            for (final q in e.questions)
              q.number == 2 ? q.copyWith(cancelled: true) : q,
          ],
        ),
      );
      final card = await c.fetchCard((await c.fetchCards('s1')).single.examId);
      final sub = card.subjects.single;
      expect(sub.correct + sub.wrong + sub.blank, 2);
      expect(card.totalNet, 0.75);
    });
  });
}
