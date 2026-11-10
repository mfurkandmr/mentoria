import '../../../core/constants/exam_subjects.dart';

/// Kurum sınavının türü: tam deneme ya da konu tarama.
enum ExamKind {
  deneme('deneme'),
  konuTarama('konu_tarama');

  const ExamKind(this.db);
  final String db;

  static ExamKind fromDb(String? v) =>
      values.firstWhere((k) => k.db == v, orElse: () => deneme);
}

enum ExamStatus {
  draft('draft'),
  published('published');

  const ExamStatus(this.db);
  final String db;

  static ExamStatus fromDb(String? v) =>
      v == 'draft' ? ExamStatus.draft : ExamStatus.published;
}

enum Difficulty {
  easy('easy'),
  medium('medium'),
  hard('hard');

  const Difficulty(this.db);
  final String db;

  static Difficulty? fromDb(String? v) {
    for (final d in values) {
      if (d.db == v) return d;
    }
    return null;
  }
}

/// Kitapçık türleri; A tek kitapçıklı sınavın da anahtarıdır ("TEK").
const bookletTypes = ['A', 'B', 'C', 'D'];

/// Sınavdaki bir ders: soru sayısı ve toplam nete katsayısı.
class ExamSubjectDef {
  const ExamSubjectDef({
    required this.code,
    required this.questionCount,
    this.weight = 1,
  });

  final String code;
  final int questionCount;
  final double weight;

  ExamSubjectDef copyWith({int? questionCount, double? weight}) =>
      ExamSubjectDef(
        code: code,
        questionCount: questionCount ?? this.questionCount,
        weight: weight ?? this.weight,
      );

  Map<String, Object?> toJson() => {
    'subject': code,
    'count': questionCount,
    'weight': weight,
  };
}

/// A kitapçığında bir soru: doğru cevap, kazanım, zorluk, iptal.
/// Yayın öncesi eksikler: ders kodu → soru numaraları.
class ExamKeyGaps {
  const ExamKeyGaps({this.noAnswer = const {}, this.noOutcome = const {}});

  final Map<String, List<int>> noAnswer;
  final Map<String, List<int>> noOutcome;

  int get answerCount => noAnswer.values.fold(0, (s, l) => s + l.length);
  int get outcomeCount => noOutcome.values.fold(0, (s, l) => s + l.length);
  bool get isComplete => answerCount == 0 && outcomeCount == 0;
}

class KeyQuestion {
  const KeyQuestion({
    required this.subject,
    required this.number,
    this.correct,
    this.outcomeId,
    this.outcome,
    this.topicId,
    this.difficulty,
    this.cancelled = false,
  });

  final String subject;
  final int number;

  /// A–E; `null` cevapsız (iptal sayılır).
  final String? correct;
  final String? outcomeId;

  /// Kazanım etiketi ("Konu — Alt konu") ya da serbest metin.
  final String? outcome;
  final int? topicId;
  final Difficulty? difficulty;
  final bool cancelled;

  /// Değerlendirilmez: iptal ya da cevapsız.
  bool get isCancelled => cancelled || correct == null;

  KeyQuestion copyWith({
    String? correct,
    bool clearCorrect = false,
    String? outcomeId,
    String? outcome,
    bool clearOutcome = false,
    Difficulty? difficulty,
    bool clearDifficulty = false,
    bool? cancelled,
  }) => KeyQuestion(
    subject: subject,
    number: number,
    correct: clearCorrect ? null : (correct ?? this.correct),
    outcomeId: clearOutcome ? null : (outcomeId ?? this.outcomeId),
    outcome: clearOutcome ? null : (outcome ?? this.outcome),
    topicId: clearOutcome ? null : topicId,
    difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
    cancelled: cancelled ?? this.cancelled,
  );

  Map<String, Object?> toJson() => {
    'subject': subject,
    'no': number,
    'correct': correct,
    'outcome_id': outcomeId,
    if (outcomeId == null) 'outcome': outcome,
    'topic_id': topicId,
    'difficulty': difficulty?.db,
    'cancelled': cancelled,
  };
}

/// B / C / D kitapçığında bir soru: A'daki karşılığı ve (şıklar karışıksa)
/// bu kitapçıktaki doğru cevap.
class BookletQuestion {
  const BookletQuestion({
    required this.subject,
    required this.number,
    required this.itemNo,
    this.correct,
  });

