import '../core/constants/exam_subjects.dart';
import '../features/exam_analysis/data/exam_report_repository.dart';
import '../features/exam_analysis/domain/outcome_analysis.dart';
import '../features/exam_import/data/exam_admin_repository.dart';
import '../features/exam_import/domain/exam_definition.dart';
import '../features/exam_import/domain/exam_scorer.dart';
import '../features/exam_import/domain/import_plan.dart';
import '../features/exam_import/domain/optic_result_parser.dart';

class _Sheet {
  _Sheet(this.booklet, this.answers);
  String booklet;
  Map<String, List<String?>> answers;
}

class _Result {
  _Result(this.examId, this.score, this.classroomId);
  final String examId;
  final ScoredResult score;
  final String? classroomId;
  int? rankOrg;
  int? rankClass;
  final rankSubject = <String, (int?, int?)>{};
}

/// Bellekte kurum sınavları, kazanım havuzu ve karneler (demo ve testler).
/// Sunucudaki kurallar: taslakta yalnızca ham optik; yayınlanınca ve
/// yayındaki sınava her yüklemede ExamScorer ile puanlanır, sıralanır.
class InMemoryExamCenter implements ExamAdminRepository, ExamReportRepository {
  InMemoryExamCenter({
    required this.roster,
    this.classOf = _noClass,
    this.viewerId = 'demo-coach',
  });

  static String? _noClass(String _) => null;

  final List<RosterStudent> roster;

  /// Öğrenci → sınıf kimliği.
  final String? Function(String studentId) classOf;
  final String viewerId;

  final exams = <String, ExamDefinition>{};
  final outcomes = <String, LearningOutcome>{};
  final templates = <String, ImportTemplate>{};
  final sheets = <String, Map<String, _Sheet>>{};
  final _results = <String, Map<String, _Result>>{};
  final imports = <Map<String, Object?>>[];
  var _seq = 0;

  String _id(String p) => '$p-${++_seq}';

