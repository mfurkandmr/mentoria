import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../import/data/spreadsheet_reader.dart';
import '../../student_books/presentation/book_pool_screen.dart'
    show subjectFromText;
import '../data/exam_admin_repository.dart';
import '../domain/exam_definition.dart';

/// Kazanım Excel'i: Ders ("TYT Matematik"), Konu, Alt konu, Kod sütunları.
/// İlk satır başlık; sütunlar başlık adından bulunur, bulunamazsa sırayla.
/// Dönüş: satırlar ve dersi tanınmayan satır sayısı.
(List<OutcomeImportRow>, int) parseOutcomeSheet(List<List<String>> rows) {
  if (rows.length < 2) return (const [], 0);
  final head = [
    for (final h in rows.first) foldTr(h).replaceAll(RegExp(r'[^a-z ]'), ''),
  ];
  int col(bool Function(String h) test, int fallback) {
    for (var i = 0; i < head.length; i++) {
      if (test(head[i])) return i;
    }
    return fallback < head.length ? fallback : -1;
  }

  final subj = col((h) => h.contains('ders'), 0);
  final sub = col((h) => h.contains('alt') || h.contains('kazanim'), 2);
  final topic = col(
    (h) => (h.contains('konu') || h.contains('unite')) && !h.contains('alt'),
    1,
  );
  final code = col((h) => h.contains('kod'), 3);
  String at(List<String> r, int i) => i >= 0 && i < r.length ? r[i].trim() : '';
  var unknown = 0;
  final out = <OutcomeImportRow>[];
  for (final r in rows.skip(1)) {
    final t = at(r, topic);
    if (t.isEmpty) continue;
    final s = subjectFromText(at(r, subj));
    if (s == null) {
      unknown++;
      continue;
    }
    out.add(
      OutcomeImportRow(
        subject: s,
        topic: t,
        subtopic: at(r, sub).isEmpty ? null : at(r, sub),
        code: at(r, code).isEmpty ? null : at(r, code),
      ),
    );
  }
  return (out, unknown);
}

/// Kurumun kazanım havuzu: ders > konu > alt konu ağacı, Excel ile toplu ekleme.
class OutcomePoolScreen extends ConsumerStatefulWidget {
  const OutcomePoolScreen({super.key});

  @override
  ConsumerState<OutcomePoolScreen> createState() => _OutcomePoolScreenState();
}

class _OutcomePoolScreenState extends ConsumerState<OutcomePoolScreen> {
  String _subject = examSubjects.first.code;

