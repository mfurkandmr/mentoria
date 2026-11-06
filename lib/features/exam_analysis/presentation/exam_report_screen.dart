import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../data/exam_report_repository.dart';
import '../data/report_excel.dart';
import '../domain/outcome_analysis.dart';
import 'report_card_screen.dart';

/// Sınıf ve kurum raporu: ortalamalar, ders dağılımı, zayıf kazanımlar,
/// soru zorluğu, sıralama tablosu; Excel ve toplu karne PDF.
class ExamReportScreen extends ConsumerStatefulWidget {
  const ExamReportScreen({
    super.key,
    required this.examId,
    required this.title,
  });

  final String examId;
  final String title;

  @override
  ConsumerState<ExamReportScreen> createState() => _ExamReportScreenState();
}

class _ExamReportScreenState extends ConsumerState<ExamReportScreen> {
  String? _class;
  String? _sortSubject;
  bool _busy = false;

  Future<void> _excel(ExamReport r) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = buildExamReportWorkbook(
        r,
        examName: widget.title,
        classNames: {for (final c in r.classes) c.id: c.name},
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              name: 'sinav-raporu.xlsx',
            ),
          ],
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Dosya hazırlanamadı. Tekrar dene.'))),
      );
    }
  }

  Future<void> _bulkPdf(ExamReport r) async {
    String? classId = _class;
    if (r.classes.isNotEmpty) {
      final picked = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(tr('Hangi sınıfın karneleri?')),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, ''),
              child: Text(tr('Tüm öğrenciler')),
            ),
            for (final c in r.classes)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, c.id),
                child: Text(
                  tr('{c} ({n} öğrenci)', {'c': c.name, 'n': c.students}),
                ),
              ),
          ],
        ),
      );
      if (picked == null) return;
      classId = picked.isEmpty ? null : picked;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final cards = await ref
          .read(examReportRepositoryProvider)
          .fetchCardsForExam(widget.examId, classroomId: classId);
      if (!mounted) return;
      if (cards.isEmpty) {
        showMessage(context, tr('Bu seçimde karne yok.'));
        return;
      }
      await shareReportCards(context, cards, fileName: 'karneler.pdf');
    } catch (_) {
      if (mounted) {
        showMessage(context, tr('Dosya hazırlanamadı. Tekrar dene.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(examReportProvider(widget.examId));
    final r = report.value;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            if (r != null) ...[
              IconButton(
                key: const ValueKey('report-excel'),
                tooltip: tr('Excel olarak paylaş'),
                onPressed: () => _excel(r),
                icon: const Icon(Icons.table_view_outlined),
              ),
              IconButton(
                key: const ValueKey('report-cards-pdf'),
                tooltip: tr('Karneleri PDF olarak al'),
                onPressed: _busy ? null : () => _bulkPdf(r),
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
              ),
            ],
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: tr('Özet')),
              Tab(text: tr('Kazanımlar')),
              Tab(text: tr('Sorular')),
              Tab(text: tr('Sıralama')),
            ],
          ),
        ),
        body: AsyncView(
          value: report,
          onRetry: () => ref.invalidate(examReportProvider(widget.examId)),
          builder: (r) => r.students == 0
              ? ListView(
                  children: [
                    EmptyState(
                      title: tr('Henüz sonuç yok'),
                      message: tr(
                        'Optikleri yükleyip sınavı yayınlayınca rapor oluşur.',
                      ),
                    ),
                  ],
                )
              : TabBarView(
                  children: [
                    _overview(r),
                    _outcomes(r),
                    _questions(r),
                    _ranking(r),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _overview(ExamReport r) {
    final text = Theme.of(context).textTheme;
    final b = context.brand;
    Widget tile(String label, String v) => Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(
                v,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(label, style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            tile(tr('Öğrenci'), '${r.students}'),
            tile(tr('Ortalama'), formatNet(r.avgNet)),
            tile(tr('En yüksek'), formatNet(r.maxNet)),
            tile(tr('En düşük'), formatNet(r.minNet)),
          ],
        ),
        SectionCard(
          title: tr('Ders ortalamaları ve dağılım'),
          child: Column(
            children: [
              for (final s in r.subjects)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${subjectByCode(s.subject).name}: ${formatNet(s.avgNet)} ${tr('net')} (${formatNet(s.avgCorrect)} D · ${formatNet(s.avgWrong)} Y · ${formatNet(s.avgBlank)} B)',
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      _Histogram(data: s.histogram, color: b.primary),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (r.classes.isNotEmpty)
          SectionCard(
            title: tr('Sınıf ortalamaları'),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: [
                  DataColumn(label: Text(tr('Sınıf'))),
                  DataColumn(label: Text(tr('Öğrenci')), numeric: true),
                  DataColumn(label: Text(tr('Toplam')), numeric: true),
                  for (final s in r.subjects)
                    DataColumn(
                      label: Text(subjectByCode(s.subject).name),
                      numeric: true,
                    ),
                ],
                rows: [
                  for (final c in r.classes)
                    DataRow(
                      cells: [
                        DataCell(Text(c.name)),
                        DataCell(Text('${c.students}')),
                        DataCell(Text(formatNet(c.avgNet))),
                        for (final s in r.subjects)
                          DataCell(
                            Text(
                              c.subjects[s.subject] == null
                                  ? '—'
                                  : formatNet(c.subjects[s.subject]!),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _outcomes(ExamReport r) {
    final names = {for (final c in r.classes) c.id: c.name};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: tr('Kurumun en zayıf 10 kazanımı'),
          subtitle: tr('Başarı yüzdesi en düşük konular; tekrar edilmeli.'),
          child: Column(
            children: [for (final o in r.weakOutcomes) _OutcomeRow(stat: o)],
          ),
        ),
        for (final e in r.classOutcomes.entries)
          if (e.value.isNotEmpty)
            SectionCard(
              title: tr('{c}: tekrar edilecek konular', {
                'c': names[e.key] ?? '',
              }),
              child: Column(
                children: [for (final o in e.value) _OutcomeRow(stat: o)],
              ),
            ),
      ],
    );
  }

  Widget _questions(ExamReport r) {
    final b = context.brand;
    final flagged = [
      for (final q in r.questions)
        if (q.suspectKey || q.veryHard) q,
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (flagged.isNotEmpty)
          SectionCard(
            title: tr('Dikkat edilecek sorular'),
            subtitle: tr(
              'Doğru oranı çok düşük ya da başarılı öğrencilerin daha çok yanlış yaptığı sorular: cevap anahtarı hatalı olabilir veya konu hiç anlaşılmamış.',
            ),
            child: Column(
              children: [
                for (final q in flagged)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      q.suspectKey
                          ? Icons.report_problem_outlined
                          : Icons.help_outline_rounded,
                      color: q.suspectKey ? b.danger : b.secondary,
                    ),
                    title: Text(
                      '${subjectByCode(q.subject).name} ${q.number}. ${tr('soru')} · %${formatNet(q.correctPct)} ${tr('doğru')}',
                    ),
                    subtitle: Text(
                      q.suspectKey
                          ? tr(
                              'Cevap anahtarını kontrol et (anahtar: {k}, en çok işaretlenen yanlış: {w}).',
                              {'k': q.correctAnswer, 'w': q.topWrong ?? '—'},
                            )
                          : tr('Konu anlaşılmamış olabilir: {o}', {
                              'o': q.outcome ?? '—',
                            }),
                    ),
                  ),
              ],
            ),
          ),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 14,
              columns: [
                DataColumn(label: Text(tr('Ders'))),
                DataColumn(label: Text(tr('Soru')), numeric: true),
                DataColumn(label: Text(tr('Cevap'))),
                DataColumn(label: Text(tr('Doğru %')), numeric: true),
                DataColumn(label: Text(tr('Boş %')), numeric: true),
                DataColumn(label: Text(tr('Kazanım'))),
              ],
              rows: [
                for (final q in r.questions)
                  DataRow(
                    cells: [
                      DataCell(Text(subjectByCode(q.subject).name)),
                      DataCell(Text('${q.number}')),
                      DataCell(Text(q.correctAnswer ?? '')),
                      DataCell(Text(formatNet(q.correctPct))),
                      DataCell(Text(formatNet(q.blankPct))),
                      DataCell(Text(q.outcome ?? '')),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _ranking(ExamReport r) {
    final names = {for (final c in r.classes) c.id: c.name};
    final rows = [
      for (final x in r.ranking)
        if (_class == null || x.classroomId == _class) x,
    ];
    if (_sortSubject != null) {
      rows.sort(
        (a, b) => (b.subjects[_sortSubject]?.net ?? -999).compareTo(
          a.subjects[_sortSubject]?.net ?? -999,
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              if (r.classes.isNotEmpty)
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _class,
                    decoration: InputDecoration(labelText: tr('Sınıf')),
                    items: [
                      DropdownMenuItem(value: null, child: Text(tr('Tümü'))),
                      for (final c in r.classes)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _class = v),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _sortSubject,
                  decoration: InputDecoration(labelText: tr('Sırala')),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(tr('Toplam net')),
                    ),
                    for (final s in r.subjects)
                      DropdownMenuItem(
                        value: s.subject,
                        child: Text(subjectByCode(s.subject).name),
                      ),
                  ],
                  onChanged: (v) => setState(() => _sortSubject = v),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                key: const ValueKey('ranking-table'),
                columnSpacing: 14,
                columns: [
                  DataColumn(label: Text(tr('Kurum')), numeric: true),
                  DataColumn(label: Text(tr('Sınıf')), numeric: true),
                  DataColumn(label: Text(tr('Öğrenci'))),
                  for (final s in r.subjects)
                    DataColumn(
                      label: Text(subjectByCode(s.subject).name),
                      numeric: true,
                    ),
                  DataColumn(label: Text(tr('Toplam')), numeric: true),
                ],
                rows: [
                  for (final x in rows)
                    DataRow(
                      onSelectChanged: (_) => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReportCardScreen(examId: x.examId),
                        ),
                      ),
                      cells: [
                        DataCell(Text('${x.rankOrg ?? '—'}')),
                        DataCell(Text('${x.rankClass ?? '—'}')),
                        DataCell(
                          Text(
                            [
                              x.name,
                              if (names[x.classroomId] != null)
                                names[x.classroomId]!,
                            ].join(' · '),
                          ),
                        ),
                        for (final s in r.subjects)
                          DataCell(
                            Text(
                              x.subjects[s.subject] == null
                                  ? '—'
                                  : formatNet(x.subjects[s.subject]!.net),
                            ),
                          ),
                        DataCell(
                          Text(
                            formatNet(x.totalNet),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OutcomeRow extends StatelessWidget {
  const _OutcomeRow({required this.stat});
  final OutcomeStat stat;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text('${subjectByCode(stat.subject).name} · ${stat.outcome}'),
    subtitle: LinearProgressIndicator(
      value: stat.successPct / 100,
      minHeight: 5,
      borderRadius: BorderRadius.circular(4),
    ),
    trailing: Text(
      '%${formatNet(stat.successPct)}\n${tr('−{n} net', {'n': formatNet(stat.lostNet)})}',
      textAlign: TextAlign.end,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}

/// Net dağılımı: 5'er netlik aralıklarda öğrenci sayısı.
class _Histogram extends StatelessWidget {
  const _Histogram({required this.data, required this.color});
  final Map<int, int> data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final keys = data.keys.toList()..sort();
    final max = data.values.reduce((a, b) => a > b ? a : b);
    final text = Theme.of(context).textTheme.labelSmall;
    return SizedBox(
      height: 90,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final k in keys)
            Expanded(
              child: Semantics(
                label: tr('{a}-{b} net: {n} öğrenci', {
                  'a': k,
                  'b': k + 5,
                  'n': data[k],
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${data[k]}', style: text),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: data[k]! / max,
                            widthFactor: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text('$k', style: text),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
