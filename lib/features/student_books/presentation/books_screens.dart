import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/data/auth_repository.dart';
import '../../tracking/data/tracking_models.dart';
import '../../tracking/data/tracking_repository.dart';
import '../data/books_repository.dart';
import '../../../core/design/motion.dart';

final _inline = FilledButton.styleFrom(minimumSize: const Size(0, 44));

String _date(DateTime d) => DateFormat('d MMM yyyy', localeTag).format(d);

/// Kim bakıyor: öğrenci (kendi), koç/müdür (yönetir), veli (salt okunur).
enum BooksViewer { student, manager, parent }

void _toast(BuildContext context, String m) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m)));

String _errorText(Object e) => e is BookLimitException
    ? tr(
        'Bu dönem için kitap hakkı doldu. Yeni kitap eklemek için koçuna haber ver.',
      )
    : e is BookExistsException
    ? tr('Bu kitap havuzda zaten var; listeden seç.')
    : '$e'.contains('BOOK_NOT_IN_POOL')
    ? tr('Bu kitap havuzda değil.')
    : tr('Kaydedilemedi. Tekrar dene.');

void _refresh(WidgetRef ref, String studentId) {
  ref.invalidate(booksOverviewProvider);
  ref.invalidate(bookProgressProvider);
  ref.invalidate(bookPoolProvider);
  ref.invalidate(bookUsageProvider);
  ref.invalidate(topicGapsProvider(studentId));
}

/// Öğrenci: Eğitim → Kitaplarım (/student/books).
class MyBooksScreen extends ConsumerWidget {
  const MyBooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentProfileProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Kitaplarım'))),
      body: me == null
          ? const Center(child: CircularProgressIndicator())
          : StudentBooksView(studentId: me.id, viewer: BooksViewer.student),
    );
  }
}

/// Öğrencinin kitapları ve dönem hakkı. Koç/müdür sekmesinde, velide ve
/// öğrencide ortak.
class StudentBooksView extends ConsumerStatefulWidget {
  const StudentBooksView({
    super.key,
    required this.studentId,
    required this.viewer,
  });

  final String studentId;
  final BooksViewer viewer;

  @override
  ConsumerState<StudentBooksView> createState() => _StudentBooksViewState();
}

class _StudentBooksViewState extends ConsumerState<StudentBooksView> {
  String? _term;

  bool get _manager => widget.viewer == BooksViewer.manager;