  final String subject;

  /// Bu kitapçıktaki numara.
  final int number;

  /// Aynı sorunun A kitapçığındaki numarası.
  final int itemNo;

  /// Boşsa A'daki doğru cevap kullanılır.
  final String? correct;

  Map<String, Object?> toJson() => {
    'subject': subject,
    'no': number,
    'item_no': itemNo,
    'correct': correct,
  };
}

/// Kurum sınavı: bilgiler, dersler, cevap anahtarları ve kazanımlar.
class ExamDefinition {
  const ExamDefinition({
    this.id,
    required this.name,
    required this.examType,
    this.kind = ExamKind.deneme,
    this.publisher,
    required this.takenOn,
    this.wrongPenalty = true,
    this.penaltyRatio = 0.25,
    this.status = ExamStatus.draft,
    this.classroomIds = const [],
    this.subjects = const [],
    this.questions = const [],
    this.booklets = const {},
    this.createdBy,
    this.templateId = 'standart_yks',
    this.sheetCount = 0,
  });

  final String? id;
  final String name;
  final ExamType examType;
  final ExamKind kind;
  final String? publisher;
  final DateTime takenOn;

  /// Yanlış doğruyu götürür mü; götürürse kaç yanlış bir doğru (0,25 = 4).
  final bool wrongPenalty;
  final double penaltyRatio;
  final ExamStatus status;
  final List<String> classroomIds;
  final List<ExamSubjectDef> subjects;

  /// A kitapçığı (tek kitapçıklı sınavda tek anahtar).
  final List<KeyQuestion> questions;

  /// Kitapçık → sorular (yalnızca B / C / D).
  final Map<String, List<BookletQuestion>> booklets;
  final String? createdBy;
  final String templateId;

  /// Yüklenmiş optik (öğrenci) sayısı.
  final int sheetCount;

  bool get isDraft => status == ExamStatus.draft;

  /// Bir yanlışın götürdüğü net.
  double get penalty => wrongPenalty ? penaltyRatio : 0;

  /// Sunucudaki yayın kuralı: iptal edilmemiş her sorunun cevabı ve kazanımı
  /// olmalı (öğrenci her sorudaki hatasını ve konusunu görsün diye).
  ExamKeyGaps get keyGaps {
    final noAnswer = <String, List<int>>{};
    final noOutcome = <String, List<int>>{};
    for (final s in subjects) {
      final byNumber = {
        for (final q in questions)
          if (q.subject == s.code) q.number: q,
      };
      for (var n = 1; n <= s.questionCount; n++) {
        final q = byNumber[n];
        if (q?.cancelled ?? false) continue;
        if (q?.correct == null) {
          noAnswer.putIfAbsent(s.code, () => []).add(n);
        }
        final hasOutcome =
            q?.outcomeId != null || (q?.outcome?.trim().isNotEmpty ?? false);
        if (!hasOutcome) noOutcome.putIfAbsent(s.code, () => []).add(n);
      }
    }
    return ExamKeyGaps(noAnswer: noAnswer, noOutcome: noOutcome);
  }

  /// Kullanılabilen kitapçıklar (A her zaman).
  List<String> get bookletList => [
    'A',
    for (final b in bookletTypes.skip(1))
      if (booklets[b]?.isNotEmpty ?? false) b,
  ];

  ExamSubjectDef? subject(String code) {
    for (final s in subjects) {
      if (s.code == code) return s;
    }
    return null;
  }

  KeyQuestion? question(String subject, int number) {
    for (final q in questions) {
      if (q.subject == subject && q.number == number) return q;
    }
    return null;
  }

  ExamDefinition copyWith({
    String? id,
    String? name,
    ExamType? examType,
    ExamKind? kind,
    String? publisher,
    DateTime? takenOn,
    bool? wrongPenalty,
    double? penaltyRatio,
    ExamStatus? status,
    List<String>? classroomIds,
    List<ExamSubjectDef>? subjects,
    List<KeyQuestion>? questions,
    Map<String, List<BookletQuestion>>? booklets,
    int? sheetCount,
  }) => ExamDefinition(
    id: id ?? this.id,
    name: name ?? this.name,
    examType: examType ?? this.examType,
    kind: kind ?? this.kind,
    publisher: publisher ?? this.publisher,
    takenOn: takenOn ?? this.takenOn,
    wrongPenalty: wrongPenalty ?? this.wrongPenalty,
    penaltyRatio: penaltyRatio ?? this.penaltyRatio,
    status: status ?? this.status,
    classroomIds: classroomIds ?? this.classroomIds,
    subjects: subjects ?? this.subjects,
    questions: questions ?? this.questions,
    booklets: booklets ?? this.booklets,
    createdBy: createdBy,
    templateId: templateId,
    sheetCount: sheetCount ?? this.sheetCount,
  );

