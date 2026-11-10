import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/tool_tile.dart';
import '../data/books_repository.dart';

/// Müdür ve koç: kitap raporu kısayolu.
ToolInfo bookReportTool(String basePath) => ToolInfo(
  id: 'tool-book-report',
  icon: Icons.menu_book_outlined,
  title: tr('Kitap raporu'),
  status: tr('Hangi öğrenci hangi kitaptan kaç soru çözdü'),
  open: (c) => c.push('$basePath/book-report'),
);

String _subjectName(String? code) =>
    code == null ? tr('Karma') : subjectByCode(code).name;

/// Hangi öğrenci hangi kitaptan kaç soru çözdü. Sayılar öğrencinin Kitaplarım'a
/// girdiği çalışmalardan gelir; müdür kurumu, koç kendi öğrencilerini görür.
class BookReportScreen extends ConsumerStatefulWidget {
  const BookReportScreen({super.key});

  @override
  ConsumerState<BookReportScreen> createState() => _BookReportScreenState();
}

class _BookReportScreenState extends ConsumerState<BookReportScreen> {
  bool _byBook = false;
  String _query = '';
  String? _classroom;

  /// Ders kodu; [_allSubjects] ise süzgeç yok, null karma kitaplar.
  static const _allSubjects = '*';
  String? _subject = _allSubjects;

  bool _matches(BookReportRow r) {
    final q = _query.toLowerCase();
    if (q.isNotEmpty &&
        !r.studentName.toLowerCase().contains(q) &&
        !r.bookName.toLowerCase().contains(q) &&
        !r.publisher.toLowerCase().contains(q) &&
        !(r.studentNumber?.toLowerCase().contains(q) ?? false)) {
      return false;
    }
    if (_classroom != null && r.classroomId != _classroom) return false;
    return _subject == _allSubjects || r.subjectCode == _subject;
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(bookReportProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Kitap raporu'))),
      body: AsyncView(
        value: report,
        onRetry: () => ref.invalidate(bookReportProvider),
        builder: (all) {
          final rows = all.where(_matches).toList();
          final total = rows.fold(0, (s, r) => s + r.questions);
          final students = rows
              .where((r) => r.questions > 0)
              .map((r) => r.studentId)
              .toSet()
              .length;
          final classes = <String, String>{
            for (final r in all)
              if (r.classroomId != null) r.classroomId!: r.classroomName ?? '',
          };
          final subjects = {for (final r in all) r.subjectCode};
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              StatRow(
                children: [
                  StatTile(
                    icon: Icons.quiz_outlined,
                    label: tr('Çözülen soru'),
                    value: '$total',
                  ),
                  StatTile(
                    icon: Icons.groups_outlined,
                    label: tr('Kitaptan çözen öğrenci'),
                    value: '$students',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(tr('Öğrenciye göre')),
                  ),
                  ButtonSegment(value: true, label: Text(tr('Kitaba göre'))),
                ],
                selected: {_byBook},
                onSelectionChanged: (v) => setState(() => _byBook = v.first),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('book-report-search'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: tr('Öğrenci, numara ya da kitap ara'),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _subject,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: tr('Ders')),
                      items: [
                        DropdownMenuItem(
                          value: _allSubjects,
                          child: Text(tr('Hepsi')),
                        ),
                        for (final c in subjects)
                          DropdownMenuItem(
                            value: c,
                            child: Text(_subjectName(c)),
                          ),
                      ],
                      onChanged: (v) => setState(() => _subject = v),
                    ),
                  ),
                  if (classes.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _classroom,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: tr('Sınıf')),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(tr('Hepsi')),
                          ),
                          for (final e in classes.entries)
                            DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                        ],
                        onChanged: (v) => setState(() => _classroom = v),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    all.isEmpty
                        ? tr(
                            'Bu dönem öğrenci kitabı yok. Öğrenciler Kitaplarım ekranından kitap seçip çözdüğü soruyu girince burada görünür.',
                          )
                        : tr('Bu süzgeçle kayıt yok.'),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (_byBook)
                ..._groupedByBook(rows)
              else
                ..._groupedByStudent(rows),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _groupedByStudent(List<BookReportRow> rows) {
    final groups = <String, List<BookReportRow>>{};
    for (final r in rows) {
      groups.putIfAbsent(r.studentId, () => []).add(r);
    }
    final ordered = groups.values.toList()
      ..sort((a, b) => _sum(b).compareTo(_sum(a)));
    return [
      for (final g in ordered)
        _Group(
          key: ValueKey('book-report-student-${g.first.studentId}'),
          title: g.first.studentName,
          subtitle: [
            ?g.first.classroomName,
            tr('{n} kitap', {'n': g.length}),
          ].join(' · '),
          total: _sum(g),
          rows: [
            for (final r in g..sort((a, b) => b.questions - a.questions))
              _Row(title: r.bookName, caption: _bookCaption(r), row: r),
          ],
        ),
    ];
  }

  List<Widget> _groupedByBook(List<BookReportRow> rows) {
    final groups = <String, List<BookReportRow>>{};
    for (final r in rows) {
      groups.putIfAbsent(r.bookId, () => []).add(r);
    }
    final ordered = groups.values.toList()
      ..sort((a, b) => _sum(b).compareTo(_sum(a)));
    return [
      for (final g in ordered)
        _Group(
          key: ValueKey('book-report-book-${g.first.bookId}'),
          title: g.first.bookName,
          subtitle: [
            g.first.publisher,
            _subjectName(g.first.subjectCode),
            tr('{n} öğrenci', {'n': g.length}),
          ].join(' · '),
          total: _sum(g),
          rows: [
            for (final r in g..sort((a, b) => b.questions - a.questions))
              _Row(title: r.studentName, caption: _dates(r), row: r),
          ],
        ),
    ];
  }

  static int _sum(List<BookReportRow> g) =>
      g.fold(0, (s, r) => s + r.questions);

  static String _bookCaption(BookReportRow r) => [
    r.publisher,
    _subjectName(r.subjectCode),
    if (_dates(r).isNotEmpty) _dates(r),
  ].join(' · ');

  static String _dates(BookReportRow r) => r.lastStudied == null
      ? ''
      : tr('son çalışma {d}', {'d': formatShortDate(r.lastStudied!)});
}

class _Group extends StatelessWidget {
  const _Group({
    super.key,
    required this.title,
    required this.subtitle,
    required this.total,
    required this.rows,
  });

  final String title;
  final String subtitle;
  final int total;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: Text(
        tr('{n} soru', {'n': total}),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.caption, required this.row});

  final String title;
  final String caption;
  final BookReportRow row;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.bodyMedium),
                if (caption.isNotEmpty) Text(caption, style: text.bodySmall),
                if (row.questions > 0)
                  Text(
                    tr('{c} doğru · {w} yanlış · {b} boş', {
                      'c': row.correct,
                      'w': row.wrong,
                      'b': row.blank,
                    }),
                    style: text.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            tr('{n} soru', {'n': row.questions}),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
