import '../../../shared/widgets/tool_tile.dart';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../import/data/spreadsheet_reader.dart';
import '../../student_management/data/student_management_repository.dart'
    show editDistance;
import '../data/books_repository.dart';
import 'books_screens.dart';
import '../../../core/design/motion.dart';

final _inline = FilledButton.styleFrom(minimumSize: const Size(0, 44));

void _toast(BuildContext context, String m) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m)));

/// Talebe benzeyen havuz kitapları (mükerrer kayıt olmasın): ad ya da
/// yayın anahtarı çok yakınsa.
List<Book> similarBooks(Book request, List<Book> pool) {
  final n = bookKey(request.name), p = bookKey(request.publisher);
  bool near(String a, String b) =>
      a == b ||
      (a.length > 4 && b.length > 4 && (a.contains(b) || b.contains(a))) ||
      editDistance(a, b) <= (a.length > 12 ? 3 : 1);
  return [
    for (final b in pool)
      if (b.status == PoolStatus.active &&
          near(n, bookKey(b.name)) &&
          (p.isEmpty || near(p, bookKey(b.publisher)) || bookKey(b.name) == n))
        b,
  ];
}

/// Excel satırındaki ders adı → ders kodu ("TYT Matematik", "AYT Fizik").
/// Yalnızca ders adı yazılmışsa ya da tanınmazsa null (karma).
String? subjectFromText(String text) {
  final key = bookKey(text);
  if (key.isEmpty) return null;
  for (final s in examSubjects) {
    final prefix = s.code.split('_').first.toLowerCase();
    if (key == bookKey('$prefix ${s.trName}') || key == bookKey(s.code)) {
      return s.code;
    }
  }
  return null;
}