  Future<String?> _ask(String title, {String initial = ''}) async {
    final c = TextEditingController(text: initial);
    final v = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const ValueKey('outcome-name'),
          controller: c,
          autofocus: true,
          decoration: InputDecoration(labelText: tr('Ad')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Vazgeç')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: Text(tr('Kaydet')),
          ),
        ],
      ),
    );
    c.dispose();
    return v == null || v.isEmpty ? null : v;
  }

  Future<void> _run(Future<void> Function() f) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await f();
      ref.invalidate(learningOutcomesProvider);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Kaydedilemedi. Aynı ad zaten olabilir.'))),
      );
    }
  }

  Future<void> _add({String? parentId}) async {
    final name = await _ask(
      parentId == null ? tr('Yeni konu') : tr('Yeni alt konu'),
    );
    if (name == null) return;
    await _run(
      () => ref
          .read(examAdminRepositoryProvider)
          .addOutcome(subject: _subject, name: name, parentId: parentId),
    );
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;
      final sheets = await readSpreadsheetInBackground(
        Uint8List.fromList(await files.first.readAsBytes()),
      );
      if (!mounted) return;
      final (rows, unknown) = parseOutcomeSheet(sheets.values.first);
      if (rows.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'Kazanım bulunamadı. Sütunlar: Ders ("TYT Matematik" gibi), Konu, Alt konu, Kod.',
              ),
            ),
          ),
        );
        return;
      }
      final r = await ref
          .read(examAdminRepositoryProvider)
          .importOutcomes(rows);
      ref.invalidate(learningOutcomesProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr(
              '{i} kazanım eklendi, {s} zaten vardı. Dersi tanınmayan satır: {u}.',
              {'i': r.inserted, 's': r.skipped, 'u': unknown},
            ),
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr('Dosya okunamadı. Excel (.xlsx, .xls) ya da CSV seç.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tree = ref.watch(learningOutcomesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Kazanım havuzu')),
        actions: [
          IconButton(
            tooltip: tr('Excel ile toplu ekle'),
            onPressed: _import,
            icon: const Icon(Icons.upload_file_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add-topic'),
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('Konu ekle')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: DropdownButtonFormField<String>(
              initialValue: _subject,
              decoration: InputDecoration(labelText: tr('Ders')),
              items: [
                for (final s in examSubjects)
                  DropdownMenuItem(
                    value: s.code,
                    child: Text('${s.examType.label} ${s.name}'),
                  ),
              ],
              onChanged: (v) => setState(() => _subject = v!),
            ),
          ),
          Expanded(
            child: AsyncView(
              value: tree,
              onRetry: () => ref.invalidate(learningOutcomesProvider),
              builder: (t) {
                final roots = t.roots(_subject);
                if (roots.isEmpty) {
                  return ListView(
                    children: [
                      EmptyState(
                        title: tr('Bu derste kazanım yok'),
                        message: tr(
                          'Konu ekle ya da Excel ile toplu yükle. Sütunlar: Ders, Konu, Alt konu, Kod.',
                        ),
                      ),
                    ],
                  );
                }
                return ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    for (final r in roots)
                      _OutcomeNode(
                        tree: t,
                        node: r,
                        onAdd: (id) => _add(parentId: id),
                        onRename: (o) async {
                          final name = await _ask(
                            tr('Adı değiştir'),
                            initial: o.name,
                          );
                          if (name == null) return;
                          await _run(
                            () => ref
                                .read(examAdminRepositoryProvider)
                                .updateOutcome(o.id, name: name, code: o.code),
                          );
                        },
                        onDelete: (o) async {
                          final ok = await confirm(
                            context,
                            title: tr('Kazanım silinsin mi?'),
                            message: tr(
                              'Alt konuları da silinir. Sınavlardaki eşleştirmeler kaldırılır; geçmiş sonuçlardaki ad kalır.',
                            ),
                          );
                          if (!ok) return;
                          await _run(
                            () => ref
                                .read(examAdminRepositoryProvider)
                                .deleteOutcome(o.id),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomeNode extends StatelessWidget {
  const _OutcomeNode({
    required this.tree,
    required this.node,
    required this.onAdd,
    required this.onRename,
    required this.onDelete,
    this.depth = 0,
  });

  final OutcomeTree tree;
  final LearningOutcome node;
  final ValueChanged<String> onAdd;
  final ValueChanged<LearningOutcome> onRename;
  final ValueChanged<LearningOutcome> onDelete;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final children = tree.children(node.id);
    final menu = PopupMenuButton<String>(
      tooltip: tr('Kazanım işlemleri'),
      onSelected: (v) => switch (v) {
        'add' => onAdd(node.id),
        'rename' => onRename(node),
        _ => onDelete(node),
      },
      itemBuilder: (_) => [
        if (depth < 2)
          PopupMenuItem(value: 'add', child: Text(tr('Alt konu ekle'))),
        PopupMenuItem(value: 'rename', child: Text(tr('Adı değiştir'))),
        PopupMenuItem(value: 'delete', child: Text(tr('Sil'))),
      ],
    );
    final title = Text(
      node.code == null ? node.name : '${node.name}  ·  ${node.code}',
      style: TextStyle(
        fontWeight: depth == 0 ? FontWeight.w700 : FontWeight.w400,
      ),
    );
    if (children.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.only(left: 16.0 + depth * 24, right: 8),
        title: title,
        trailing: menu,
      );
    }
    return ExpansionTile(
      tilePadding: EdgeInsets.only(left: 16.0 + depth * 24, right: 8),
      title: title,
      subtitle: Text(tr('{n} alt konu', {'n': children.length})),
      trailing: menu,
      children: [
        for (final c in children)
          _OutcomeNode(
            tree: tree,
            node: c,
            onAdd: onAdd,
            onRename: onRename,
            onDelete: onDelete,
            depth: depth + 1,
          ),
      ],
    );
  }
}
