import 'package:flutter/material.dart';

import '../../../core/i18n/i18n.dart';
import '../data/timetable_repository.dart';
import '../domain/constraints.dart';
import '../domain/models.dart';

String dayShort(int d) => switch (d) {
  1 => tr('Pzt'),
  2 => tr('Sal'),
  3 => tr('Çar'),
  4 => tr('Per'),
  5 => tr('Cum'),
  6 => tr('Cmt'),
  _ => tr('Paz'),
};

String dayLong(int d) => switch (d) {
  1 => tr('Pazartesi'),
  2 => tr('Salı'),
  3 => tr('Çarşamba'),
  4 => tr('Perşembe'),
  5 => tr('Cuma'),
  6 => tr('Cumartesi'),
  _ => tr('Pazar'),
};

String slotLabel(TimeSlot s) => '${formatClock(s.start)}–${formatClock(s.end)}';

String levelLabel(String? level) => switch (level) {
  null => tr('Seviye yok'),
  'graduate' => tr('Mezun'),
  _ => tr('{n}. sınıf', {'n': level}),
};

String fieldLabel(String? field) => switch (field) {
  'SAY' => tr('Sayısal'),
  'EA' => tr('Eşit Ağırlık'),
  'SOZ' => tr('Sözel'),
  'DIL' => tr('Dil'),
  _ => tr('Alan yok'),
};

/// Branş renkleri: sabit kategorik palet (marka renginden bağımsız; aynı
/// branş her ekranda ve çıktıda aynı renkte).
const _palette = [
  Color(0xFF4C7BF3),
  Color(0xFFE5674A),
  Color(0xFF2EA37A),
  Color(0xFF9B5DE5),
  Color(0xFFF2A93B),
  Color(0xFF1FA2C2),
  Color(0xFFD64F8C),
  Color(0xFF6E8B3D),
  Color(0xFF8D6E63),
  Color(0xFF5C6BC0),
  Color(0xFFC0A030),
  Color(0xFF00897B),
];

Color branchColor(String branch) {
  final i = commonBranches.indexOf(branch);
  if (i >= 0) return _palette[i % _palette.length];
  var h = 0;
  for (final c in branch.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _palette[h % _palette.length];
}

/// Çakışma raporunun metni (aksiyon alınabilir).
String conflictMessage(Conflict c) {
  final t = c.teacherName ?? '';
  final k = c.classroomName ?? '';
  final b = c.branch ?? '';
  return switch (c.kind) {
    ConflictKind.noTeacherForBranch => tr(
      '{class} sınıfının {branch} dersi için öğretmen yok ({n} saat). Bu branşa giren bir öğretmen ekle.',
      {'class': k, 'branch': b, 'n': c.need},
    ),
    ConflictKind.teacherOverMax => tr(
      '{teacher}: {need} saat ders atanmış ama haftalık en çok {have} saat girebiliyor. Üst sınırı artır ya da dersin bir kısmını başka öğretmene ver.',
      {'teacher': t, 'need': c.need, 'have': c.have},
    ),
    ConflictKind.teacherOverAvailability => tr(
      '{teacher}: müsait {have} saati var ama {need} saat ders atanmış. Müsaitliği genişlet ya da dersin bir kısmını başka öğretmene ver.',
      {'teacher': t, 'need': c.need, 'have': c.have},
    ),
    ConflictKind.classroomOverSlots => tr(
      '{class}: haftada {need} saat ders istiyor ama şablonda {have} ders saati var. Ders saati ekle ya da dersleri azalt.',
      {'class': k, 'need': c.need, 'have': c.have},
    ),
    ConflictKind.lockedOverHours => tr(
      '{class} {branch}: {have} saat kilitli ama haftalık ihtiyaç {need} saat. Fazla kilitleri kaldır.',
      {'class': k, 'branch': b, 'need': c.need, 'have': c.have},
    ),
    ConflictKind.lockedInvalid =>
      t.isEmpty
          ? tr(
              'Silinmiş bir öğretmen, sınıf ya da saate bağlı kilitli ders kaldırıldı.',
            )
          : tr(
              '{class} {branch} ({teacher}) kilitli dersi bir kuralı bozuyor: öğretmen o saatte müsait değil ya da aynı saatte başka dersi var. Kilidi kaldır.',
              {'class': k, 'branch': b, 'teacher': t},
            ),
    ConflictKind.noCommonSlot => tr(
      '{class} {branch}: {need} saat yerleşmedi. {teacher} ile sınıfın ortak boş saati {have}. Öğretmenin müsaitliğini artır ya da kilitli dersleri gözden geçir.',
      {'class': k, 'branch': b, 'teacher': t, 'need': c.need, 'have': c.have},
    ),
  };
}

String hardRuleMessage(HardRule r) => switch (r) {
  HardRule.teacherClash => tr('Öğretmenin o saatte başka dersi var.'),
  HardRule.classClash => tr('Sınıfın o saatte başka dersi var.'),
  HardRule.roomClash => tr('Derslik o saatte dolu.'),
  HardRule.teacherUnavailable => tr('Öğretmen o saatte müsait değil.'),
  HardRule.hoursMismatch => tr('Dersin haftalık saati tutmuyor.'),
  HardRule.lockedMoved => tr('Kilitli ders taşınamaz.'),
  HardRule.teacherOverMax => tr('Öğretmenin haftalık üst sınırı aşılıyor.'),
};

/// Program görünümü: sınıf, öğretmen ya da derslik.
enum TimetableMode { classroom, teacher, room }

/// [mode] görünümünde [targetId] için (gün, sıra) → ders dizinleri.
Map<(int, int), List<int>> cellsFor(
  TimetableSetup setup,
  List<ScheduleEntry> entries,
  TimetableMode mode,
  String targetId,
) {
  final slots = {for (final s in setup.slots) s.id: s};
  final out = <(int, int), List<int>>{};
  for (var i = 0; i < entries.length; i++) {
    final e = entries[i];
    final match = switch (mode) {
      TimetableMode.classroom => e.classroomId == targetId,
      TimetableMode.teacher => e.teacherId == targetId,
      TimetableMode.room => e.roomId == targetId,
    };
    final s = slots[e.timeSlotId];
    if (!match || s == null) continue;
    out.putIfAbsent((s.day, s.seq), () => []).add(i);
  }
  return out;
}

/// Şablondaki günler ve en büyük sıra.
(List<int>, int) gridShape(List<TimeSlot> slots) {
  final days = {for (final s in slots) s.day}.toList()..sort();
  var maxSeq = 0;
  for (final s in slots) {
    if (s.seq > maxSeq) maxSeq = s.seq;
  }
  return (days, maxSeq);
}

/// Bir satırın (sıra) saat etiketi: ilk günün o sıradaki saati.
String rowLabel(List<TimeSlot> slots, int seq) {
  final s = slots.where((x) => x.seq == seq).toList()
    ..sort((a, b) => a.day.compareTo(b.day));
  return s.isEmpty ? '$seq' : formatClock(s.first.start);
}