  RosterStudent? _student(String id) {
    for (final s in roster) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Demo verisi: kazanım havuzu, kayıtlı şablon, yayında bir deneme ve
  /// taslak bir deneme.
  factory InMemoryExamCenter.demo({
    required List<RosterStudent> roster,
    String? Function(String studentId) classOf = _noClass,
    String viewerId = 'demo-coach',
  }) {
    final c = InMemoryExamCenter(
      roster: roster,
      classOf: classOf,
      viewerId: viewerId,
    );
    String add(String subject, String name, [String? parent]) {
      final id = c._id('lo');
      c.outcomes[id] = LearningOutcome(
        id: id,
        subject: subject,
        name: name,
        parentId: parent,
      );
      return id;
    }

    final problems = add('TYT_MAT', 'Problemler');
    final yas = add('TYT_MAT', 'Yaş problemleri', problems);
    final isci = add('TYT_MAT', 'İşçi problemleri', problems);
    final sayi = add('TYT_MAT', 'Temel kavramlar');
    final paragraf = add('TYT_TUR', 'Paragraf');
    final anaFikir = add('TYT_TUR', 'Ana düşünce', paragraf);
    final sozcuk = add('TYT_TUR', 'Sözcükte anlam');
    c.templates['tpl-1'] = const ImportTemplate(
      id: 'tpl-1',
      name: 'Okul optik okuyucusu',
      studentNo: 'ogrenci_no',
      studentName: 'ad_soyad',
      className: 'sinif',
      booklet: 'kitapcik',
      columns: [
        AnswerColumn(column: 'TURKCE_CEVAP', subjects: ['TYT_TUR']),
        AnswerColumn(column: 'MAT_CEVAP', subjects: ['TYT_MAT']),
      ],
    );

    List<KeyQuestion> key(DateTime day) => [
      for (var n = 1; n <= 10; n++)
        KeyQuestion(
          subject: 'TYT_MAT',
          number: n,
          correct: 'ABCDE'[(n * 3 + day.day) % 5],
          outcomeId: n <= 3 ? yas : (n <= 6 ? isci : sayi),
          outcome: c.label(n <= 3 ? yas : (n <= 6 ? isci : sayi)),
          cancelled: n == 10 && day.day == 1,
        ),
      for (var n = 1; n <= 10; n++)
        KeyQuestion(
          subject: 'TYT_TUR',
          number: n,
          correct: 'ABCDE'[(n + day.day) % 5],
          outcomeId: n <= 6 ? anaFikir : sozcuk,
          outcome: c.label(n <= 6 ? anaFikir : sozcuk),
        ),
    ];
    ExamDefinition def(String id, String name, DateTime day, ExamStatus st) =>
        ExamDefinition(
          id: id,
          name: name,
          examType: ExamType.tyt,
          takenOn: day,
          status: st,
          createdBy: viewerId,
          subjects: const [
            ExamSubjectDef(code: 'TYT_TUR', questionCount: 10),
            ExamSubjectDef(code: 'TYT_MAT', questionCount: 10),
          ],
          questions: key(day),
        );

    final now = DateTime.now();
    final d1 = DateTime(
      now.year,
      now.month,
      1,
    ).subtract(const Duration(days: 20));
    final d2 = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 3));
    c.exams['org-exam-1'] = def(
      'org-exam-1',
      'Kurum Denemesi 1',
      d1,
      ExamStatus.published,
    );
    c.exams['org-exam-2'] = def(
      'org-exam-2',
      'Kurum Denemesi 2',
      d2,
      ExamStatus.published,
    );
    c.exams['org-exam-3'] = def(
      'org-exam-3',
      'Kurum Denemesi 3 (taslak)',
      d2.add(const Duration(days: 2)),
      ExamStatus.draft,
    );
    // Öğrenci başına farklı başarı: her öğrenci cevapların bir kısmını tutturur.
    for (final (i, s) in roster.indexed) {
      for (final id in ['org-exam-1', 'org-exam-2']) {
        final e = c.exams[id]!;
        final hit = id == 'org-exam-1' ? 5 + i : 6 + i;
        String? mark(KeyQuestion q, int n) => n % 10 < hit
            ? q.correct
            : (n % 4 == 0 ? null : 'ABCDE'[(n + 1) % 5]);
        c.sheets.putIfAbsent(id, () => {})[s.id] = _Sheet('A', {
          for (final subj in e.subjects)
            subj.code: [
              for (final q in e.questions.where((q) => q.subject == subj.code))
                mark(q, q.number + (subj.code == 'TYT_MAT' ? i : 0)),
            ],
        });
      }
    }
    c._rescore('org-exam-1');
    c._rescore('org-exam-2');
    return c;
  }

  String label(String outcomeId) =>
      OutcomeTree([...outcomes.values]).label(outcomeId);

  void _rescore(String id) {
    final e = exams[id]!;
    if (e.isDraft) return;
    final out = <String, _Result>{};
    for (final MapEntry(key: student, value: s) in (sheets[id] ?? {}).entries) {
      try {
        out[student] = _Result(
          '$id/$student',
          ExamScorer.score(s.answers, s.booklet, e),
          classOf(student),
        );
      } on NoBookletKeyException {
        continue;
      }
    }
    // Sıralama: rank() — eşit nete aynı sıra.
    int rank(Iterable<double> all, double v) =>
        all.where((x) => x > v).length + 1;
    for (final r in out.values) {
      r.rankOrg = rank(
        out.values.map((x) => x.score.totalNet),
        r.score.totalNet,
      );
      if (r.classroomId != null) {
        r.rankClass = rank(
          out.values
              .where((x) => x.classroomId == r.classroomId)
              .map((x) => x.score.totalNet),
          r.score.totalNet,
        );
      }
      for (final s in r.score.subjects.values) {
        final same = out.values
            .map((x) => x.score.subjects[s.subject])
            .whereType<SubjectScore>();
        r.rankSubject[s.subject] = (
          rank(same.map((x) => x.net), s.net),
          r.classroomId == null
              ? null
              : rank([
                  for (final x in out.values)
                    if (x.classroomId == r.classroomId &&
                        x.score.subjects[s.subject] != null)
                      x.score.subjects[s.subject]!.net,
                ], s.net),
        );
      }
    }
    _results[id] = out;
  }

  // ------------------------------------------------------------------
  // ExamAdminRepository
  // ------------------------------------------------------------------
  @override
  Future<List<ExamDefinition>> fetchExams() async => [
    for (final e in exams.values)
      e.copyWith(sheetCount: sheets[e.id]?.length ?? 0),
  ]..sort((a, b) => b.takenOn.compareTo(a.takenOn));

  @override
  Future<ExamDefinition> fetchExam(String id) async {
    final e = exams[id];
    if (e == null) throw StateError('KEY_NOT_FOUND');
    return e.copyWith(sheetCount: sheets[id]?.length ?? 0);
  }

  @override
  Future<String> saveExam(ExamDefinition exam) async {
    final old = exam.id == null ? null : exams[exam.id];
    if (old != null && old.examType != exam.examType) {
      throw const ExamLockedTypeException();
    }
    final id = exam.id ?? _id('exam');
    final tree = OutcomeTree([...outcomes.values]);
    exams[id] = exam.copyWith(
      id: id,
      status: old?.status ?? ExamStatus.draft,
      questions: [
        for (final q in exam.questions)
          q.outcomeId == null
              ? q
              : q.copyWith(outcome: tree.label(q.outcomeId!)),
      ],
    );
    if (old != null) _rescore(id);
    return id;
  }

  @override
  Future<int> publishExam(String id) async {
    final e = exams[id]!;
    if (!e.isDraft) throw StateError('ALREADY_PUBLISHED');
    exams[id] = e.copyWith(status: ExamStatus.published);
    _rescore(id);
    return _results[id]?.length ?? 0;
  }

  @override
  Future<void> deleteExam(String id) async {
    exams.remove(id);
    sheets.remove(id);
    _results.remove(id);
  }

  @override
  Future<List<ClassroomRef>> fetchClassrooms() async {
    final names = <String, String>{};
    for (final s in roster) {
      final id = classOf(s.id);
      if (id != null) names[id] = s.className ?? id;
    }
    return [
      for (final e in names.entries) ClassroomRef(id: e.key, name: e.value),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<List<LearningOutcome>> fetchOutcomes() async => [...outcomes.values];

  @override
  Future<LearningOutcome> addOutcome({
    required String subject,
    required String name,
    String? parentId,
    String? code,
  }) async {
    final dup = outcomes.values.any(
      (o) =>
          o.subject == subject &&
          o.parentId == parentId &&
          foldTr(o.name) == foldTr(name),
    );
    if (dup) throw StateError('learning_outcomes_unique');
    final id = _id('lo');
    return outcomes[id] = LearningOutcome(
      id: id,
      subject: subject,
      name: name.trim(),
      parentId: parentId,
      code: code,
    );
  }

  @override
  Future<void> updateOutcome(
    String id, {
    required String name,
    String? code,
  }) async {
    final o = outcomes[id]!;
    outcomes[id] = LearningOutcome(
      id: id,
      subject: o.subject,
      name: name.trim(),
      parentId: o.parentId,
      code: code,
      topicId: o.topicId,
    );
  }

  @override
  Future<void> deleteOutcome(String id) async {
    final remove = {id};
    var grew = true;
    while (grew) {
      final more = {
        for (final o in outcomes.values)
          if (o.parentId != null && remove.contains(o.parentId)) o.id,
      };
      grew = !remove.containsAll(more);
      remove.addAll(more);
    }
    outcomes.removeWhere((k, _) => remove.contains(k));
  }

  @override
  Future<({int inserted, int skipped})> importOutcomes(
    List<OutcomeImportRow> rows,
  ) async {
    var ins = 0;
    var skip = 0;
    LearningOutcome? find(String subject, String? parent, String name) {
      for (final o in outcomes.values) {
        if (o.subject == subject &&
            o.parentId == parent &&
            foldTr(o.name) == foldTr(name)) {
          return o;
        }
      }
      return null;
    }

    for (final r in rows) {
      if (examSubjects.every((s) => s.code != r.subject) ||
          r.topic.trim().isEmpty) {
        skip++;
        continue;
      }
      var parent = find(r.subject, null, r.topic);
      final sub = r.subtopic?.trim() ?? '';
      if (parent == null) {
        parent = await addOutcome(
          subject: r.subject,
          name: r.topic,
          code: sub.isEmpty ? r.code : null,
        );
        ins++;
      } else if (sub.isEmpty) {
        skip++;
      }
      if (sub.isNotEmpty) {
        if (find(r.subject, parent.id, sub) == null) {
          await addOutcome(
            subject: r.subject,
            name: sub,
            parentId: parent.id,
            code: r.code,
          );
          ins++;
        } else {
          skip++;
        }
      }
    }
    return (inserted: ins, skipped: skip);
  }

  @override
  Future<List<ImportTemplate>> fetchTemplates() async => [...templates.values];

  @override
  Future<ImportTemplate> saveTemplate(ImportTemplate template) async {
    var id = template.id;
    for (final t in templates.values) {
      if (id == null && foldTr(t.name) == foldTr(template.name)) id = t.id;
    }
    id ??= _id('tpl');
    return templates[id] = template.copyWith(id: id);
  }

  @override
  Future<List<RosterStudent>> fetchRoster() async => [...roster];

  @override
  Future<int> sheetCount(String examId) async => sheets[examId]?.length ?? 0;

  @override
  Future<ImportOutcome> importSheets({
    required String examId,
    required String fileName,
    required Map<String, Object?> stats,
    required List<SheetUpload> sheets,
    void Function(double progress)? onProgress,
  }) async {
    final e = exams[examId]!;
    final skipped = <String>[];
    var saved = 0;
    for (final (i, s) in sheets.indexed) {
      if (_student(s.studentId) == null ||
          (s.booklet != 'A' && !e.bookletList.contains(s.booklet))) {
        skipped.add(s.studentId);
      } else {
        this.sheets.putIfAbsent(examId, () => {})[s.studentId] = _Sheet(
          s.booklet,
          s.answers,
        );
        saved++;
      }
      if ((i + 1) % importChunk == 0 || i == sheets.length - 1) {
        onProgress?.call((i + 1) / sheets.length);
      }
    }
    imports.add({'exam': examId, 'file': fileName, ...stats, 'saved': saved});
    _rescore(examId);
    return ImportOutcome(
      saved: saved,
      skipped: skipped,
      sheets: this.sheets[examId]?.length ?? 0,
      published: !e.isDraft,
    );
  }

  // ------------------------------------------------------------------
  // ExamReportRepository
  // ------------------------------------------------------------------
  (String, String)? _split(String examId) {
    final i = examId.lastIndexOf('/');
    return i < 0 ? null : (examId.substring(0, i), examId.substring(i + 1));
  }

  List<OutcomeStat> _stats(String key, String student) {
    final e = exams[key]!;
    final r = _results[key]![student]!;
    return outcomeStats(
      r.score.responses,
      penalty: e.penalty,
      weights: {for (final s in e.subjects) s.code: s.weight},
      examId: r.examId,
      takenOn: e.takenOn,
    );
  }

  @override
  Future<List<CardSummary>> fetchCards(String studentId) async => [
    for (final MapEntry(key: key, value: rs) in _results.entries)
      if (rs[studentId] != null)
        CardSummary(
          examId: rs[studentId]!.examId,
          name: exams[key]!.name,
          takenOn: exams[key]!.takenOn,
          examType: exams[key]!.examType,
          totalNet: rs[studentId]!.score.totalNet,
          rankOrg: rs[studentId]!.rankOrg,
        ),
  ]..sort((a, b) => b.takenOn.compareTo(a.takenOn));

  ReportCard _card(String key, String student) {
    final e = exams[key]!;
    final rs = _results[key]!;
    final r = rs[student]!;
    final same = [
      for (final x in rs.values)
        if (r.classroomId != null && x.classroomId == r.classroomId) x,
    ];
    double avg(Iterable<double> v) =>
        v.isEmpty ? 0 : round2(v.reduce((a, b) => a + b) / v.length);
    // Önceki: aynı türde, daha eski yayındaki sınav.
    _Result? prev;
    DateTime? prevDay;
    for (final MapEntry(key: k, value: list) in _results.entries) {
      final pe = exams[k]!;
      final p = list[student];
      if (p == null || pe.examType != e.examType) continue;
      if (!pe.takenOn.isBefore(e.takenOn)) continue;
      if (prevDay == null || pe.takenOn.isAfter(prevDay)) {
        prev = p;
        prevDay = pe.takenOn;
      }
    }
    // AYT/YDT puanı için aynı gün ya da önceki en yakın TYT netleri.
    _Result? tyt;
    DateTime? tytDay;
    if (e.examType != ExamType.tyt) {
      for (final MapEntry(key: k, value: list) in _results.entries) {
        final te = exams[k]!;
        final t = list[student];
        if (t == null || te.examType != ExamType.tyt) continue;
        if (te.takenOn.isAfter(e.takenOn)) continue;
        if (tytDay == null || te.takenOn.isAfter(tytDay)) {
          tyt = t;
          tytDay = te.takenOn;
        }
      }
    }
    final s = _student(student);
    return ReportCard(
      tytNets: {
        for (final sc in tyt?.score.subjects.values ?? const <Never>[])
          sc.subject: sc.net,
      },
      examId: r.examId,
      studentId: student,
      studentName: s?.name,
      studentNumber: s?.number,
      examName: e.name,
      examType: e.examType,
      takenOn: e.takenOn,
      booklet: sheets[key]![student]!.booklet,
      totalNet: r.score.totalNet,
      rankOrg: r.rankOrg,
      rankClass: r.rankClass,
      orgCount: rs.length,
      classCount: r.classroomId == null ? null : same.length,
      className: s?.className,
      orgAvg: avg(rs.values.map((x) => x.score.totalNet)),
      classAvg: r.classroomId == null
          ? null
          : avg(same.map((x) => x.score.totalNet)),
      previousTotal: prev?.score.totalNet,
      subjects: [
        for (final sc in r.score.subjects.values)
          CardSubject(
            subject: sc.subject,
            correct: sc.correct,
            wrong: sc.wrong,
            blank: sc.blank,
            net: sc.net,
            weight: sc.weight,
            rankOrg: r.rankSubject[sc.subject]?.$1,
            rankClass: r.rankSubject[sc.subject]?.$2,
            orgAvg: avg(
              rs.values
                  .map((x) => x.score.subjects[sc.subject]?.net)
                  .whereType<double>(),
            ),
            classAvg: r.classroomId == null
                ? null
                : avg(
                    same
                        .map((x) => x.score.subjects[sc.subject]?.net)
                        .whereType<double>(),
                  ),
            previousNet: prev?.score.subjects[sc.subject]?.net,
          ),
      ],
      responses: r.score.responses,
      outcomes: _stats(key, student),
    );
  }

  @override
  Future<ReportCard> fetchCard(String examId) async {
    final p = _split(examId);
    if (p == null || _results[p.$1]?[p.$2] == null) {
      throw StateError('NOT_ALLOWED');
    }
    return _card(p.$1, p.$2);
  }

  @override
  Future<List<ReportCard>> fetchCardsForExam(
    String keyId, {
    String? classroomId,
  }) async {
    final rs = _results[keyId] ?? const {};
    final cards = [
      for (final MapEntry(key: student, value: r) in rs.entries)
        if (classroomId == null || r.classroomId == classroomId)
          _card(keyId, student),
    ]..sort((a, b) => (a.rankOrg ?? 0).compareTo(b.rankOrg ?? 0));
    return cards;
  }

  @override
  Future<List<OutcomeStat>> fetchOutcomeHistory(String studentId) async => [
    for (final MapEntry(key: key, value: rs) in _results.entries)
      if (rs[studentId] != null) ..._stats(key, studentId),
  ];

  @override
  Future<ExamReport> fetchReport(String keyId) async {
    final e = exams[keyId]!;
    final rs = _results[keyId] ?? const {};
    if (rs.isEmpty) return ExamReport.empty;
    double avg(Iterable<num> v) =>
        v.isEmpty ? 0 : round2(v.fold<double>(0, (a, b) => a + b) / v.length);
    final totals = [for (final r in rs.values) r.score.totalNet];
    final all = [
      for (final MapEntry(key: student, value: _) in rs.entries)
        ..._stats(keyId, student),
    ];
    List<OutcomeStat> merge(Iterable<OutcomeStat> list) {
      final g = <(String, String), List<OutcomeStat>>{};
      for (final s in list) {
        g.putIfAbsent((s.subject, s.outcomeKey), () => []).add(s);
      }
      return [
        for (final MapEntry(key: (subject, key), value: v) in g.entries)
          OutcomeStat(
            subject: subject,
            outcomeKey: key,
            outcome: v.first.outcome,
            questions: v.fold(0, (a, s) => a + s.questions),
            correct: v.fold(0, (a, s) => a + s.correct),
            wrong: v.fold(0, (a, s) => a + s.wrong),
            blank: v.fold(0, (a, s) => a + s.blank),
            lostNet: avg(v.map((s) => s.lostNet)),
            students: v.length,
          ),
      ]..sort((a, b) {
        final c = a.successPct.compareTo(b.successPct);
        return c != 0 ? c : b.lostNet.compareTo(a.lostNet);
      });
    }

    final classes = await fetchClassrooms();
    final ranked = [...rs.entries]
      ..sort((a, b) => (a.value.rankOrg ?? 0).compareTo(b.value.rankOrg ?? 0));
    final questions = <QuestionStat>[];
    for (final q in e.questions) {
      if (q.isCancelled) continue;
      final res = [
        for (final r in ranked)
          for (final x in r.value.score.responses)
            if (x.subject == q.subject && x.number == q.number) x,
      ];
      if (res.isEmpty) continue;
      final n = res.length;
      final cut = (n * 0.27).ceil();
      double rate(Iterable<QuestionResponse> x) => x.isEmpty
          ? 0
          : x.where((r) => r.result == ResponseResult.correct).length /
                x.length;
      final wrongMarks = <String, int>{};
      for (final r in res) {
        if (r.result == ResponseResult.wrong) {
          wrongMarks[r.marked!] = (wrongMarks[r.marked!] ?? 0) + 1;
        }
      }
      questions.add(
        QuestionStat(
          subject: q.subject,
          number: q.number,
          students: n,
          correctPct: (rate(res) * 1000).round() / 10,
          blankPct:
              (res.where((r) => r.result == ResponseResult.blank).length /
                      n *
                      1000)
                  .round() /
              10,
          correctAnswer: q.correct,
          outcome: q.outcome,
          topWrong: wrongMarks.isEmpty
              ? null
              : (wrongMarks.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                    .first
                    .key,
          discrimination: round2(rate(res.take(cut)) - rate(res.skip(n - cut))),
        ),
      );
    }
    return ExamReport(
      students: rs.length,
      avgNet: avg(totals),
      maxNet: totals.reduce((a, b) => a > b ? a : b),
      minNet: totals.reduce((a, b) => a < b ? a : b),
      subjects: [
        for (final s in e.subjects)
          () {
            final xs = [
              for (final r in rs.values)
                if (r.score.subjects[s.code] != null) r.score.subjects[s.code]!,
            ];
            final hist = <int, int>{};
            for (final x in xs) {
              final b = (x.net / 5).floor() * 5;
              hist[b] = (hist[b] ?? 0) + 1;
            }
            return SubjectReport(
              subject: s.code,
              avgNet: avg(xs.map((x) => x.net)),
              avgCorrect: avg(xs.map((x) => x.correct)),
              avgWrong: avg(xs.map((x) => x.wrong)),
              avgBlank: avg(xs.map((x) => x.blank)),
              histogram: hist,
            );
          }(),
      ],
      classes: [
        for (final c in classes)
          if (rs.values.any((r) => r.classroomId == c.id))
            () {
              final xs = [
                for (final r in rs.values)
                  if (r.classroomId == c.id) r,
              ];
              return ClassReport(
                id: c.id,
                name: c.name,
                students: xs.length,
                avgNet: avg(xs.map((x) => x.score.totalNet)),
                subjects: {
                  for (final s in e.subjects)
                    s.code: avg(
                      xs
                          .map((x) => x.score.subjects[s.code]?.net)
                          .whereType<double>(),
                    ),
                },
              );
            }(),
      ],
      weakOutcomes: merge(all).take(10).toList(),
      classOutcomes: {
        for (final c in classes)
          c.id: merge([
            for (final MapEntry(key: student, value: r) in rs.entries)
              if (r.classroomId == c.id) ..._stats(keyId, student),
          ]).take(5).toList(),
      },
      questions: questions,
      ranking: [
        for (final MapEntry(key: student, value: r) in ranked)
          RankRow(
            examId: r.examId,
            studentId: student,
            name: _student(student)?.name ?? student,
            studentNumber: _student(student)?.number,
            classroomId: r.classroomId,
            booklet: sheets[keyId]?[student]?.booklet,
            totalNet: r.score.totalNet,
            rankOrg: r.rankOrg,
            rankClass: r.rankClass,
            subjects: r.score.subjects,
          ),
      ],
    );
  }
}