  Future<void> _add(BooksOverview o) async {
    if (o.full) {
      _toast(
        context,
        _manager
            ? tr('Öğrencinin bu dönemki kitap hakkı doldu. Önce limiti artır.')
            : tr(
                'Bu dönem için {n} kitap hakkını kullandın. Yeni kitap eklemek için koçuna haber ver.',
                {'n': o.limit},
              ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookPickerScreen(
          studentId: widget.studentId,
          viewer: widget.viewer,
          overview: o,
        ),
      ),
    );
    if (mounted) _refresh(ref, widget.studentId);
  }

  Future<void> _raiseLimit(BooksOverview o) async {
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (_) => _LimitDialog(current: o.limit, used: o.used),
    );
    if (result == null || !mounted) return;
    try {
      await ref
          .read(booksRepositoryProvider)
          .setLimit(widget.studentId, result.$1, result.$2);
      _refresh(ref, widget.studentId);
      if (mounted) {
        _toast(context, tr('Kitap hakkı {n} oldu.', {'n': result.$1}));
      }
    } catch (e) {
      if (mounted) _toast(context, _errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(
      booksOverviewProvider((widget.studentId, _term)),
    );
    final text = Theme.of(context).textTheme;
    return AsyncView(
      value: overview,
      onRetry: () => ref.invalidate(booksOverviewProvider),
      builder: (o) {
        final canAdd = o.isCurrent && widget.viewer != BooksViewer.parent;
        return RefreshIndicator(
          onRefresh: () async => _refresh(ref, widget.studentId),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              if (_manager) TopicGapsCard(studentId: widget.studentId),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tr('{u} / {l} kitap kullanıldı', {
                                'u': o.used,
                                'l': o.limit,
                              }),
                              key: const ValueKey('book-quota'),
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (o.terms.length > 1 || !o.isCurrent)
                            DropdownButton<String>(
                              value: o.term,
                              items: [
                                for (final t in {...o.terms, o.currentTerm})
                                  DropdownMenuItem(value: t, child: Text(t)),
                              ],
                              onChanged: (v) => setState(() => _term = v),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: o.limit == 0
                            ? 0
                            : (o.used / o.limit).clamp(0, 1),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr(
                          '{term} dönemi. Bitirilen ya da bırakılan kitaplar da hakka sayılır.',
                          {'term': o.term},
                        ),
                        style: text.bodySmall,
                      ),
                      if (_manager && o.isCurrent)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            key: const ValueKey('raise-limit'),
                            onPressed: () => _raiseLimit(o),
                            icon: const Icon(Icons.add_circle_outline),
                            label: Text(tr('Limiti artır')),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.viewer == BooksViewer.parent)
                _WeeklySummary(books: o.books),
              if (canAdd)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: FilledButton.icon(
                    key: const ValueKey('add-book'),
                    onPressed: () => _add(o),
                    icon: const Icon(Icons.library_add_rounded),
                    label: Text(tr('Kitap ekle')),
                  ),
                ),
              if (o.books.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    tr('Bu dönem henüz kitap eklenmedi.'),
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final b in o.books)
                _BookCard(
                  book: b,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BookDetailScreen(
                        studentId: widget.studentId,
                        studentBook: b,
                        viewer: widget.viewer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.onTap});

  final StudentBook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = switch (book.status) {
      StudentBookStatus.active => context.brand.primary,
      StudentBookStatus.finished => context.brand.success,
      StudentBookStatus.dropped => scheme.outline,
    };
    return Card(
      child: ListTile(
        key: ValueKey('student-book-${book.id}'),
        onTap: onTap,
        leading: const Icon(Icons.menu_book_rounded),
        title: Text(book.book.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${book.book.publisher} · ${book.book.subjectName}'),
            Text(
              [
                tr('{n} soru', {'n': book.questions}),
                if (book.lastStudied != null)
                  tr('son çalışma {d}', {'d': _date(book.lastStudied!)}),
              ].join(' · '),
              style: text.bodySmall,
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            book.status.label,
            style: text.labelSmall?.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

/// Veli: son 7 günde kitaplardan çözülen soru.
class _WeeklySummary extends ConsumerWidget {
  const _WeeklySummary({required this.books});

  final List<StudentBook> books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final since = DateTime.now().subtract(const Duration(days: 7));
    var total = 0;
    BookProgress? last;
    for (final b in books) {
      for (final p
          in ref.watch(bookProgressProvider(b.id)).value ??
              const <BookProgress>[]) {
        if (p.studiedOn.isAfter(since)) total += p.solved;
        if (last == null || p.studiedOn.isAfter(last.studiedOn)) last = p;
      }
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.insights_rounded),
        title: Text(tr('Son 7 günde kitaplardan {n} soru', {'n': total})),
        subtitle: last == null
            ? null
            : Text(
                tr('Son çalışma: {d} · {topic}', {
                  'd': _date(last.studiedOn),
                  'topic': last.topicText ?? '',
                }),
              ),
      ),
    );
  }
}

class _LimitDialog extends StatefulWidget {
  const _LimitDialog({required this.current, required this.used});

  final int current;
  final int used;

  @override
  State<_LimitDialog> createState() => _LimitDialogState();
}

class _LimitDialogState extends State<_LimitDialog> {
  late int _limit = widget.current + 1;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('Kitap hakkını değiştir')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text(tr('Bu dönem için hak'))),
            IconButton(
              tooltip: tr('Azalt'),
              onPressed: _limit > widget.used && _limit > 1
                  ? () => setState(() => _limit--)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$_limit', key: const ValueKey('limit-value')),
            IconButton(
              key: const ValueKey('limit-plus'),
              tooltip: tr('Artır'),
              onPressed: _limit < 50 ? () => setState(() => _limit++) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        TextField(
          key: const ValueKey('limit-reason'),
          controller: _reason,
          decoration: InputDecoration(labelText: tr('Sebep')),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr('Vazgeç')),
      ),
      FilledButton(
        key: const ValueKey('limit-save'),
        style: _inline,
        onPressed: () {
          if (_reason.text.trim().isEmpty) {
            showMessage(context, tr('Sebebi yaz.'));
            return;
          }
          Navigator.pop(context, (_limit, _reason.text.trim()));
        },
        child: Text(tr('Kaydet')),
      ),
    ],
  );
}

/// Havuzdan kitap seçimi (serbest metin yok); bulunamazsa talep.
class BookPickerScreen extends ConsumerStatefulWidget {
  const BookPickerScreen({
    super.key,
    required this.studentId,
    required this.viewer,
    required this.overview,
  });

  final String studentId;
  final BooksViewer viewer;
  final BooksOverview overview;

  @override
  ConsumerState<BookPickerScreen> createState() => _BookPickerScreenState();
}

class _BookPickerScreenState extends ConsumerState<BookPickerScreen> {
  String _q = '';
  String? _subject;
  String? _publisher;

  Future<void> _choose(Book b) async {
    final o = widget.overview;
    var agreed = widget.viewer == BooksViewer.manager;
    final ok = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.overlayStyle(context),
      builder: (d) => StatefulBuilder(
        builder: (d, setState) => AlertDialog(
          title: Text(b.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${b.publisher} · ${b.subjectName}'),
              const SizedBox(height: 12),
              Text(
                widget.viewer == BooksViewer.manager
                    ? tr('Öğrencinin kitap hakkından düşer ({n}/{l}).', {
                        'n': o.used + 1,
                        'l': o.limit,
                      })
                    : tr(
                        'Bu kitap hakkını kullanacaksın ({n}/{l}). Ekledikten sonra kendin kaldıramazsın, düzeltme için koçuna başvurman gerekir.',
                        {'n': o.used + 1, 'l': o.limit},
                      ),
              ),
              if (widget.viewer == BooksViewer.student)
                CheckboxListTile(
                  key: const ValueKey('book-agree'),
                  contentPadding: EdgeInsets.zero,
                  value: agreed,
                  onChanged: (v) => setState(() => agreed = v ?? false),
                  title: Text(tr('Anladım, ekle')),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(tr('Vazgeç')),
            ),
            FilledButton(
              key: const ValueKey('book-confirm'),
              style: _inline,
              onPressed: agreed ? () => Navigator.pop(d, true) : null,
              child: Text(tr('Ekle')),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(booksRepositoryProvider)
          .addStudentBook(widget.studentId, b.id);
      _refresh(ref, widget.studentId);
      if (!mounted) return;
      _toast(context, tr('{name} eklendi.', {'name': b.name}));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _toast(context, _errorText(e));
    }
  }

  Future<void> _request() async {
    final draft = await showDialog<Book>(
      context: context,
      animationStyle: AppMotion.overlayStyle(context),
      builder: (_) => const BookFormDialog(request: true),
    );
    if (draft == null || !mounted) return;
    try {
      await ref
          .read(booksRepositoryProvider)
          .addBook(
            name: draft.name,
            publisher: draft.publisher,
            subjectCode: draft.subjectCode,
            kind: draft.kind,
          );
      ref.invalidate(bookPoolProvider);
      if (mounted) {
        _toast(
          context,
          widget.viewer == BooksViewer.student
              ? tr('Talebin iletildi. Onaylanınca bildirim gelecek.')
              : tr('Kitap havuza eklendi.'),
        );
      }
    } catch (e) {
      if (mounted) _toast(context, _errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pool = ref.watch(bookPoolProvider);
    final have = {for (final b in widget.overview.books) b.book.id};
    return Scaffold(
      appBar: AppBar(title: Text(tr('Kitap seç'))),
      body: AsyncView(
        value: pool,
        onRetry: () => ref.invalidate(bookPoolProvider),
        builder: (all) {
          final active = [
            for (final b in all)
              if (b.status == PoolStatus.active) b,
          ];
          final myRequests = [
            for (final b in all)
              if (b.status == PoolStatus.pending &&
                  widget.viewer == BooksViewer.student)
                b,
          ];
          final publishers = {for (final b in active) b.publisher}.toList()
            ..sort();
          final subjects = [
            for (final s in examSubjects)
              if (active.any((b) => b.subjectCode == s.code)) s.code,
          ];
          final q = bookKey(_q);
          final shown = [
            for (final b in active)
              if ((q.isEmpty ||
                      bookKey(b.name).contains(q) ||
                      bookKey(b.publisher).contains(q)) &&
                  (_subject == null || b.subjectCode == _subject) &&
                  (_publisher == null || b.publisher == _publisher))
                b,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              TextField(
                key: const ValueKey('book-search'),
                decoration: InputDecoration(
                  hintText: tr('Kitap ya da yayın ara'),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _subject,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr('Ders'),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem(value: null, child: Text(tr('Hepsi'))),
                        for (final c in subjects)
                          DropdownMenuItem(
                            value: c,
                            child: Text(
                              '${c.split('_').first} ${subjectByCode(c).name}',
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _subject = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _publisher,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr('Yayın'),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem(value: null, child: Text(tr('Hepsi'))),
                        for (final p in publishers)
                          DropdownMenuItem(value: p, child: Text(p)),
                      ],
                      onChanged: (v) => setState(() => _publisher = v),
                    ),
                  ),
                ],
              ),
              if (myRequests.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  tr('Onay bekleyen taleplerin'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final r in myRequests)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.hourglass_top_rounded),
                    title: Text(r.name),
                    subtitle: Text(r.publisher),
                  ),
              ],
              const SizedBox(height: 8),
              for (final b in shown)
                Card(
                  child: ListTile(
                    key: ValueKey('pool-${b.id}'),
                    enabled: !have.contains(b.id),
                    title: Text(b.name),
                    subtitle: Text(
                      [
                        b.publisher,
                        b.subjectName,
                        b.kind.label,
                        if (have.contains(b.id)) tr('zaten listende'),
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.add_rounded),
                    onTap: () => _choose(b),
                  ),
                ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  key: const ValueKey('request-book'),
                  leading: const Icon(Icons.help_outline_rounded),
                  title: Text(
                    shown.isEmpty
                        ? tr('Kitabı bulamadın mı? Talep et')
                        : widget.viewer == BooksViewer.student
                        ? tr('Aradığın kitap yok mu? Talep et')
                        : tr('Havuza yeni kitap ekle'),
                  ),
                  subtitle: Text(
                    widget.viewer == BooksViewer.student
                        ? tr(
                            'Koçun ya da müdürün onaylayınca havuza girer; sonra seçebilirsin.',
                          )
                        : tr('Kurumun kitap havuzuna eklenir.'),
                  ),
                  onTap: _request,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Kitap formu (talep ya da havuza ekleme): ad, yayın, ders, tür.
class BookFormDialog extends StatefulWidget {
  const BookFormDialog({super.key, this.request = false, this.book});

  final bool request;
  final Book? book;

  @override
  State<BookFormDialog> createState() => _BookFormDialogState();
}

class _BookFormDialogState extends State<BookFormDialog> {
  late final _name = TextEditingController(text: widget.book?.name ?? '');
  late final _publisher = TextEditingController(
    text: widget.book?.publisher ?? '',
  );
  late String? _subject = widget.book?.subjectCode;
  late BookKind _kind = widget.book?.kind ?? BookKind.questionBank;

  @override
  void dispose() {
    _name.dispose();
    _publisher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.request
          ? tr('Kitap talep et')
          : widget.book == null
          ? tr('Havuza kitap ekle')
          : tr('Kitabı düzenle'),
    ),
    content: SizedBox(
      width: 420,
      child: ListView(
        shrinkWrap: true,
        children: [
          TextField(
            key: const ValueKey('book-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: tr('Kitap adı')),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('book-publisher'),
            controller: _publisher,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: tr('Yayın')),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: _subject,
            isExpanded: true,
            decoration: InputDecoration(labelText: tr('Ders')),
            items: [
              DropdownMenuItem(value: null, child: Text(tr('Karma'))),
              for (final s in examSubjects)
                DropdownMenuItem(
                  value: s.code,
                  child: Text('${s.code.split('_').first} ${s.name}'),
                ),
            ],
            onChanged: (v) => setState(() => _subject = v),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<BookKind>(
            initialValue: _kind,
            decoration: InputDecoration(labelText: tr('Tür')),
            items: [
              for (final k in BookKind.values)
                DropdownMenuItem(value: k, child: Text(k.label)),
            ],
            onChanged: (v) => setState(() => _kind = v ?? _kind),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr('Vazgeç')),
      ),
      FilledButton(
        key: const ValueKey('book-form-save'),
        style: _inline,
        onPressed: () {
          final n = _name.text.trim(), p = _publisher.text.trim();
          if (n.length < 2 || p.isEmpty) {
            showMessage(context, tr('Kitap adını ve yayını yaz.'));
            return;
          }
          Navigator.pop(
            context,
            Book(
              id: widget.book?.id ?? '',
              name: n,
              publisher: p,
              subjectCode: _subject,
              kind: _kind,
              status: widget.book?.status ?? PoolStatus.active,
            ),
          );
        },
        child: Text(widget.request ? tr('Talep et') : tr('Kaydet')),
      ),
    ],
  );
}

/// Kitap detayı: çalışma kayıtları; koç/müdür durum değiştirir, siler.
class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({
    super.key,
    required this.studentId,
    required this.studentBook,
    required this.viewer,
  });

  final String studentId;
  final StudentBook studentBook;
  final BooksViewer viewer;

  bool get _manager => viewer == BooksViewer.manager;

  Future<void> _editProgress(
    BuildContext context,
    WidgetRef ref, [
    BookProgress? p,
  ]) async {
    final result = await showDialog<BookProgress>(
      context: context,
      animationStyle: AppMotion.overlayStyle(context),
      builder: (_) => ProgressDialog(studentBook: studentBook, progress: p),
    );
    if (result == null || !context.mounted) return;
    try {
      final repo = ref.read(booksRepositoryProvider);
      p == null
          ? await repo.addProgress(result)
          : await repo.updateProgress(result);
      _refresh(ref, studentId);
    } catch (e) {
      if (context.mounted) {
        _toast(
          context,
          '$e'.contains('NOT_ALLOWED')
              ? tr('Bu kaydı artık düzenleyemezsin; koçuna başvur.')
              : _errorText(e),
        );
      }
    }
  }

  Future<void> _manage(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final repo = ref.read(booksRepositoryProvider);
    try {
      if (action == 'delete') {
        final ok = await showDialog<bool>(
          context: context,
          animationStyle: AppMotion.overlayStyle(context),
          builder: (d) => AlertDialog(
            title: Text(tr('Kitap öğrencinin listesinden silinsin mi?')),
            content: Text(
              tr('Çalışma kayıtları da silinir ve kitap hakkından düşer.'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: Text(tr('Vazgeç')),
              ),
              FilledButton(
                style: _inline,
                onPressed: () => Navigator.pop(d, true),
                child: Text(tr('Sil')),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await repo.deleteStudentBook(studentBook.id);
        _refresh(ref, studentId);
        if (context.mounted) Navigator.pop(context);
        return;
      }
      await repo.setStudentBookStatus(
        studentBook.id,
        StudentBookStatus.values.byName(action),
      );
      _refresh(ref, studentId);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) _toast(context, _errorText(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(bookProgressProvider(studentBook.id));
    final me = ref.watch(currentProfileProvider).value?.id ?? '';
    final b = studentBook.book;
    final text = Theme.of(context).textTheme;
    final canAdd = viewer != BooksViewer.parent;
    return Scaffold(
      appBar: AppBar(
        title: Text(b.name),
        actions: [
          if (_manager)
            PopupMenuButton<String>(
              key: const ValueKey('book-manage'),
              tooltip: tr('Diğer'),
              onSelected: (v) => _manage(context, ref, v),
              itemBuilder: (_) => [
                for (final s in StudentBookStatus.values)
                  if (s != studentBook.status)
                    PopupMenuItem(
                      value: s.name,
                      child: Text(tr('Durum: {s}', {'s': s.label})),
                    ),
                PopupMenuItem(value: 'delete', child: Text(tr('Listeden sil'))),
              ],
            ),
        ],
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              key: const ValueKey('add-progress'),
              onPressed: () => _editProgress(context, ref),
              icon: const Icon(Icons.add),
              label: Text(tr('Çalışma ekle')),
            )
          : null,
      body: AsyncView(
        value: progress,
        onRetry: () => ref.invalidate(bookProgressProvider(studentBook.id)),
        builder: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Text(
              '${b.publisher} · ${b.subjectName} · ${b.kind.label}',
              style: text.bodyMedium,
            ),
            Text(
              [
                studentBook.status.label,
                tr('{n} soru', {'n': studentBook.questions}),
                if (studentBook.questions > 0)
                  tr('{d} doğru · {y} yanlış · {b} boş', {
                    'd': studentBook.correct,
                    'y': studentBook.wrong,
                    'b': studentBook.blank,
                  }),
              ].join(' · '),
              style: text.bodySmall,
            ),
            if (viewer == BooksViewer.student)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  tr(
                    'Kitabı kaldırmak ya da bitti işaretlemek için koçuna başvur. Kendi çalışmanı 24 saat içinde düzeltebilirsin.',
                  ),
                  style: text.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr('Henüz çalışma eklenmedi.'),
                  textAlign: TextAlign.center,
                ),
              ),
            for (final p in list)
              Card(
                child: ListTile(
                  title: Text(p.topicText ?? tr('Çalışma')),
                  subtitle: Text(
                    [
                      _date(p.studiedOn),
                      if (p.pageFrom != null)
                        tr('s. {a}-{b}', {
                          'a': p.pageFrom!,
                          'b': p.pageTo ?? p.pageFrom!,
                        }),
                      if (p.solved > 0) tr('{n} soru', {'n': p.solved}),
                      if (p.correct != null)
                        tr('{d}D {y}Y {b}B', {
                          'd': p.correct!,
                          'y': p.wrong ?? 0,
                          'b': p.blank ?? 0,
                        }),
                      if (p.note != null) p.note!,
                    ].join(' · '),
                  ),
                  trailing: canAdd && p.editableBy(me, manager: _manager)
                      ? PopupMenuButton<String>(
                          tooltip: tr('Diğer'),
                          onSelected: (v) async {
                            if (v == 'edit') {
                              await _editProgress(context, ref, p);
                              return;
                            }
                            try {
                              await ref
                                  .read(booksRepositoryProvider)
                                  .deleteProgress(p.id);
                              _refresh(ref, studentId);
                            } catch (_) {
                              if (context.mounted) {
                                _toast(
                                  context,
                                  tr(
                                    'Bu kaydı artık düzenleyemezsin; koçuna başvur.',
                                  ),
                                );
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text(tr('Düzenle')),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(tr('Sil')),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Çalışma ekle / düzenle: tarih, konu (kitabın dersinin konularından ya
/// da serbest), sayfa aralığı, soru ve doğru / yanlış / boş, not.
class ProgressDialog extends ConsumerStatefulWidget {
  const ProgressDialog({super.key, required this.studentBook, this.progress});

  final StudentBook studentBook;
  final BookProgress? progress;

  @override
  ConsumerState<ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends ConsumerState<ProgressDialog> {
  late DateTime _day = widget.progress?.studiedOn ?? DateTime.now();
  late int? _topicId = widget.progress?.topicId;
  late final _topic = TextEditingController(
    text: widget.progress?.topicText ?? '',
  );
  late final _from = TextEditingController(
    text: widget.progress?.pageFrom?.toString() ?? '',
  );
  late final _to = TextEditingController(
    text: widget.progress?.pageTo?.toString() ?? '',
  );
  late final _questions = TextEditingController(
    text: widget.progress?.questions?.toString() ?? '',
  );
  late final _correct = TextEditingController(
    text: widget.progress?.correct?.toString() ?? '',
  );
  late final _wrong = TextEditingController(
    text: widget.progress?.wrong?.toString() ?? '',
  );
  late final _blank = TextEditingController(
    text: widget.progress?.blank?.toString() ?? '',
  );
  late final _note = TextEditingController(text: widget.progress?.note ?? '');

  @override
  void dispose() {
    for (final c in [
      _topic,
      _from,
      _to,
      _questions,
      _correct,
      _wrong,
      _blank,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _int(TextEditingController c) => int.tryParse(c.text.trim());

  Widget _num(String label, TextEditingController c, String key) => Expanded(
    child: TextField(
      key: ValueKey(key),
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, isDense: true),
    ),
  );

  void _save() {
    final p = BookProgress(
      id: widget.progress?.id ?? '',
      studentBookId: widget.studentBook.id,
      studiedOn: DateTime(_day.year, _day.month, _day.day),
      topicId: _topicId,
      topicText: _topic.text.trim().isEmpty ? null : _topic.text.trim(),
      pageFrom: _int(_from),
      pageTo: _int(_to),
      questions: _int(_questions),
      correct: _int(_correct),
      wrong: _int(_wrong),
      blank: _int(_blank),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    final problem = validateProgress(p);
    if (problem != null) {
      showMessage(context, problem);
      return;
    }
    Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.studentBook.book.subjectCode;
    final topics = [
      for (final t in ref.watch(topicsProvider).value ?? const <Topic>[])
        if (subject == null || t.subjectCode == subject) t,
    ];
    return AlertDialog(
      title: Text(
        widget.progress == null ? tr('Çalışma ekle') : tr('Çalışmayı düzenle'),
      ),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Tarih')),
              trailing: Text(_date(_day)),
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _day,
                  firstDate: now.subtract(const Duration(days: 365)),
                  lastDate: now,
                );
                if (d != null) setState(() => _day = d);
              },
            ),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _topic.text),
              optionsBuilder: (v) {
                final q = bookKey(v.text);
                if (q.isEmpty) return const [];
                return [
                  for (final t in topics)
                    if (bookKey(t.name).contains(q)) t.name,
                ].take(8);
              },
              onSelected: (name) {
                _topic.text = name;
                _topicId = topics.where((t) => t.name == name).firstOrNull?.id;
              },
              fieldViewBuilder: (context, controller, focus, onSubmit) =>
                  TextField(
                    key: const ValueKey('progress-topic'),
                    controller: controller,
                    focusNode: focus,
                    onChanged: (v) {
                      _topic.text = v;
                      _topicId = topics
                          .where((t) => t.name == v)
                          .firstOrNull
                          ?.id;
                    },
                    decoration: InputDecoration(labelText: tr('Konu')),
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _num(tr('Başlangıç sayfası'), _from, 'p-from'),
                const SizedBox(width: 8),
                _num(tr('Bitiş sayfası'), _to, 'p-to'),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [_num(tr('Soru sayısı'), _questions, 'p-questions')]),
            const SizedBox(height: 8),
            Row(
              children: [
                _num(tr('Doğru'), _correct, 'p-correct'),
                const SizedBox(width: 8),
                _num(tr('Yanlış'), _wrong, 'p-wrong'),
                const SizedBox(width: 8),
                _num(tr('Boş'), _blank, 'p-blank'),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLength: 500,
              decoration: InputDecoration(labelText: tr('Not (isteğe bağlı)')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Vazgeç')),
        ),
        FilledButton(
          key: const ValueKey('progress-save'),
          style: _inline,
          onPressed: _save,
          child: Text(tr('Kaydet')),
        ),
      ],
    );
  }
}

/// Koç paneli sinyali: denemede başarısı düşük ama kitapla çalışılmamış konular.
class TopicGapsCard extends ConsumerWidget {
  const TopicGapsCard({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gaps = ref.watch(topicGapsProvider(studentId)).value ?? const [];
    if (gaps.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Kitapla desteklenmesi gereken konular'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            for (final g in gaps)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  tr(
                    '{topic}: deneme başarısı %{rate} ({n} soru), son 60 günde bu konuda kitap çalışması yok.',
                    {'topic': g.topicName, 'rate': g.rate, 'n': g.answered},
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Eğitim sekmesi: Kitaplarım girişi.
class MyBooksEntryCard extends ConsumerWidget {
  const MyBooksEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentProfileProvider).value?.id;
    final o = me == null
        ? null
        : ref.watch(booksOverviewProvider((me, null))).value;
    return Card(
      child: ListTile(
        key: const ValueKey('my-books-card'),
        leading: const Icon(Icons.menu_book_rounded),
        title: Text(tr('Kitaplarım')),
        subtitle: Text(
          o == null
              ? tr('Çözdüğün kaynak kitaplar ve ilerlemen')
              : tr('{u} / {l} kitap kullanıldı', {'u': o.used, 'l': o.limit}),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/student/books'),
      ),
    );
  }
}
