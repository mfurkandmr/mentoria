import 'dart:math' as math;

import '../core/config/env.dart';
import '../core/constants/exam_subjects.dart';
import '../features/admin/data/cockpit_repository.dart';
import '../features/coach/data/coach_repository.dart';
import '../features/exams/data/exam.dart';
import '../features/finance/data/finance_repository.dart';
import '../features/sms/data/bulk_sms_repository.dart';

/// Sunum demosu için kalabalık kurum (24 öğrenci, 4 koç). Web demosu
/// `--dart-define=DEMO_RICH=true` ile derlenir (tool/web/build_web.py); testler
/// küçük demo verisine bağlı olduğu için varsayılan kapalıdır. Bütün adlar ve
/// telefonlar uydurmadır.
bool demoRichEnabled = Env.demoRich;

class RichStudent {
  const RichStudent(
    this.id,
    this.name,
    this.number,
    this.coachId,
    this.classroomId,
    this.ability,
    this.trend,
    this.activity,
  );

  final String id;
  final String name;
  final String number;
  final String coachId;
  final String classroomId;

  /// Elif'in denemelerine göre başarı oranı.
  final double ability;

  /// Denemeler boyunca değişim; eksi değer net düşüşü demek.
  final double trend;

  /// Çalışma yoğunluğu; 0 ise bu hafta kaydı yok.
  final double activity;
}

const richCoachNames = {
  'demo-coach-3': 'Deniz Aydın',
  'demo-coach-4': 'Okan Çelik',
};

/// Zeynep küçük demoda sınıfsız ve denemesizdir; kalabalık demoda doldurulur.
const richZeynep = RichStudent(
  'demo-zeynep',
  'Zeynep Arslan',
  '1077',
  'demo-coach-2',
  'c-ea',
  0.92,
  -0.2,
  0.8,
);

const richStudents = [
  RichStudent(
    'demo-ali',
    'Ali Demir',
    '1003',
    'demo-coach',
    'c-say',
    0.96,
    0.08,
    0.9,
  ),
  RichStudent(
    'demo-ece',
    'Ece Tan',
    '1008',
    'demo-coach',
    'c-ea',
    0.82,
    0.12,
    0.8,
  ),
  RichStudent(
    'demo-berk',
    'Berk Şahin',
    '1011',
    'demo-coach',
    'c-say',
    0.74,
    0.22,
    0.7,
  ),
  RichStudent(
    'demo-defne',
    'Defne Aksoy',
    '1015',
    'demo-coach',
    'c-say',
    1.04,
    0.04,
    1,
  ),
  RichStudent(
    'demo-kerem',
    'Kerem Polat',
    '1019',
    'demo-coach',
    'c-ea',
    0.8,
    -0.24,
    0.4,
  ),
  RichStudent(
    'demo-nisa',
    'Nisa Erdem',
    '1021',
    'demo-coach',
    'c-soz',
    0.62,
    0.02,
    0,
  ),
  RichStudent(
    'demo-mert',
    'Mert Aydın',
    '1024',
    'demo-coach-2',
    'c-say',
    0.7,
    0.1,
    0.6,
  ),
  RichStudent(
    'demo-selin',
    'Selin Koç',
    '1027',
    'demo-coach-2',
    'c-soz',
    0.76,
    0.16,
    0.8,
  ),
  RichStudent(
    'demo-emre',
    'Emre Yıldırım',
    '1030',
    'demo-coach-2',
    'c-say',
    0.88,
    0.14,
    0.9,
  ),
  RichStudent(
    'demo-zehra',
    'Zehra Öztürk',
    '1034',
    'demo-coach-2',
    'c-ea',
    0.98,
    0.06,
    1.1,
  ),
  RichStudent(
    'demo-yusuf',
    'Yusuf Güneş',
    '1037',
    'demo-coach-2',
    'c-soz',
    0.58,
    0.18,
    0.5,
  ),
  RichStudent(
    'demo-ceren',
    'Ceren Aslan',
    '1041',
    'demo-coach-2',
    'c-say',
    0.86,
    -0.22,
    0.5,
  ),
  RichStudent(
    'demo-ahmet',
    'Ahmet Tekin',
    '1045',
    'demo-coach-3',
    'c-say',
    0.66,
    0.2,
    0.7,
  ),
  RichStudent(
    'demo-irem',
    'İrem Kurt',
    '1048',
    'demo-coach-3',
    'c-ea',
    0.9,
    0.1,
    0.9,
  ),
  RichStudent(
    'demo-baran',
    'Baran Özkan',
    '1052',
    'demo-coach-3',
    'c-soz',
    0.72,
    0.06,
    0.6,
  ),
  RichStudent(
    'demo-melis',
    'Melis Çetin',
    '1056',
    'demo-coach-3',
    'c-ea',
    0.84,
    0.14,
    0.8,
  ),
  RichStudent(
    'demo-omer',
    'Ömer Doğan',
    '1059',
    'demo-coach-3',
    'c-say',
    1,
    0.05,
    1,
  ),
  RichStudent(
    'demo-sude',
    'Sude Karaca',
    '1063',
    'demo-coach-4',
    'c-ea',
    0.78,
    0.12,
    0.7,
  ),
  RichStudent(
    'demo-arda',
    'Arda Bulut',
    '1066',
    'demo-coach-4',
    'c-say',
    0.6,
    -0.04,
    0,
  ),
  RichStudent(
    'demo-aylin',
    'Aylin Korkmaz',
    '1070',
    'demo-coach-4',
    'c-soz',
    0.8,
    0.08,
    0.8,
  ),
  RichStudent(
    'demo-eren',
    'Eren Acar',
    '1074',
    'demo-coach-4',
    'c-say',
    0.94,
    0.1,
    0.9,
  ),
];