/// Müdür / koç: kurum kitap havuzu ve onay bekleyen talepler.
class BookPoolScreen extends ConsumerWidget {
  const BookPoolScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref, [Book? book]) async {
    final draft = await showDialog<Book>(
      context: context,
      animationStyle: AppMotion.overlayStyle(context),
      builder: (_) => BookFormDialog(book: book),
    );
    if (draft == null || !context.mounted) return;
    try {
      final repo = ref.read(booksRepositoryProvider);
      book == null
          ? await repo.addBook(
              name: draft.name,
              publisher: draft.publisher,
              subjectCode: draft.subjectCode,
              kind: draft.kind,
            )
          : await repo.updateBook(draft);
      ref.invalidate(bookPoolProvider);
    } catch (e) {
      if (context.mounted) {
        _toast(
          context,
          e is BookExistsException
              ? tr('Bu kitap havuzda zaten var.')
              : tr('Kaydedilemedi. Tekrar dene.'),
        );
      }
    }
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    Book request,
    List<Book> pool,
  ) async {
    final similar = similarBooks(request, pool);
    final choice = await showModalBottomSheet<String>(
      context: context,
      sheetAnimationStyle: AppMotion.overlayStyle(context),
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(request.name),
              subtitle: Text('${request.publisher} · ${request.subjectName}'),
            ),
            if (similar.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  tr('Bu kitaba benziyor (mükerrer olmasın):'),
                  style: Theme.of(c).textTheme.titleSmall,
                ),
              ),
              for (final b in similar)
                ListTile(
                  key: ValueKey('merge-${b.id}'),
                  leading: const Icon(Icons.merge_rounded),
                  title: Text(b.name),
                  subtitle: Text(
                    tr('{p} · bununla birleştir', {'p': b.publisher}),
                  ),
                  onTap: () => Navigator.pop(c, 'merge:${b.id}'),
                ),
            ],
            ListTile(
              key: const ValueKey('approve-request'),
              leading: const Icon(Icons.check_circle_outline),
              title: Text(tr('Onayla ve havuza ekle')),
              onTap: () => Navigator.pop(c, 'approve'),
            ),
            ListTile(
              key: const ValueKey('reject-request'),
              leading: const Icon(Icons.block_rounded),
              title: Text(tr('Reddet')),
              onTap: () => Navigator.pop(c, 'reject'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final repo = ref.read(booksRepositoryProvider);
    try {
      if (choice == 'approve') {
        await repo.approve(request.id);
      } else if (choice == 'reject') {
        await repo.reject(request.id);
      } else {
        await repo.merge(request.id, choice.substring(6));
      }
      ref.invalidate(bookPoolProvider);
      if (context.mounted) {
        _toast(
          context,
          choice == 'reject'
              ? tr('Talep reddedildi; öğrenciye bildirildi.')
              : tr('Öğrenciye "kitap eklendi" bildirimi gitti.'),
        );
      }
    } catch (_) {
      if (context.mounted) _toast(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pool = ref.watch(bookPoolProvider);
    final usage = ref.watch(bookUsageProvider).value ?? const {};
    return AsyncView(
      value: pool,
      onRetry: () => ref.invalidate(bookPoolProvider),
      builder: (all) {
        final active = [
          for (final b in all)
            if (b.status != PoolStatus.pending) b,
        ];
        final pending = [
          for (final b in all)
            if (b.status == PoolStatus.pending) b,
        ];
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(tr('Kitap havuzu')),
              actions: [
                IconButton(
                  tooltip: tr('Excel ile toplu ekle'),
                  icon: const Icon(Icons.upload_file_rounded),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BookImportScreen(),
                    ),
                  ),
                ),
              ],
              bottom: TabBar(
                tabs: [
                  Tab(text: tr('Havuz ({n})', {'n': active.length})),
                  Tab(
                    text: tr('Onay bekleyenler ({n})', {'n': pending.length}),
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              key: const ValueKey('pool-add'),
              onPressed: () => _add(context, ref),
              icon: const Icon(Icons.add),
              label: Text(tr('Kitap ekle')),
            ),
            body: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    if (active.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          tr(
                            'Havuz boş. Kitap ekle ya da Excel ile toplu yükle.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    for (final b in active)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(b.name),
                          subtitle: Text(
                            [
                              b.publisher,
                              b.subjectName,
                              b.kind.label,
                              tr('{n} öğrencide', {
                                'n': usage[b.id]?.students ?? 0,
                              }),
                              if (usage[b.id] != null)
                                tr('ort. {n} soru', {
                                  'n': usage[b.id]!.avgQuestions.round(),
                                }),
                              if (b.status == PoolStatus.inactive) tr('Pasif'),
                            ].join(' · '),
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: tr('Diğer'),
                            onSelected: (v) async {
                              if (v == 'edit') return _add(context, ref, b);
                              try {
                                await ref
                                    .read(booksRepositoryProvider)
                                    .updateBook(
                                      b.copyWith(
                                        status: b.status == PoolStatus.inactive
                                            ? PoolStatus.active
                                            : PoolStatus.inactive,
                                      ),
                                    );
                                ref.invalidate(bookPoolProvider);
                              } catch (_) {
                                if (context.mounted) {
                                  _toast(
                                    context,
                                    tr('Kaydedilemedi. Tekrar dene.'),
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
                                value: 'toggle',
                                child: Text(
                                  b.status == PoolStatus.inactive
                                      ? tr('Etkinleştir')
                                      : tr('Pasifleştir'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    if (pending.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          tr('Onay bekleyen kitap yok.'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    for (final r in pending)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          key: ValueKey('pending-${r.id}'),
                          leading: const Icon(Icons.hourglass_top_rounded),
                          title: Text(r.name),
                          subtitle: Text(
                            [
                              r.publisher,
                              r.subjectName,
                              if (similarBooks(r, all).isNotEmpty)
                                tr('benzer kitap var'),
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _decide(context, ref, r, all),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Havuzu Excel'den doldur: ad, yayın, ders, tür sütunları.
class BookImportScreen extends ConsumerStatefulWidget {
  const BookImportScreen({super.key, this.initialRows});

  /// Testler için: dosya seçmeden bu satırlarla.
  final List<List<String>>? initialRows;

  @override
  ConsumerState<BookImportScreen> createState() => _BookImportScreenState();
}

class _BookImportScreenState extends ConsumerState<BookImportScreen> {
  List<Book>? _rows;
  int _unmatched = 0;
  int _skipped = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRows;
    if (r != null) _parse(r);
  }

  void _parse(List<List<String>> rows) {
    if (rows.isEmpty) return;
    final header = [for (final h in rows.first) bookKey(h)];
    int col(List<String> keys) =>
        header.indexWhere((h) => keys.any((k) => h.contains(k)));
    final name = col(['kitap', 'ad', 'name']);
    final pub = col(['yayin', 'publisher']);
    final subj = col(['ders', 'subject']);
    final kind = col(['tur', 'kind', 'tip']);
    final out = <Book>[];
    var unmatched = 0, skipped = 0;
    for (final r in rows.skip(1)) {
      String at(int i) => i < 0 || i >= r.length ? '' : r[i].trim();
      if (at(name).length < 2 || at(pub).isEmpty) {
        if (r.any((c) => c.trim().isNotEmpty)) skipped++;
        continue;
      }
      final code = subjectFromText(at(subj));
      if (code == null && at(subj).isNotEmpty) unmatched++;
      final k = bookKey(at(kind));
      out.add(
        Book(
          id: '',
          name: at(name),
          publisher: at(pub),
          subjectCode: code,
          kind: k.contains('deneme')
              ? BookKind.practiceExams
              : k.contains('konu')
              ? BookKind.lecture
              : k.contains('diger')
              ? BookKind.other
              : BookKind.questionBank,
        ),
      );
    }
    setState(() {
      _rows = out;
      _unmatched = unmatched;
      _skipped = skipped;
    });
  }

  Future<void> _pick() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;
      final sheets = await readSpreadsheetInBackground(
        Uint8List.fromList(await files.first.readAsBytes()),
      );
      if (!mounted) return;
      _parse(sheets.values.first);
    } catch (_) {
      if (mounted) {
        _toast(
          context,
          tr('Dosya okunamadı. Excel (.xlsx, .xls) ya da CSV seç.'),
        );
      }
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final (ins, skip) = await ref
          .read(booksRepositoryProvider)
          .importBooks(_rows!);
      ref.invalidate(bookPoolProvider);
      if (!mounted) return;
      _toast(
        context,
        tr('{i} kitap eklendi, {s} zaten havuzdaydı.', {'i': ins, 's': skip}),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Kitap havuzu yükle'))),
      bottomNavigationBar: rows == null || rows.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  key: const ValueKey('books-import-go'),
                  style: _inline,
                  onPressed: _busy ? null : _import,
                  child: Text(tr('İçe aktar ({n} kitap)', {'n': rows.length})),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.attach_file_rounded),
            label: Text(tr('Dosya seç (Excel / CSV)')),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'Sütunlar: kitap adı, yayın, ders ("TYT Matematik" gibi), tür (soru bankası / deneme / konu anlatımı). Aynı ad ve yayın tekrar eklenmez.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (rows != null) ...[
            const SizedBox(height: 12),
            Text(tr('{n} kitap okundu', {'n': rows.length})),
            if (_skipped > 0)
              Text(
                tr('{n} satırda ad ya da yayın eksik; atlanacak.', {
                  'n': _skipped,
                }),
              ),
            if (_unmatched > 0)
              Text(
                tr(
                  '{n} satırda ders tanınmadı; "Karma" eklenecek, sonra düzenleyebilirsin.',
                  {'n': _unmatched},
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            for (final b in rows.take(20))
              ListTile(
                dense: true,
                title: Text(b.name),
                subtitle: Text(
                  '${b.publisher} · ${b.subjectName} · ${b.kind.label}',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Müdür / koç ana sayfası: kitap havuzu (bekleyen talep sayısıyla).
/// Kitap havuzu kısayolu (onay bekleyen talepler).
ToolInfo bookPoolTool(WidgetRef ref, String basePath) {
  final pending = (ref.watch(bookPoolProvider).value ?? const <Book>[])
      .where((b) => b.status == PoolStatus.pending)
      .length;
  return ToolInfo(
    id: 'book-pool-card',
    icon: Icons.local_library_outlined,
    title: tr('Kitap havuzu'),
    status: pending > 0
        ? tr('{n} kitap talebi onay bekliyor', {'n': pending})
        : tr('Öğrencilerin seçtiği kaynak kitaplar'),
    needsAction: pending > 0,
    open: (context) => context.push('$basePath/books'),
  );
}

class BookPoolHomeCard extends ConsumerWidget {
  const BookPoolHomeCard({super.key, required this.basePath});

  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ToolListCard(tool: bookPoolTool(ref, basePath));
}
