import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../../auth/data/auth_repository.dart';
import '../../schedule_generator/data/timetable_repository.dart';
import '../../schedule_generator/domain/models.dart';

/// Öğrencinin ders programı: sınıfı ve yayındaki programdan sınıfının
/// dersleri. Son başarılı yükleme cihazda saklanır; çevrimdışıyken o
/// gösterilir ([fromCache]).
class StudentScheduleView {
  const StudentScheduleView({
    required this.className,
    required this.items,
    this.fromCache = false,
    this.savedAt,
  });

  /// Sınıfı yoksa null ("Henüz bir sınıfa atanmadın").
  final String? className;
  final List<TimetableItem> items;
  final bool fromCache;
  final DateTime? savedAt;

  bool get hasClass => className != null;

  /// Sınıfı var ama yayında program yok.
  bool get notPublished => hasClass && items.isEmpty;

  String? get scheduleName => items.firstOrNull?.scheduleName;

  /// [weekday] gününün dersleri (sırayla).
  List<TimetableItem> day(int weekday) => [
    for (final i in items)
      if (i.day == weekday) i,
  ]..sort((a, b) => a.seq.compareTo(b.seq));

  Map<String, dynamic> toJson() => {
    'class': className,
    'saved_at': (savedAt ?? DateTime.now()).toIso8601String(),
    'items': [
      for (final i in items)
        {
          'schedule_name': i.scheduleName,
          'day': i.day,
          'seq': i.seq,
          'start_time': formatClock(i.start),
          'end_time': formatClock(i.end),
          'branch': i.branch,
          'classroom_name': i.classroomName,
          'teacher_name': i.teacherName,
          'room_name': i.roomName,
        },
    ],
  };

  factory StudentScheduleView.fromJson(Map<String, dynamic> j) =>
      StudentScheduleView(
        className: j['class'] as String?,
        items: [
          for (final r in j['items'] as List)
            TimetableItem.fromJson(Map<String, dynamic>.from(r as Map)),
        ],
        fromCache: true,
        savedAt: DateTime.tryParse(j['saved_at'] as String? ?? ''),
      );
}

/// Şu an süren ders (yoksa null) ve sıradaki ders.
(TimetableItem?, TimetableItem?) currentAndNext(
  List<TimetableItem> today,
  DateTime now,
) {
  final m = now.hour * 60 + now.minute;
  TimetableItem? current, next;
  for (final i in today) {
    if (i.start <= m && m < i.end) current = i;
    if (i.start > m && (next == null || i.start < next.start)) next = i;
  }
  return (current, next);
}

String _cacheKey(String userId) => 'student_schedule_$userId';

final studentScheduleProvider = FutureProvider<StudentScheduleView>((
  ref,
) async {
  final repo = ref.watch(timetableRepositoryProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final userId = (await ref.watch(currentProfileProvider.future))?.id ?? '';
  try {
    final results = await Future.wait([repo.myClassroom(), repo.myTimetable()]);
    final klass = results[0] as (String, String)?;
    final items = results[1] as List<TimetableItem>;
    final view = StudentScheduleView(
      className: klass?.$2,
      items: [
        for (final i in items)
          if (i.studentId == null || i.studentId == userId) i,
      ],
    );
    await prefs?.setString(_cacheKey(userId), jsonEncode(view.toJson()));
    return view;
  } catch (e) {
    final raw = prefs?.getString(_cacheKey(userId));
    if (raw == null) rethrow;
    return StudentScheduleView.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }
});