/// Uydurma veli adı ve telefonu; her yedinci öğrencinin telefonu yok.
(String, String)? richGuardian(int index, RichStudent s) {
  if (index % 7 == 6) return null;
  const first = [
    'Fatma',
    'Hasan',
    'Ayten',
    'Mustafa',
    'Sevgi',
    'İbrahim',
    'Gül',
  ];
  final surname = s.name.split(' ').last;
  final phone = (index + 1).toString().padLeft(4, '0');
  return ('${first[index % first.length]} $surname', '+90555000$phone');
}

/// Öğrencinin denemeleri: Elif'in denemelerinden oranla türetilir. Sayısal
/// sınıfı dışındakilere AYT Sayısal denemesi verilmez.
List<Exam> richExamsOf(RichStudent s, List<Exam> base) {
  final tyt = [
    for (final e in base)
      if (e.examType == ExamType.tyt) e,
  ];
  final ayt = [
    for (final e in base)
      if (e.examType == ExamType.ayt && s.classroomId == 'c-say') e,
  ];
  Exam scaled(Exam e, double factor) => Exam(
    id: '${s.id}-${e.id}',
    examType: e.examType,
    field: e.field,
    name: e.name,
    publisher: e.publisher,
    takenOn: e.takenOn,
    results: [
      for (final r in e.results)
        () {
          final total = r.correct + r.wrong + r.blank;
          final correct = (r.correct * factor).round().clamp(0, total);
          final wrong = math.min(
            r.wrong + (factor < 0.8 ? 2 : 0),
            total - correct,
          );
          return SubjectResult(
            code: r.code,
            correct: correct,
            wrong: wrong,
            blank: total - correct - wrong,
          );
        }(),
    ],
  );
  List<Exam> series(List<Exam> list) => [
    for (final (i, e) in list.indexed)
      scaled(
        e,
        s.ability +
            s.trend * (list.length < 2 ? 0 : i / (list.length - 1) - 0.5) -
            // Düşüşteki öğrencinin son denemesi kokpitte net düşüşü olarak görünür.
            (s.trend < 0 && i == list.length - 1 ? 0.12 : 0),
      ),
  ];
  return [...series(tyt), ...series(ayt)];
}

