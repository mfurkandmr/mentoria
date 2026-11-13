import '../../../shared/widgets/tool_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../exam_analysis/presentation/exam_report_screen.dart';
import '../data/exam_admin_repository.dart';
import '../domain/exam_definition.dart';
import 'exam_package_flow.dart';
import 'import_wizard_screen.dart';
import 'outcome_picker.dart';
import '../../../core/design/motion.dart';

String examKindLabel(ExamKind k) => switch (k) {
  ExamKind.deneme => tr('Deneme'),
  ExamKind.konuTarama => tr('Konu tarama'),
};

/// Kurum sınavları: optik okuyucu Excel'iyle sonuç yükleme ve kazanım analizi.
class OrgExamsScreen extends ConsumerWidget {
  const OrgExamsScreen({super.key, required this.basePath});

  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exams = ref.watch(orgExamsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Kurum sınavları')),
        actions: [
          IconButton(
            key: const ValueKey('exam-from-files'),
            tooltip: tr('Dosyalardan sınav kur'),
            icon: const Icon(Icons.drive_folder_upload_outlined),
            onPressed: () => createExamFromFiles(context, ref, basePath),
          ),
          IconButton(
            key: const ValueKey('open-outcomes'),
            tooltip: tr('Kazanım havuzu'),
            icon: const Icon(Icons.account_tree_outlined),
            onPressed: () => context.push('$basePath/outcomes'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('new-org-exam'),
        onPressed: () => context.push('$basePath/org-exams/new'),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('Yeni sınav')),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(orgExamsProvider.future),
        child: AsyncView(
          value: exams,
          onRetry: () => ref.invalidate(orgExamsProvider),
          builder: (list) => list.isEmpty
              ? ListView(
                  children: [
                    EmptyState(
                      title: tr('Henüz sınav yok'),
                      message: tr(
                        'Sınavı tanımla, cevap anahtarını ve kazanımları gir, sonra optik okuyucunun Excel dosyasını yükle.',
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final e = list[i];
                    return Card(
                      child: ListTile(
                        key: ValueKey('org-exam-${e.id}'),
                        title: Text(e.name),
                        subtitle: Text(
                          '${formatShortDate(e.takenOn)} · ${e.examType.label} · ${examKindLabel(e.kind)} · ${tr('{n} optik', {'n': e.sheetCount})}',
                        ),
                        trailing: _StatusChip(draft: e.isDraft),
                        onTap: () =>
                            context.push('$basePath/org-exams/${e.id}'),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.draft});
  final bool draft;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (draft ? b.secondary : b.success).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        draft ? tr('Taslak') : tr('Yayında'),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: draft ? b.ink : b.success,
        ),
      ),
    );
  }
}

/// Cevap metni: yalnızca A-E kalır; boş, "-", "*", "." cevapsız ("-").
/// Excel'den kopyalanan sütundaki satır sonları ve boşluklar atılır.
String cleanKeyText(String raw) {
  final b = StringBuffer();
  for (final ch in raw.toUpperCase().split('')) {
    if ('ABCDE'.contains(ch)) {
      b.write(ch);
    } else if ('-*._?'.contains(ch)) {
      b.write('-');
    }
  }
  return b.toString();
}

/// "5 4 3 2 1" / "5,4,3" → numaralar; geçersizse `null`.
List<int>? parseOrder(String raw, int count) {
  final parts = raw
      .split(RegExp(r'[\s,;]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return const [];
  final nums = [for (final p in parts) int.tryParse(p)];
  if (nums.any((n) => n == null || n < 1 || n > count)) return null;
  if (nums.toSet().length != nums.length || nums.length != count) return null;
  return nums.cast<int>();
}

/// Sınav oluşturma / düzenleme: bilgiler, anahtar, kazanımlar, sonuçlar.
class OrgExamScreen extends ConsumerStatefulWidget {
  const OrgExamScreen({super.key, required this.basePath, this.examId});

  final String basePath;

  /// `null`: yeni sınav.
  final String? examId;

  @override
  ConsumerState<OrgExamScreen> createState() => _OrgExamScreenState();
}

class _OrgExamScreenState extends ConsumerState<OrgExamScreen> {
  ExamDefinition? _exam;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.examId == null) {
      _exam = ExamDefinition(
        name: '',
        examType: ExamType.tyt,
        takenOn: DateUtils.dateOnly(DateTime.now()),
        subjects: _defaultSubjects(ExamType.tyt),
      );
    }
  }

  static List<ExamSubjectDef> _defaultSubjects(ExamType t) => [
    // Kitapçık sırası: AYT'de Edebiyat-Sosyal-1, Sosyal-2, Matematik, Fen.
    for (final s in bookletSubjects(t))
      ExamSubjectDef(code: s.code, questionCount: s.questionCount),
  ];

  void _update(ExamDefinition e) => setState(() {
    _exam = e;
    _dirty = true;
  });

  /// Kaydeder; sınavın kimliğini döner (olmazsa `null`).
  Future<String?> _save() async {
    final e = _exam!;
    final messenger = ScaffoldMessenger.of(context);
    if (e.name.trim().length < 2) {
      messenger.showSnackBar(SnackBar(content: Text(tr('Sınavın adını yaz.'))));
      return null;
    }
    if (e.subjects.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('En az bir ders ekle.'))),
      );
      return null;
    }
    setState(() => _saving = true);
    try {
      final id = await ref.read(examAdminRepositoryProvider).saveExam(e);
      ref.invalidate(orgExamsProvider);
      ref.invalidate(orgExamProvider(id));
      if (!mounted) return id;
      setState(() {
        _exam = e.copyWith(id: id);
        _dirty = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.isDraft || e.id == null
                ? tr('Sınav kaydedildi.')
                : tr('Kaydedildi; sonuçlar yeniden hesaplandı.'),
          ),
        ),
      );
      return id;
    } on ExamLockedTypeException {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Kaydedilmiş sınavın türü değiştirilemez.'))),
      );
      return null;
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Kaydedilemedi. Bilgileri kontrol et.'))),
      );
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_exam == null) {
      final async = ref.watch(orgExamProvider(widget.examId!));
      return Scaffold(
        appBar: AppBar(title: Text(tr('Sınav'))),
        body: AsyncView(
          value: async,
          onRetry: () => ref.invalidate(orgExamProvider(widget.examId!)),
          builder: (e) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _exam == null) setState(() => _exam = e);
            });
            return const SizedBox.shrink();
          },
        ),
      );
    }
    final e = _exam!;
    return DefaultTabController(
      length: 4,
      child: PopScope(
        canPop: !_dirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final leave = await confirm(
            context,
            title: tr('Kaydedilmemiş değişiklikler var'),
            message: tr('Çıkarsan değişiklikler kaybolur.'),
            action: tr('Çık'),
          );
          if (leave && context.mounted) {
            setState(() => _dirty = false);
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(e.name.isEmpty ? tr('Yeni sınav') : e.name),
            actions: [
              TextButton.icon(
                key: const ValueKey('save-org-exam'),
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(tr('Kaydet')),
              ),
            ],
            bottom: TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: tr('Bilgiler')),
                Tab(text: tr('Cevap anahtarı')),
                Tab(text: tr('Kazanımlar')),
                Tab(text: tr('Sonuçlar')),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _InfoTab(exam: e, onChanged: _update),
              _KeyTab(exam: e, onChanged: _update),
              _OutcomeTab(exam: e, onChanged: _update),
              _ResultsTab(
                exam: e,
                basePath: widget.basePath,
                dirty: _dirty,
                onSave: _save,
                onPublished: (id) async {
                  final fresh = await ref
                      .read(examAdminRepositoryProvider)
                      .fetchExam(id);
                  if (mounted) setState(() => _exam = fresh);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Bilgiler: ad, tür, tarih, yanlış katsayısı, sınıflar, dersler
// ---------------------------------------------------------------------
class _InfoTab extends ConsumerStatefulWidget {
  const _InfoTab({required this.exam, required this.onChanged});

  final ExamDefinition exam;
  final ValueChanged<ExamDefinition> onChanged;

  @override
  ConsumerState<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends ConsumerState<_InfoTab> {
  late final _name = TextEditingController(text: widget.exam.name);
  late final _publisher = TextEditingController(
    text: widget.exam.publisher ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _publisher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exam;
    final locked = e.id != null;
    final classes = ref.watch(examClassroomsProvider).value ?? const [];
    final available = [
      for (final s in examSubjects)
        if (s.examType == e.examType && e.subject(s.code) == null) s,
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          key: const ValueKey('exam-name'),
          controller: _name,
          decoration: InputDecoration(labelText: tr('Sınav adı')),
          onChanged: (v) => widget.onChanged(e.copyWith(name: v)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _publisher,
          decoration: InputDecoration(labelText: tr('Yayın (isteğe bağlı)')),
          onChanged: (v) => widget.onChanged(e.copyWith(publisher: v)),
        ),
        const SizedBox(height: 16),
        Text(tr('Tür'), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in ExamType.values)
              ChoiceChip(
                label: Text(t.label),
                selected: e.examType == t,
                onSelected: locked
                    ? null
                    : (_) => widget.onChanged(
                        e.copyWith(
                          examType: t,
                          subjects: _OrgExamScreenState._defaultSubjects(t),
                          questions: const [],
                          booklets: const {},
                        ),
                      ),
              ),
            for (final k in ExamKind.values)
              ChoiceChip(
                label: Text(examKindLabel(k)),
                selected: e.kind == k,
                onSelected: (_) => widget.onChanged(e.copyWith(kind: k)),
              ),
          ],
        ),
        if (locked)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              tr('Kaydedilmiş sınavın türü değiştirilemez.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text(tr('Sınav tarihi')),
          subtitle: Text(formatLongDate(e.takenOn)),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: e.takenOn,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (d != null) widget.onChanged(e.copyWith(takenOn: d));
          },
        ),
        SwitchListTile(
          key: const ValueKey('wrong-penalty'),
          contentPadding: EdgeInsets.zero,
          title: Text(tr('Yanlışlar doğruyu götürür')),
          subtitle: Text(
            e.wrongPenalty
                ? tr('{n} yanlış bir doğruyu götürür', {
                    'n': (1 / e.penaltyRatio).round(),
                  })
                : tr('Net = doğru sayısı'),
          ),
          value: e.wrongPenalty,
          onChanged: (v) => widget.onChanged(e.copyWith(wrongPenalty: v)),
        ),
        if (e.wrongPenalty)
          Wrap(
            spacing: 8,
            children: [
              for (final n in const [3, 4])
                ChoiceChip(
                  label: Text(tr('{n} yanlış', {'n': n})),
                  selected: (1 / e.penaltyRatio).round() == n,
                  onSelected: (_) => widget.onChanged(
                    e.copyWith(penaltyRatio: n == 4 ? 0.25 : 0.3333),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
        Text(
          tr('Uygulandığı sınıflar'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (classes.isEmpty)
          Text(
            tr('Kurumda sınıf yok; sınıf sıralaması yapılmaz.'),
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in classes)
                FilterChip(
                  label: Text(c.name),
                  selected: e.classroomIds.contains(c.id),
                  onSelected: (v) => widget.onChanged(
                    e.copyWith(
                      classroomIds: v
                          ? [...e.classroomIds, c.id]
                          : [
                              for (final x in e.classroomIds)
                                if (x != c.id) x,
                            ],
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                tr('Dersler'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (available.isNotEmpty)
              PopupMenuButton<ExamSubject>(
                tooltip: tr('Ders ekle'),
                icon: const Icon(Icons.add_rounded),
                onSelected: (s) => widget.onChanged(
                  e.copyWith(
                    subjects: [
                      ...e.subjects,
                      ExamSubjectDef(
                        code: s.code,
                        questionCount: s.questionCount,
                      ),
                    ],
                  ),
                ),
                itemBuilder: (_) => [
                  for (final s in available)
                    PopupMenuItem(value: s, child: Text(s.name)),
                ],
              ),
          ],
        ),
        for (final s in e.subjects)
          _SubjectRow(
            key: ValueKey('subject-${s.code}'),
            subject: s,
            onChanged: (n) => widget.onChanged(
              e.copyWith(
                subjects: [
                  for (final x in e.subjects) x.code == s.code ? n : x,
                ],
              ),
            ),
            onRemove: e.subjects.length == 1
                ? null
                : () => widget.onChanged(
                    e.copyWith(
                      subjects: [
                        for (final x in e.subjects)
                          if (x.code != s.code) x,
                      ],
                    ),
                  ),
          ),
      ],
    );
  }
}

class _SubjectRow extends StatefulWidget {
  const _SubjectRow({
    super.key,
    required this.subject,
    required this.onChanged,
    this.onRemove,
  });

  final ExamSubjectDef subject;
  final ValueChanged<ExamSubjectDef> onChanged;
  final VoidCallback? onRemove;

  @override
  State<_SubjectRow> createState() => _SubjectRowState();
}

class _SubjectRowState extends State<_SubjectRow> {
  late final _count = TextEditingController(
    text: '${widget.subject.questionCount}',
  );
  late final _weight = TextEditingController(
    text: formatNet(widget.subject.weight),
  );

  @override
  void dispose() {
    _count.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(subjectByCode(widget.subject.code).name)),
        SizedBox(
          width: 72,
          child: TextField(
            controller: _count,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: tr('Soru')),
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null && n >= 1 && n <= 80) {
                widget.onChanged(widget.subject.copyWith(questionCount: n));
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: tr('Katsayı')),
            onChanged: (v) {
              final w = double.tryParse(v.replaceAll(',', '.'));
              if (w != null && w > 0 && w <= 10) {
                widget.onChanged(widget.subject.copyWith(weight: w));
              }
            },
          ),
        ),
        IconButton(
          tooltip: tr('Dersi çıkar'),
          onPressed: widget.onRemove,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------
// Cevap anahtarı: kitapçık başına, ders başına cevap metni
// ---------------------------------------------------------------------
class _KeyTab extends StatefulWidget {
  const _KeyTab({required this.exam, required this.onChanged});

  final ExamDefinition exam;
  final ValueChanged<ExamDefinition> onChanged;

  @override
  State<_KeyTab> createState() => _KeyTabState();
}

class _KeyTabState extends State<_KeyTab> {
  String _booklet = 'A';

  String _keyText(ExamSubjectDef s) {
    final e = widget.exam;
    final b = StringBuffer();
    for (var n = 1; n <= s.questionCount; n++) {
      if (_booklet == 'A') {
        b.write(e.question(s.code, n)?.correct ?? '-');
      } else {
        final q = (e.booklets[_booklet] ?? const []).where(
          (x) => x.subject == s.code && x.number == n,
        );
        final item = q.isEmpty ? null : q.first;
        b.write(
          item?.correct ??
              (item == null ? '-' : e.question(s.code, item.itemNo)?.correct) ??
              '-',
        );
      }
    }
    return b.toString();
  }

  String _orderText(ExamSubjectDef s) {
    final list = [
      for (final q
          in widget.exam.booklets[_booklet] ?? const <BookletQuestion>[])
        if (q.subject == s.code) q,
    ]..sort((a, b) => a.number - b.number);
    if (list.every((q) => q.number == q.itemNo)) return '';
    return list.map((q) => q.itemNo).join(' ');
  }

  void _setA(ExamSubjectDef s, String text) {
    final e = widget.exam;
    final clean = cleanKeyText(text);
    final others = [
      for (final q in e.questions)
        if (q.subject != s.code) q,
    ];
    widget.onChanged(
      e.copyWith(
        questions: [
          ...others,
          for (var n = 1; n <= s.questionCount; n++)
            () {
              final old = e.question(s.code, n);
              final ch = n <= clean.length ? clean[n - 1] : '-';
              final letter = ch == '-' ? null : ch;
              return old == null
                  ? KeyQuestion(subject: s.code, number: n, correct: letter)
                  : old.copyWith(correct: letter, clearCorrect: letter == null);
            }(),
        ],
      ),
    );
  }

  void _setBooklet(ExamSubjectDef s, {String? keys, String? order}) {
    final e = widget.exam;
    final list = e.booklets[_booklet] ?? const <BookletQuestion>[];
    final keyText = cleanKeyText(keys ?? _keyText(s));
    final ord = parseOrder(order ?? _orderText(s), s.questionCount) ?? const [];
    final anyKey = keyText.split('').any((c) => c != '-');
    final rows = [
      for (var n = 1; n <= s.questionCount; n++)
        () {
          final itemNo = ord.isEmpty ? n : ord[n - 1];
          final ch = n <= keyText.length ? keyText[n - 1] : '-';
          // Sıra karışıksa ve harf A'dakiyle aynıysa ayrıca saklamaya gerek yok.
          final aCorrect = e.question(s.code, itemNo)?.correct;
          return BookletQuestion(
            subject: s.code,
            number: n,
            itemNo: itemNo,
            correct: ch == '-' || ch == aCorrect ? null : ch,
          );
        }(),
    ];
    widget.onChanged(
      e.copyWith(
        booklets: {
          ...e.booklets,
          _booklet: [
            for (final q in list)
              if (q.subject != s.code) q,
            if (anyKey || ord.isNotEmpty) ...rows,
          ],
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exam;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<String>(
          segments: [
            for (final b in bookletTypes)
              ButtonSegment(
                value: b,
                label: Text(b == 'A' ? tr('A (tek)') : b),
              ),
          ],
          selected: {_booklet},
          onSelectionChanged: (s) => setState(() => _booklet = s.first),
        ),
        const SizedBox(height: 8),
        Text(
          _booklet == 'A'
              ? tr(
                  'Her ders için cevapları sırayla yaz ya da Excel\'den yapıştır (ör. ABDCE…). Cevapsız soru için "-" yaz; o soru iptal sayılır.',
                )
              : tr(
                  'Bu kitapçığın cevaplarını yaz. Sorular A\'dan farklı sıradaysa "A\'daki karşılığı" alanına sırayla A numaralarını yaz (ör. 5 4 3 2 1); boşsa sıra aynı kabul edilir.',
                ),
          style: text.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final s in e.subjects)
          _KeyField(
            key: ValueKey('key-$_booklet-${s.code}'),
            label:
                '${subjectByCode(s.code).name} (${tr('{n} soru', {'n': s.questionCount})})',
            initialKeys: _keyText(s),
            initialOrder: _booklet == 'A' ? null : _orderText(s),
            count: s.questionCount,
            onKeys: (v) =>
                _booklet == 'A' ? _setA(s, v) : _setBooklet(s, keys: v),
            onOrder: (v) => _setBooklet(s, order: v),
          ),
      ],
    );
  }
}

class _KeyField extends StatefulWidget {
  const _KeyField({
    super.key,
    required this.label,
    required this.initialKeys,
    required this.count,
    required this.onKeys,
    required this.onOrder,
    this.initialOrder,
  });

  final String label;
  final String initialKeys;
  final String? initialOrder;
  final int count;
  final ValueChanged<String> onKeys;
  final ValueChanged<String> onOrder;

  @override
  State<_KeyField> createState() => _KeyFieldState();
}

class _KeyFieldState extends State<_KeyField> {
  late final _keys = TextEditingController(
    text: widget.initialKeys.replaceAll(RegExp(r'-+$'), ''),
  );
  late final _order = TextEditingController(text: widget.initialOrder ?? '');

  @override
  void dispose() {
    _keys.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clean = cleanKeyText(_keys.text);
    final orderBad =
        _order.text.trim().isNotEmpty &&
        parseOrder(_order.text, widget.count) == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _keys,
            maxLines: null,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: widget.label,
              helperText: tr('{n} / {t} cevap', {
                'n': clean.replaceAll('-', '').length,
                't': widget.count,
              }),
              errorText: clean.length > widget.count
                  ? tr('Soru sayısından fazla cevap var; fazlası alınmaz.')
                  : null,
            ),
            onChanged: (v) {
              setState(() {});
              widget.onKeys(v);
            },
          ),
          if (widget.initialOrder != null) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _order,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('A\'daki karşılığı (isteğe bağlı)'),
                errorText: orderBad
                    ? tr('1-{n} arası her numara bir kez yazılmalı.', {
                        'n': widget.count,
                      })
                    : null,
              ),
              onChanged: (v) {
                setState(() {});
                if (v.trim().isEmpty || parseOrder(v, widget.count) != null) {
                  widget.onOrder(v);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Kazanımlar: soru → kazanım, zorluk, iptal; toplu atama
// ---------------------------------------------------------------------
class _OutcomeTab extends ConsumerStatefulWidget {
  const _OutcomeTab({required this.exam, required this.onChanged});

  final ExamDefinition exam;
  final ValueChanged<ExamDefinition> onChanged;

  @override
  ConsumerState<_OutcomeTab> createState() => _OutcomeTabState();
}

class _OutcomeTabState extends ConsumerState<_OutcomeTab> {
  late String _subject = widget.exam.subjects.first.code;
  final _selected = <int>{};

  KeyQuestion _q(int n) =>
      widget.exam.question(_subject, n) ??
      KeyQuestion(subject: _subject, number: n);

  void _replace(Iterable<KeyQuestion> changed) {
    final byNo = {for (final q in changed) q.number: q};
    final e = widget.exam;
    widget.onChanged(
      e.copyWith(
        questions: [
          for (final q in e.questions)
            if (q.subject != _subject || !byNo.containsKey(q.number)) q,
          ...byNo.values,
        ],
      ),
    );
  }

  Future<void> _assign(Iterable<int> numbers) async {
    final picked = await pickOutcome(context, subject: _subject);
    if (picked == null) return;
    final tree = ref.read(learningOutcomesProvider).value;
    _replace([
      for (final n in numbers)
        picked.id == null
            ? _q(n).copyWith(clearOutcome: true)
            : _q(n).copyWith(
                outcomeId: picked.id,
                outcome: tree?.label(picked.id!) ?? picked.label,
              ),
    ]);
    setState(_selected.clear);
  }

  Future<void> _range() async {
    final s = widget.exam.subject(_subject)!;
    final from = TextEditingController();
    final to = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.overlayStyle(context),
      builder: (context) => AlertDialog(
        title: Text(tr('Ardışık soruları seç')),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: from,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('İlk soru')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: to,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('Son soru')),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Vazgeç')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Seç')),
          ),
        ],
      ),
    );
    final a = int.tryParse(from.text);
    final b = int.tryParse(to.text);
    from.dispose();
    to.dispose();
    if (ok != true || a == null || b == null) return;
    setState(() {
      for (var n = a < b ? a : b; n <= (a < b ? b : a); n++) {
        if (n >= 1 && n <= s.questionCount) _selected.add(n);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exam;
    if (e.subject(_subject) == null) _subject = e.subjects.first.code;
    final s = e.subject(_subject)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _subject,
                  decoration: InputDecoration(labelText: tr('Ders')),
                  items: [
                    for (final x in e.subjects)
                      DropdownMenuItem(
                        value: x.code,
                        child: Text(subjectByCode(x.code).name),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _subject = v!;
                    _selected.clear();
                  }),
                ),
              ),
              IconButton(
                tooltip: tr('Ardışık soruları seç'),
                onPressed: _range,
                icon: const Icon(Icons.linear_scale_rounded),
              ),
            ],
          ),
        ),
        if (_selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(tr('{n} soru seçili', {'n': _selected.length})),
                ),
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: Text(tr('Temizle')),
                ),
                FilledButton.tonal(
                  key: const ValueKey('assign-outcome'),
                  onPressed: () => _assign(_selected),
                  child: Text(tr('Kazanım ata')),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: s.questionCount,
            itemBuilder: (_, i) {
              final q = _q(i + 1);
              return ListTile(
                key: ValueKey('q-$_subject-${q.number}'),
                dense: true,
                leading: Checkbox(
                  value: _selected.contains(q.number),
                  onChanged: (v) => setState(
                    () => v!
                        ? _selected.add(q.number)
                        : _selected.remove(q.number),
                  ),
                ),
                title: Text(
                  '${q.number}. ${q.isCancelled ? tr('iptal') : q.correct}  ·  ${q.outcome ?? tr('Kazanım seçilmedi')}',
                  style: TextStyle(
                    color: q.outcome == null
                        ? Theme.of(context).hintColor
                        : null,
                    decoration: q.cancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                onTap: () => _assign([q.number]),
                trailing: PopupMenuButton<String>(
                  tooltip: tr('Soru ayarları'),
                  onSelected: (v) => _replace([
                    switch (v) {
                      'cancel' => q.copyWith(cancelled: !q.cancelled),
                      'none' => q.copyWith(clearDifficulty: true),
                      _ => q.copyWith(difficulty: Difficulty.fromDb(v)),
                    },
                  ]),
                  itemBuilder: (_) => [
                    CheckedPopupMenuItem(
                      value: 'cancel',
                      checked: q.cancelled,
                      child: Text(tr('Soruyu iptal et')),
                    ),
                    const PopupMenuDivider(),
                    for (final (v, l) in [
                      ('easy', tr('Kolay')),
                      ('medium', tr('Orta')),
                      ('hard', tr('Zor')),
                      ('none', tr('Zorluk yok')),
                    ])
                      CheckedPopupMenuItem(
                        value: v,
                        checked: (q.difficulty?.db ?? 'none') == v,
                        child: Text(l),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Sonuçlar: Excel yükle, kamerayla oku, yayınla, rapor
// ---------------------------------------------------------------------
/// Yayın öncesi kontrol: öğrenci her sorudaki hatasını ve konusunu görsün diye
/// anahtar ve kazanım tam olmadan yayınlanmaz (sunucu da reddeder).
class _PublishChecklist extends StatelessWidget {
  const _PublishChecklist({required this.exam, required this.gaps});

  final ExamDefinition exam;
  final ExamKeyGaps gaps;

  String _detail(Map<String, List<int>> gaps) => [
    for (final e in gaps.entries)
      '${subjectByCode(e.key).name}: ${e.value.length > 8 ? tr('{n} soru', {'n': e.value.length}) : e.value.join(', ')}',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    Widget row(String key, bool ok, String title, String? detail) => ListTile(
      key: ValueKey(key),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
        color: ok ? b.success : b.danger,
      ),
      title: Text(title),
      subtitle: detail == null ? null : Text(detail),
    );
    return SectionCard(
      title: tr('Yayın kontrolü'),
      subtitle: tr('Üçü de tamam olunca sonuçlar yayınlanır.'),
      child: Column(
        children: [
          row(
            'check-answers',
            gaps.answerCount == 0,
            gaps.answerCount == 0
                ? tr('Cevap anahtarı tam')
                : tr('{n} sorunun cevabı eksik', {'n': gaps.answerCount}),
            gaps.answerCount == 0 ? null : _detail(gaps.noAnswer),
          ),
          row(
            'check-outcomes',
            gaps.outcomeCount == 0,
            gaps.outcomeCount == 0
                ? tr('Bütün soruların kazanımı var')
                : tr('{n} sorunun kazanımı eksik', {'n': gaps.outcomeCount}),
            gaps.outcomeCount == 0 ? null : _detail(gaps.noOutcome),
          ),
          row(
            'check-sheets',
            exam.sheetCount > 0,
            exam.sheetCount > 0
                ? tr('Optik çıktısı yüklendi')
                : tr('Optik çıktısı yüklenmedi'),
            null,
          ),
        ],
      ),
    );
  }
}

class _ResultsTab extends ConsumerWidget {
  const _ResultsTab({
    required this.exam,
    required this.basePath,
    required this.dirty,
    required this.onSave,
    required this.onPublished,
  });

  final ExamDefinition exam;
  final String basePath;
  final bool dirty;
  final Future<String?> Function() onSave;
  final Future<void> Function(String id) onPublished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = exam;
    final hasKey = e.questions.any((q) => !q.isCancelled);
    final gaps = e.keyGaps;
    final text = Theme.of(context).textTheme;
    Future<String?> ready() async {
      if (e.id != null && !dirty) return e.id;
      return onSave();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: e.isDraft ? tr('Taslak') : tr('Yayında'),
          subtitle: e.isDraft
              ? tr(
                  'Yüklenen sonuçları öğrenci ve veli görmez. Kontrol edip yayınlayınca karneler oluşur ve öğrencilere bildirim gider.',
                )
              : tr(
                  'Sonuçlar öğrenci, veli ve koç panellerinde. Anahtarı değiştirip kaydedersen bütün sonuçlar yeniden hesaplanır.',
                ),
          child: Text(
            tr('{n} öğrencinin optiği yüklü', {'n': e.sheetCount}),
            style: text.titleMedium,
          ),
        ),
        const SizedBox(height: 12),
        if (e.isDraft) ...[
          _PublishChecklist(exam: e, gaps: gaps),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          key: const ValueKey('open-import'),
          onPressed: !hasKey
              ? null
              : () async {
                  final id = await ready();
                  if (id == null || !context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ImportWizardScreen(examId: id),
                    ),
                  );
                  await onPublished(id);
                },
          icon: const Icon(Icons.upload_file_rounded),
          label: Text(tr('Optik okuyucu çıktısını yükle')),
        ),
        if (!hasKey)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              tr('Önce cevap anahtarını gir.'),
              style: text.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: e.id == null || dirty
              ? null
              : () => context.push('$basePath/optic/${e.id}'),
          icon: const Icon(Icons.document_scanner_outlined),
          label: Text(tr('Kamerayla optik oku')),
        ),
        const SizedBox(height: 8),
        if (e.isDraft)
          FilledButton.tonalIcon(
            key: const ValueKey('publish-exam'),
            onPressed:
                e.id == null || e.sheetCount == 0 || dirty || !gaps.isComplete
                ? null
                : () async {
                    final ok = await confirm(
                      context,
                      title: tr('Sonuçlar yayınlansın mı?'),
                      message: tr(
                        '{n} öğrencinin karnesi oluşur ve öğrencilere bildirim gider.',
                        {'n': e.sheetCount},
                      ),
                      action: tr('Yayınla'),
                    );
                    if (!ok || !context.mounted) return;
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final n = await ref
                          .read(examAdminRepositoryProvider)
                          .publishExam(e.id!);
                      ref.invalidate(orgExamsProvider);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            tr('{n} öğrencinin sonucu yayınlandı.', {'n': n}),
                          ),
                        ),
                      );
                      await onPublished(e.id!);
                    } catch (err) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            '$err'.contains('EXAM_KEY_INCOMPLETE')
                                ? tr(
                                    'Cevabı ya da kazanımı eksik soru var; önce tamamla.',
                                  )
                                : tr('Yayınlanamadı. Tekrar dene.'),
                          ),
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.campaign_outlined),
            label: Text(tr('Sonuçları yayınla')),
          )
        else
          FilledButton.tonalIcon(
            key: const ValueKey('open-report'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ExamReportScreen(examId: e.id!, title: e.name),
              ),
            ),
            icon: const Icon(Icons.insights_rounded),
            label: Text(tr('Sınıf ve kurum raporu')),
          ),
        if (e.id != null) ...[
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () async {
              final ok = await confirm(
                context,
                title: tr('Sınav silinsin mi?'),
                message: tr(
                  'Cevap anahtarı ve yüklenen optikler silinir. Yayınlanmış sonuçlar öğrencilerin denemelerinde kalır.',
                ),
              );
              if (!ok || !context.mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              final router = GoRouter.of(context);
              try {
                await ref.read(examAdminRepositoryProvider).deleteExam(e.id!);
                ref.invalidate(orgExamsProvider);
                router.pop();
              } catch (_) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      tr('Silinemedi. Sınavı yalnızca ekleyen kişi silebilir.'),
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(tr('Sınavı sil')),
          ),
        ],
      ],
    );
  }
}

/// Müdür / koç ana sayfasındaki giriş kartı.
/// Kurum sınavları kısayolu (yayın bekleyen sonuçlar).
ToolInfo orgExamsTool(WidgetRef ref, String basePath) {
  final drafts = (ref.watch(orgExamsProvider).value ?? const [])
      .where((e) => e.isDraft && e.sheetCount > 0)
      .length;
  return ToolInfo(
    id: 'org-exams-card',
    icon: Icons.fact_check_outlined,
    title: tr('Kurum sınavları'),
    status: drafts > 0
        ? tr('{n} sınavın sonuçları yayın bekliyor', {'n': drafts})
        : tr('Kazanım tablosunu ve optik çıktısını yükle'),
    needsAction: drafts > 0,
    open: (context) => context.push('$basePath/org-exams'),
  );
}

class OrgExamsHomeCard extends ConsumerWidget {
  const OrgExamsHomeCard({super.key, required this.basePath});

  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ToolListCard(tool: orgExamsTool(ref, basePath));
}
