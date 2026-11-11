import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/constants/grade_levels.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../tracking/data/tracking_models.dart';
import '../../tracking/data/tracking_repository.dart';
import '../data/books_repository.dart';
import 'books_screens.dart' show BooksViewer;

/// Kaynak takibi (NOTLAR §92): ders başına bir tablo; satırlar konular,
/// sütunlar öğrencinin o dersteki kitapları. Kutuya dokununca "bu kitaptan
/// bu konu bitti" işaretlenir. Veli yalnızca görür.
class ResourceTrackingScreen extends ConsumerStatefulWidget {
  const ResourceTrackingScreen({
    super.key,
    required this.studentId,
    required this.viewer,
    this.term,
  });

  final String studentId;
  final BooksViewer viewer;
  final String? term;

  @override
  ConsumerState<ResourceTrackingScreen> createState() =>
      _ResourceTrackingScreenState();
}

class _ResourceTrackingScreenState
    extends ConsumerState<ResourceTrackingScreen> {
  ExamType _type = ExamType.tyt;

  /// Sunucu yanıtı gelene kadar ekranda gösterilen değişiklikler.
  final _pending = <(String, int), bool>{};

  bool get _canEdit => widget.viewer != BooksViewer.parent;

  Future<void> _toggle(String studentBookId, int topicId, bool done) async {
    final key = (studentBookId, topicId);
    setState(() => _pending[key] = done);
    try {
      await ref
          .read(booksRepositoryProvider)
          .setTopicMark(studentBookId, topicId, done);
      ref.invalidate(bookTopicMarksProvider(widget.studentId));
      await ref.read(bookTopicMarksProvider(widget.studentId).future);
    } catch (_) {
      if (mounted) showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    } finally {
      if (mounted) setState(() => _pending.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(
      booksOverviewProvider((widget.studentId, widget.term)),
    );
    final topics = ref.watch(topicsProvider);
    final marks = ref.watch(bookTopicMarksProvider(widget.studentId));
    final grade = effectiveGrade(
      ref.watch(studentGradeProvider(widget.studentId)).value,
    );
    final school = grade < 12;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Kaynak takibi'))),
      body: AsyncView(
        value: overview,
        onRetry: () => ref.invalidate(booksOverviewProvider),
        builder: (o) => AsyncView(
          value: topics,
          onRetry: () => ref.invalidate(topicsProvider),
          builder: (all) => AsyncView(
            value: marks,
            onRetry: () =>
                ref.invalidate(bookTopicMarksProvider(widget.studentId)),
            builder: (saved) {
              // Bırakılan kitaplar tabloda yer almaz.
              final books = [
                for (final b in o.books)
                  if (b.status != StudentBookStatus.dropped) b,
              ];
              final visible = topicsForGrade(all, grade);
              final subjects = [
                for (final s in examSubjects)
                  if ((school || s.examType == _type) &&
                      visible.any((t) => t.subjectCode == s.code) &&
                      books.any(
                        (b) =>
                            b.book.subjectCode == null ||
                            b.book.subjectCode == s.code,
                      ))
                    s,
              ];
              bool done(String sb, int topic) =>
                  _pending[(sb, topic)] ?? saved.contains((sb, topic));

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  if (!school)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SegmentedButton<ExamType>(
                        showSelectedIcon: false,
                        segments: [
                          for (final t in ExamType.values)
                            ButtonSegment(value: t, label: Text(t.label)),
                        ],
                        selected: {_type},
                        onSelectionChanged: (s) =>
                            setState(() => _type = s.first),
                      ),
                    ),
                  if (subjects.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyState(
                        title: tr('Bu bölümde kitabın yok'),
                        message: tr(
                          'Kitap eklediğinde konuları burada kitap kitap işaretleyebilirsin.',
                        ),
                      ),
                    ),
                  for (final s in subjects)
                    _SubjectTable(
                      title: school ? s.name : '${s.examType.label} ${s.name}',
                      topics: [
                        for (final t in visible)
                          if (t.subjectCode == s.code) t,
                      ]..sort((a, b) => a.sort.compareTo(b.sort)),
                      books: [
                        for (final b in books)
                          if (b.book.subjectCode == null ||
                              b.book.subjectCode == s.code)
                            b,
                      ],
                      isDone: done,
                      onToggle: _canEdit ? _toggle : null,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SubjectTable extends StatelessWidget {
  const _SubjectTable({
    required this.title,
    required this.topics,
    required this.books,
    required this.isDone,
    required this.onToggle,
  });

  final String title;
  final List<Topic> topics;
  final List<StudentBook> books;
  final bool Function(String studentBookId, int topicId) isDone;
  final Future<void> Function(String studentBookId, int topicId, bool done)?
  onToggle;

  static const _bookWidth = 92.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final line = BorderSide(color: scheme.outlineVariant);
    final total = topics.length * books.length;
    final finished = [
      for (final t in topics)
        for (final b in books)
          if (isDone(b.id, t.id)) 1,
    ].length;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.brand.primary,
                    ),
                  ),
                ),
                Text('$finished / $total', style: text.labelMedium),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, box) {
                // Konu sütunu kalan yeri alır; kitap çoksa tablo yana kayar.
                final topicWidth = (box.maxWidth - books.length * _bookWidth)
                    .clamp(150.0, double.infinity);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    border: TableBorder(
                      horizontalInside: line,
                      verticalInside: line,
                      bottom: line,
                    ),
                    columnWidths: {
                      0: FixedColumnWidth(topicWidth),
                      for (var i = 0; i < books.length; i++)
                        i + 1: const FixedColumnWidth(_bookWidth),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(tr('Konu'), style: text.labelLarge),
                          ),
                          for (final b in books)
                            Tooltip(
                              message: '${b.book.name} · ${b.book.publisher}',
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  b.book.name,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: text.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      for (final t in topics)
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Text(t.name, style: text.bodyMedium),
                            ),
                            for (final b in books)
                              Checkbox(
                                key: ValueKey('mark-${b.id}-${t.id}'),
                                value: isDone(b.id, t.id),
                                semanticLabel: '${t.name} · ${b.book.name}',
                                onChanged: onToggle == null
                                    ? null
                                    : (v) => onToggle!(b.id, t.id, v ?? false),
                              ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
