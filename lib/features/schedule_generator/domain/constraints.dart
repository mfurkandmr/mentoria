import 'models.dart';

/// Sert kısıtlar (hiçbir programda bozulamaz).
enum HardRule {
  /// 1. Öğretmen aynı saatte iki derste.
  teacherClash,

  /// 2. Sınıf aynı saatte iki derste.
  classClash,

  /// 3. Derslik aynı saatte iki sınıfta.
  roomClash,

  /// 4. Öğretmen o saatte müsait değil.
  teacherUnavailable,

  /// 5. Sınıfın bir dersinin haftalık saati tutmuyor.
  hoursMismatch,

  /// 6. Kilitli ders yerinden oynamış ya da silinmiş.
  lockedMoved,

  /// 7. Öğretmenin haftalık en çok ders saati aşıldı.
  teacherOverMax,
}

class HardViolation {
  const HardViolation(this.rule, this.detail);

  final HardRule rule;
  final String detail;

  @override
  String toString() => '${rule.name}: $detail';
}

/// Programdaki bütün sert kısıt ihlalleri. [requireComplete] false ise
/// eksik saat (5. kural) yalnızca fazlalık için sayılır (kısmi program).
List<HardViolation> validateHard(
  GenerationInput input,
  List<ScheduleEntry> entries, {
  bool requireComplete = true,
}) {
  final out = <HardViolation>[];
  final slots = {for (final s in input.slots) s.id: s};
  final teachers = {for (final t in input.teachers) t.id: t};
  final rooms = {for (final r in input.rooms) r.id: r};
  final seenTeacher = <String>{};
  final seenClass = <String>{};
  final seenRoom = <String>{};
  final load = <String, int>{};
  final hours = <String, int>{};
  for (final e in entries) {
    if (!seenTeacher.add('${e.teacherId}|${e.timeSlotId}')) {
      out.add(HardViolation(HardRule.teacherClash, e.toString()));
    }
    if (!seenClass.add('${e.classroomId}|${e.timeSlotId}')) {
      out.add(HardViolation(HardRule.classClash, e.toString()));
    }
    if (e.roomId != null && !seenRoom.add('${e.roomId}|${e.timeSlotId}')) {
      out.add(HardViolation(HardRule.roomClash, e.toString()));
    }
    final s = slots[e.timeSlotId];
    // Derslikte o saatte soru çözümü / birebir oturumu var.
    final r = rooms[e.roomId];
    if (s != null && r != null && !r.freeAt(s)) {
      out.add(HardViolation(HardRule.roomClash, e.toString()));
    }
    final t = teachers[e.teacherId];
    if (s == null || t == null || !t.freeAt(s)) {
      out.add(HardViolation(HardRule.teacherUnavailable, e.toString()));
    }
    load.update(e.teacherId, (v) => v + 1, ifAbsent: () => 1);
    hours.update(
      '${e.classroomId}|${e.branch}',
      (v) => v + 1,
      ifAbsent: () => 1,
    );
  }
  for (final l in input.lessons) {
    final n = hours.remove('${l.classroomId}|${l.branch}') ?? 0;
    if (n > l.weeklyHours || (requireComplete && n != l.weeklyHours)) {
      out.add(
        HardViolation(
          HardRule.hoursMismatch,
          '${l.classroomId} ${l.branch}: $n/${l.weeklyHours}',
        ),
      );
    }
  }
  for (final k in hours.keys) {
    out.add(HardViolation(HardRule.hoursMismatch, '$k: ihtiyaç yok'));
  }
  for (final t in input.teachers) {
    final n = load[t.id] ?? 0;
    if (n > t.maxWeeklyHours) {
      out.add(
        HardViolation(
          HardRule.teacherOverMax,
          '${t.name}: $n/${t.maxWeeklyHours}',
        ),
      );
    }
  }
  final present = entries
      .map((e) => (e.teacherId, e.classroomId, e.timeSlotId, e.branch))
      .toSet();
  for (final e in input.locked) {
    if (!present.contains((
      e.teacherId,
      e.classroomId,
      e.timeSlotId,
      e.branch,
    ))) {
      out.add(HardViolation(HardRule.lockedMoved, e.toString()));
    }
  }
  return out;
}

