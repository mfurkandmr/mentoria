import 'dart:convert';

import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/dev/demo_timetable.dart';
import 'package:mentoria/features/schedule_generator/presentation/schedule_export.dart';
import 'package:mentoria/features/schedule_generator/presentation/timetable_format.dart';

void main() {
  testWidgets('Excel: sınıf başına sayfa, PDF: sınıf başına sayfa', (t) async {
    final repo = InMemoryTimetableRepository.demo();
    final setup = await repo.fetchSetup();
    final entries = await repo.fetchEntries('sch-demo');

    final book = xl.Excel.decodeBytes(
      buildScheduleWorkbook(setup, entries, TimetableMode.classroom),
    );
    expect(
      book.tables.keys,
      containsAll(['Sayısal-1', 'Eşit Ağırlık-1', 'Sözel-1']),
    );
    final sheet = book.tables['Sayısal-1']!;
    expect(sheet.rows.first[1]?.value.toString(), 'Pazartesi');
    expect(sheet.maxRows, 1 + 6);
    final texts = [
      for (final r in sheet.rows.skip(1))
        for (final c in r.skip(1)) c?.value.toString() ?? '',
    ].where((s) => s.isNotEmpty);
    expect(texts.length, entries.where((e) => e.classroomId == 'c-say').length);

    final teacherBook = xl.Excel.decodeBytes(
      buildScheduleWorkbook(setup, entries, TimetableMode.teacher),
    );
    expect(teacherBook.tables.keys, contains('Ahmet Kaya'));

    final pdf = await t.runAsync(
      () => renderSchedulePdf(
        setup,
        entries,
        TimetableMode.classroom,
        title: 'Güz dönemi',
      ),
    );
    final head = latin1.decode(pdf!.sublist(0, 8));
    expect(head, startsWith('%PDF-1.4'));
    expect(latin1.decode(pdf, allowInvalid: true), contains('/Count 3'));
  });
}