  /// `save_exam` gövdesi.
  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'exam_type': examType.db,
    'kind': kind.db,
    'publisher': publisher,
    'taken_on': takenOn.toIso8601String().substring(0, 10),
    'wrong_penalty': wrongPenalty,
    'penalty_ratio': penaltyRatio,
    'template_id': templateId,
    'classrooms': classroomIds,
    'subjects': [for (final s in subjects) s.toJson()],
    'items': [
      for (final q in questions)
        if (subject(q.subject) != null &&
            q.number <= subject(q.subject)!.questionCount)
          q.toJson(),
    ],
    'booklets': {
      for (final e in booklets.entries)
        if (e.value.isNotEmpty) e.key: [for (final b in e.value) b.toJson()],
    },
  };
}

/// Kurumun kazanım havuzunda bir düğüm (ders > konu > alt konu).
class LearningOutcome {
  const LearningOutcome({
    required this.id,
    required this.subject,
    required this.name,
    this.parentId,
    this.code,
    this.topicId,
  });

  final String id;
  final String subject;
  final String name;
  final String? parentId;

  /// MEB kazanım kodu.
  final String? code;
  final int? topicId;
}

/// Kazanım ağacı: etiket ("Konu — Alt konu"), alt düğümler, arama.
class OutcomeTree {
  OutcomeTree(this.all) : _byId = {for (final o in all) o.id: o};

  final List<LearningOutcome> all;
  final Map<String, LearningOutcome> _byId;

  LearningOutcome? byId(String? id) => id == null ? null : _byId[id];

  String label(String id) {
    final parts = <String>[];
    var cur = _byId[id];
    var guard = 0;
    while (cur != null && guard++ < 10) {
      parts.insert(0, cur.name);
      cur = cur.parentId == null ? null : _byId[cur.parentId];
    }
    return parts.join(' — ');
  }

  List<LearningOutcome> roots(String subject) => [
    for (final o in all)
      if (o.subject == subject && o.parentId == null) o,
  ]..sort((a, b) => a.name.compareTo(b.name));

  List<LearningOutcome> children(String id) => [
    for (final o in all)
      if (o.parentId == id) o,
  ]..sort((a, b) => a.name.compareTo(b.name));

  /// Dersin tüm kazanımları ağaç sırasıyla (konu, altındakiler, sonraki konu).
  List<LearningOutcome> ordered(String subject) {
    final out = <LearningOutcome>[];
    void walk(LearningOutcome o, int depth) {
      if (depth > 10) return;
      out.add(o);
      for (final c in children(o.id)) {
        walk(c, depth + 1);
      }
    }

    for (final r in roots(subject)) {
      walk(r, 0);
    }
    return out;
  }

  /// Etikette ya da kodda [query] geçen kazanımlar (Türkçe harf duyarsız).
  List<LearningOutcome> search(String subject, String query) {
    final q = foldTr(query);
    return [
      for (final o in ordered(subject))
        if (q.isEmpty ||
            foldTr(label(o.id)).contains(q) ||
            foldTr(o.code ?? '').contains(q))
          o,
    ];
  }
}

/// Karşılaştırma için sadeleştirme: küçük harf, Türkçe harfler Latin.
String foldTr(String s) {
  const map = {
    'İ': 'i',
    'I': 'i',
    'ı': 'i',
    'Ş': 's',
    'ş': 's',
    'Ğ': 'g',
    'ğ': 'g',
    'Ü': 'u',
    'ü': 'u',
    'Ö': 'o',
    'ö': 'o',
    'Ç': 'c',
    'ç': 'c',
    'Â': 'a',
    'â': 'a',
    'Î': 'i',
    'î': 'i',
    'Û': 'u',
    'û': 'u',
  };
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(map[ch] ?? ch.toLowerCase());
  }
  return b.toString().trim();
}