/// Elle taşıma: [entries][index] dersi [slotId] saatine giderse hangi
/// sert kurallar bozulur (kendisi hariç). Derslik de o saatte doluysa
/// [HardRule.roomClash].
List<HardRule> moveProblems(
  GenerationInput input,
  List<ScheduleEntry> entries,
  int index,
  String slotId, {
  String? roomId,
}) {
  final e = entries[index];
  final room = roomId ?? e.roomId;
  final problems = <HardRule>{};
  for (var i = 0; i < entries.length; i++) {
    if (i == index) continue;
    final o = entries[i];
    if (o.timeSlotId != slotId) continue;
    if (o.teacherId == e.teacherId) problems.add(HardRule.teacherClash);
    if (o.classroomId == e.classroomId) problems.add(HardRule.classClash);
    if (room != null && o.roomId == room) problems.add(HardRule.roomClash);
  }
  final slot = input.slots.where((s) => s.id == slotId).firstOrNull;
  final r = input.rooms.where((x) => x.id == room).firstOrNull;
  if (slot != null && r != null && !r.freeAt(slot)) {
    problems.add(HardRule.roomClash);
  }
  final teacher = input.teachers.where((t) => t.id == e.teacherId).firstOrNull;
  if (slot == null || teacher == null || !teacher.freeAt(slot)) {
    problems.add(HardRule.teacherUnavailable);
  }
  return problems.toList();
}

/// Yumuşak kısıt ceza puanları (düşük daha iyi). Ağırlıklar:
const gapPenalty = 3; // öğretmenin günündeki her boş saat (pencere)
const stackPenalty = 5; // aynı dersin günlük sınırı aşan her saati
const afternoonPenalty = 2; // sayısal ders 12.00'den sonra
const classSwitchPenalty = 1; // öğretmenin bir gündeki her ek sınıfı

/// 2'li blok (NOTLAR §96): bir sınıfın bir dersi günlere 2 saatlik bloklar
/// hâlinde dağılır (4 → 2+2, 3 → 2+1, 5 → 2+2+1, 6 → 2+2+2). Fazladan her
/// tek saatlik gün ve aynı gündeki iki saatin arasının açılması cezalı.
/// Günde en çok 1 saat seçilmiş derste uygulanmaz.
const splitPenalty = 4;

/// Haftalık saatin günlere planlanan bölünüşü: 5 → [2, 2, 1].
List<int> blockPlan(int weeklyHours) => [
  for (var h = weeklyHours; h > 0; h -= 2) h >= 2 ? 2 : 1,
];

/// Puanı dizinler üzerinden hızlı hesaplar (üretici her adımda çağırır).
class ScoreModel {
  ScoreModel(GenerationInput input)
    : slotIndex = {
        for (var i = 0; i < input.slots.length; i++) input.slots[i].id: i,
      },
      teacherIndex = {
        for (var i = 0; i < input.teachers.length; i++) input.teachers[i].id: i,
      },
      classIndex = {
        for (var i = 0; i < input.classrooms.length; i++)
          input.classrooms[i].id: i,
      },
      _day = [for (final s in input.slots) s.day],
      _afternoon = [for (final s in input.slots) s.start >= 12 * 60],
      _pos = _positions(input.slots),
      _maxPerDay = {
        for (final l in input.lessons)
          '${l.classroomId}|${l.branch}': l.maxPerDay,
      },
      _weekly = {
        for (final l in input.lessons)
          '${l.classroomId}|${l.branch}': l.weeklyHours,
      },
      _classIds = [for (final c in input.classrooms) c.id];

  final Map<String, int> slotIndex;
  final Map<String, int> teacherIndex;
  final Map<String, int> classIndex;
  final List<int> _day;
  final List<bool> _afternoon;

  /// Saatin kendi günündeki sırası (0'dan; şablonda boşluk olsa da ardışık).
  final List<int> _pos;
  final Map<String, int> _maxPerDay;
  final Map<String, int> _weekly;
  final List<String> _classIds;