/// Müdür kokpiti, öteki ekranlardaki gerçek demo verisinden hesaplanır; böylece
/// karttaki sayı ile açılan ekrandaki sayı aynı olur.
CockpitData richCockpitData({
  required List<StudentSummary> students,
  required List<Exam> Function(String studentId) examsOf,
  required List<StudentFee> fees,
  required Map<String, String> coachNames,
  required List<ExamPlan> examPlans,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final today = DateTime(t.year, t.month, t.day);
  final byId = {for (final s in students) s.id: s};
  final idle = [
    for (final s in students)
      if (s.weekQuestions == 0 && s.weekMinutes == 0) s,
  ];
  final active = students.length - idle.length;
  final questions = students.fold(0, (a, s) => a + s.weekQuestions);
  final minutes = students.fold(0, (a, s) => a + s.weekMinutes);

  final drops = <NetDropStudent>[];
  for (final s in students) {
    final tyt = [
      for (final e in examsOf(s.id))
        if (e.examType == ExamType.tyt && e.results.length > 2) e,
    ]..sort((a, b) => Exam.byDate(b, a));
    if (tyt.length < 2 || tyt[1].totalNet - tyt[0].totalNet < 1) continue;
    drops.add(
      NetDropStudent(
        studentId: s.id,
        name: s.fullName,
        coachId: s.coachId,
        coachName: s.coachName,
        examType: ExamType.tyt,
        lastNet: tyt[0].totalNet,
        prevNet: tyt[1].totalNet,
      ),
    );
  }
  drops.sort(
    (a, b) => (b.prevNet - b.lastNet).compareTo(a.prevNet - a.lastNet),
  );

  final overdue = <OverdueStudent>[];
  for (final f in fees) {
    final late = f.overdue(today);
    final s = byId[f.studentId];
    if (late.isEmpty || s == null) continue;
    overdue.add(
      OverdueStudent(
        studentId: s.id,
        name: s.fullName,
        coachId: s.coachId,
        coachName: s.coachName,
        count: late.length,
        amount: late.fold(0.0, (a, i) => a + i.open),
        oldestDue: late
            .map((i) => i.dueOn)
            .reduce((a, b) => a.isBefore(b) ? a : b),
      ),
    );
  }
  overdue.sort((a, b) => b.amount.compareTo(a.amount));

  return CockpitData(
    students: students.length,
    studentsPrev: students.length - 1,
    active: active,
    activePrev: math.max(active - 1, 0),
    questions: questions,
    questionsPrev: (questions * 0.93).round(),
    minutes: minutes,
    minutesPrev: (minutes * 0.96).round(),
    examPlans: examPlans,
    inactive: [
      for (final (i, s) in idle.indexed)
        InactiveStudent(
          studentId: s.id,
          name: s.fullName,
          coachId: s.coachId,
          coachName: s.coachName,
          seenAt: today.subtract(Duration(days: 8 + i * 3)),
        ),
    ],
    netDrops: drops,
    overdue: overdue,
    coaches: [
      for (final (i, e) in coachNames.entries.indexed)
        () {
          final mine = students.where((s) => s.coachId == e.key).toList();
          final planned = mine.length * 2;
          return CoachStat(
            coachId: e.key,
            name: e.value,
            phone: '+9055510000${i + 1}',
            students: mine.length,
            active: mine
                .where((s) => s.weekQuestions > 0 || s.weekMinutes > 0)
                .length,
            meetingsPlanned: planned,
            meetingsHeld: planned - 1 - i % 2,
          );
        }(),
    ],
  );
}

/// Son 8 hafta (en eskisi önce); son hafta kokpitteki sayılarla aynı.
List<ActivityWeek> richActivityWeeks({
  required int students,
  required int active,
  required int questions,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final today = DateTime(t.year, t.month, t.day);
  const growth = [0.58, 0.66, 0.71, 0.8, 0.77, 0.88, 0.93, 1.0];
  return [
    for (var i = 0; i < growth.length; i++)
      ActivityWeek(
        start: today.subtract(Duration(days: 7 * (8 - i) - 1)),
        end: today.subtract(Duration(days: 7 * (7 - i))),
        students: students - (7 - i) ~/ 3,
        active: (active * (0.7 + 0.3 * growth[i])).round(),
        questions: (questions * growth[i]).round(),
      ),
  ];
}

/// Daha önce gönderilmiş toplu SMS'ler (geçmiş ekranı boş görünmesin).
List<SmsBroadcast> richSmsHistory({DateTime? now}) {
  final t = now ?? DateTime.now();
  SmsBroadcast sms(int id, int daysAgo, String body, int recipients) =>
      SmsBroadcast(
        id: 'rich-sms-$id',
        body: body,
        audience: SmsAudience.all,
        recipients: recipients,
        createdAt: t.subtract(Duration(days: daysAgo, hours: 3)),
        sender: 'Mehmet Demir',
        sent: recipients,
      );
  return [
    sms(
      1,
      2,
      'Cumartesi 10.00\'da TYT denemesi var. Öğrencimizin 09.45\'te kurumda olmasını rica ederiz.',
      19,
    ),
    sms(
      2,
      9,
      'Veli toplantımız perşembe 18.30\'da yapılacaktır. Katılımınızı bekleriz.',
      19,
    ),
    sms(
      3,
      21,
      'Kasım ayı deneme takvimi öğrencilerimize uygulamadan iletilmiştir.',
      18,
    ),
  ];
}