  int dayOf(int slot) => _day[slot];
  int posOf(int slot) => _pos[slot];

  static List<int> _positions(List<TimeSlot> slots) {
    final byDay = <int, List<int>>{};
    for (var i = 0; i < slots.length; i++) {
      byDay.putIfAbsent(slots[i].day, () => []).add(i);
    }
    final pos = List<int>.filled(slots.length, 0);
    for (final list in byDay.values) {
      list.sort((a, b) => slots[a].seq.compareTo(slots[b].seq));
      for (var k = 0; k < list.length; k++) {
        pos[list[k]] = k;
      }
    }
    return pos;
  }

  int maxPerDay(int classIdx, String branch) =>
      _maxPerDay['${_classIds[classIdx]}|$branch'] ?? 2;

  /// Dizinlerle verilen derslerin puanı.
  int score(
    List<int> teacher,
    List<int> klass,
    List<int> slot,
    List<String> branch,
  ) {
    var total = 0;
    final tDay = <int, List<int>>{};
    final tDayClasses = <int, Set<int>>{};
    final lessonDay = <String, int>{};
    final lessonPos = <String, List<int>>{};
    for (var i = 0; i < slot.length; i++) {
      final s = slot[i];
      final d = _day[s];
      final key = teacher[i] * 8 + d;
      tDay.putIfAbsent(key, () => []).add(_pos[s]);
      tDayClasses.putIfAbsent(key, () => {}).add(klass[i]);
      final lk = '${klass[i]}|${branch[i]}|$d';
      lessonDay[lk] = (lessonDay[lk] ?? 0) + 1;
      lessonPos.putIfAbsent(lk, () => []).add(_pos[s]);
      if (_afternoon[s] && numericBranches.contains(branch[i])) {
        total += afternoonPenalty;
      }
    }
    for (final p in tDay.values) {
      var lo = p.first, hi = p.first;
      for (final x in p) {
        if (x < lo) lo = x;
        if (x > hi) hi = x;
      }
      final gaps = hi - lo + 1 - p.length;
      if (gaps > 0) total += gaps * gapPenalty;
    }
    for (final c in tDayClasses.values) {
      total += (c.length - 1) * classSwitchPenalty;
    }
    final singles = <String, int>{};
    for (final e in lessonDay.entries) {
      final parts = e.key.split('|');
      final max = maxPerDay(int.parse(parts[0]), parts[1]);
      if (e.value > max) total += (e.value - max) * stackPenalty;
      if (max < 2) continue;
      final lesson = '${parts[0]}|${parts[1]}';
      if (e.value == 1) {
        singles[lesson] = (singles[lesson] ?? 0) + 1;
      } else {
        // Aynı gündeki saatler bitişik olsun (blok).
        final p = lessonPos[e.key]!;
        var lo = p.first, hi = p.first;
        for (final x in p) {
          if (x < lo) lo = x;
          if (x > hi) hi = x;
        }
        total += (hi - lo + 1 - p.length) * splitPenalty;
      }
    }
    for (final e in singles.entries) {
      final parts = e.key.split('|');
      final weekly = _weekly['${_classIds[int.parse(parts[0])]}|${parts[1]}'];
      final allowed = (weekly ?? 1).isOdd ? 1 : 0;
      if (e.value > allowed) total += (e.value - allowed) * splitPenalty;
    }
    return total;
  }
}

/// Programın yumuşak kısıt ceza puanı (0 en iyisi).
int softScore(GenerationInput input, List<ScheduleEntry> entries) {
  final m = ScoreModel(input);
  final t = <int>[], c = <int>[], s = <int>[], b = <String>[];
  for (final e in entries) {
    final ti = m.teacherIndex[e.teacherId];
    final ci = m.classIndex[e.classroomId];
    final si = m.slotIndex[e.timeSlotId];
    if (ti == null || ci == null || si == null) continue;
    t.add(ti);
    c.add(ci);
    s.add(si);
    b.add(e.branch);
  }
  return m.score(t, c, s, b);
}
