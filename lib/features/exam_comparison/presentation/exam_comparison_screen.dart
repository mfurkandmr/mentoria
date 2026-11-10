import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart' show DateFormat;
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../exams/data/exam.dart';
import '../../exams/data/exam_repository.dart';
import '../../optic/data/optic_repository.dart';
import '../../schedule_generator/presentation/schedule_export.dart'
    show jpegPagesToPdf;
import '../domain/exam_comparator.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/effects.dart';
import '../../../core/design/motion.dart';

/// Karşılaştırma sütun renkleri (sabit kategorik palet).
const _colors = [
  Color(0xFF4C7BF3),
  Color(0xFFE5674A),
  Color(0xFF2EA37A),
  Color(0xFF9B5DE5),
];

String _day(DateTime d) => DateFormat('d MMM', localeTag).format(d);

String _examLabel(Exam e) =>
    [e.publisher, e.name].whereType<String>().where((s) => s.isNotEmpty).first;

/// Denemeleri yan yana karşılaştırma (öğrenci, koç, müdür; velide salt
/// okunur). 2-4 deneme tablo, 5 ve üzeri özet.
class ExamComparisonScreen extends ConsumerStatefulWidget {
  const ExamComparisonScreen({super.key, required this.studentId});

  final String studentId;

  @override
  ConsumerState<ExamComparisonScreen> createState() =>
      _ExamComparisonScreenState();
}

class _ExamComparisonScreenState extends ConsumerState<ExamComparisonScreen> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final exams = ref.watch(examsForStudentProvider(widget.studentId));
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Deneme karşılaştırma')),
          actions: [
            if (exams.value case final all?)
              if (ComparisonMode.forCount(_selected.length) ==
                  ComparisonMode.table)
                IconButton(
                  tooltip: tr('PDF olarak paylaş'),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: () => _sharePdf(
                    context,
                    ExamComparator.compare([
                      for (final e in all)
                        if (_selected.contains(e.id)) e,
                    ]),
                  ),
                ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: tr('Denemeler')),
              Tab(text: tr('Karşılaştırma')),
              Tab(text: tr('Kazanımlar')),
            ],
          ),
        ),
        body: AsyncView(
          value: exams,
          onRetry: () =>
              ref.invalidate(examsForStudentProvider(widget.studentId)),
          builder: (all) {
            final list = [...all]..sort((a, b) => Exam.byDate(b, a));
            final chosen = [
              for (final e in list)
                if (_selected.contains(e.id)) e,
            ];
            final mode = ComparisonMode.forCount(chosen.length);
            final mixed = ExamComparator.mixed(chosen);
            final notices = [
              if (mode == ComparisonMode.summary)
                _Notice(
                  icon: Icons.info_outline,
                  text: tr(
                    '5 ve üzeri deneme için özet görünümü gösteriliyor.',
                  ),
                ),
              if (mixed)
                _Notice(
                  icon: Icons.warning_amber_rounded,
                  text: tr(
                    'Farklı türde denemeler karşılaştırıyorsun, netler birebir kıyaslanamayabilir.',
                  ),
                ),
            ];
            return TabBarView(
              children: [
                _Picker(
                  exams: list,
                  selected: _selected,
                  notices: notices,
                  onToggle: (id) => setState(
                    () => _selected.contains(id)
                        ? _selected.remove(id)
                        : _selected.add(id),
                  ),
                ),
                switch (mode) {
                  ComparisonMode.tooFew => _Hint(
                    text: tr('Karşılaştırmak için en az 2 deneme seç.'),
                  ),
                  ComparisonMode.table => _TableView(
                    table: ExamComparator.compare(chosen),
                    notices: notices,
                  ),
                  ComparisonMode.summary => _SummaryView(
                    summary: ExamComparator.summarize(chosen),
                    notices: notices,
                  ),
                },
                chosen.length < 2
                    ? _Hint(text: tr('Karşılaştırmak için en az 2 deneme seç.'))
                    : _OutcomesView(exams: chosen),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _sharePdf(BuildContext context, ComparisonTable t) async {
    final messenger = ScaffoldMessenger.of(context);
    final font = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    try {
      final pdf = await renderComparisonPdf(t, fontFamily: font);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              pdf,
              mimeType: 'application/pdf',
              name: 'deneme-karsilastirma.pdf',
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
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: ListTile(dense: true, leading: Icon(icon), title: Text(text)),
  );
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.exams,
    required this.selected,
    required this.notices,
    required this.onToggle,
  });

  final List<Exam> exams;
  final Set<String> selected;
  final List<Widget> notices;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (exams.isEmpty) return _Hint(text: tr('Henüz deneme yok.'));
    final n = selected.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Chip(
                    key: const ValueKey('compare-count'),
                    label: Text(
                      n <= ExamComparator.maxTable
                          ? tr('{n}/4 seçildi', {'n': n})
                          : tr('{n} seçildi · özet', {'n': n}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('2-4 deneme: yan yana'),
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              ...notices,
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
            itemCount: exams.length,
            itemBuilder: (context, i) {
              final e = exams[i];
              return CheckboxListTile(
                key: ValueKey('pick-${e.id}'),
                value: selected.contains(e.id),
                onChanged: (_) => onToggle(e.id),
                title: Text(e.name),
                subtitle: Text(
                  [
                    _day(e.takenOn),
                    if (e.publisher != null && e.publisher!.isNotEmpty)
                      e.publisher!,
                    e.examType.label,
                    tr('{n} net', {'n': formatNet(e.totalNet)}),
                  ].join(' · '),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.table, required this.notices});

  final ComparisonTable table;
  final List<Widget> notices;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final brand = context.brand;
    Widget head(Exam e, int i) => SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, color: _colors[i % 4]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _examLabel(e),
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          Text(
            '${_day(e.takenOn)} · ${e.examType.label}',
            style: text.labelSmall,
          ),
        ],
      ),
    );
    Widget cell(ComparisonRow r, int i) {
      final c = r.cells[i];
      if (c == null) {
        return const SizedBox(width: 110, child: Text('—'));
      }
      final best = r.best == i, worst = r.worst == i;
      return Opacity(
        opacity: worst ? 0.5 : 1,
        child: SizedBox(
          width: 110,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatNet(c.net),
                style: text.titleSmall?.copyWith(
                  fontWeight: best ? FontWeight.w900 : FontWeight.w600,
                  color: best ? brand.success : null,
                ),
              ),
              Text(
                tr('{d}D {y}Y {b}B', {
                  'd': c.correct,
                  'y': c.wrong,
                  'b': c.blank,
                }),
                style: text.labelSmall,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        ...notices,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            key: const ValueKey('compare-table'),
            columnSpacing: 12,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 60,
            columns: [
              DataColumn(label: Text(tr('Ders'))),
              for (final (i, e) in table.exams.indexed)
                DataColumn(label: head(e, i)),
            ],
            rows: [
              for (final r in table.rows)
                DataRow(
                  cells: [
                    DataCell(
                      Text(
                        '${r.code.split('_').first} ${r.name}',
                        style: text.bodyMedium,
                      ),
                    ),
                    for (var i = 0; i < table.exams.length; i++)
                      DataCell(cell(r, i)),
                  ],
                ),
              DataRow(
                color: WidgetStatePropertyAll(
                  brand.primary.withValues(alpha: 0.08),
                ),
                cells: [
                  DataCell(
                    Text(
                      tr('Toplam net'),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  for (var i = 0; i < table.exams.length; i++)
                    DataCell(
                      Text(
                        '${formatNet(table.totals[i])}  ·  ${tr('{n}.', {'n': table.ranks[i]})}',
                        key: ValueKey('total-$i'),
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(tr('Ders bazında net'), style: text.titleSmall),
        const SizedBox(height: 8),
        _SubjectBars(table: table),
        const SizedBox(height: 20),
        Text(tr('Toplam net'), style: text.titleSmall),
        const SizedBox(height: 8),
        _TotalLine(exams: table.exams),
      ],
    );
  }
}

class _SubjectBars extends StatelessWidget {
  const _SubjectBars({required this.table});

  final ComparisonTable table;

  @override
  Widget build(BuildContext context) {
    final rows = table.rows;
    final width = (rows.length * (table.exams.length * 14 + 24)).toDouble();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width < 320 ? 320 : width,
        height: 220,
        child: RevealIn(
          axis: Axis.vertical,
          child: BarChart(
            duration: AppMotion.of(context, AppMotion.base),
            curve: AppMotion.enter,
            BarChartData(
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= rows.length) return const SizedBox();
                      final name = subjectByCode(rows[i].code).name;
                      return Text(
                        name.length > 6 ? name.substring(0, 6) : name,
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (final (i, r) in rows.indexed)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 2,
                    barRods: [
                      for (final (j, c) in r.cells.indexed)
                        BarChartRodData(
                          toY: c == null || c.net < 0 ? 0 : c.net,
                          width: 10,
                          color: _colors[j % 4],
                          borderRadius: BorderRadius.circular(2),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.exams});

  final List<Exam> exams;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return SizedBox(
      height: 200,
      child: RevealIn(
        child: LineChart(
          duration: AppMotion.of(context, AppMotion.base),
          curve: AppMotion.enter,
          LineChartData(
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 36),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 24,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= exams.length || v != i) {
                      return const SizedBox();
                    }
                    return Text(
                      _day(exams[i].takenOn),
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (final (i, e) in exams.indexed)
                    FlSpot(i.toDouble(), e.totalNet),
                ],
                color: brand.primary,
                barWidth: 3,
                dotData: const FlDotData(show: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.summary, required this.notices});

  final ComparisonSummary summary;
  final List<Widget> notices;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final brand = context.brand;
    Widget trend(SubjectTrend t) => ListTile(
      dense: true,
      leading: Icon(
        t.change >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
        color: t.change >= 0
            ? brand.success
            : Theme.of(context).colorScheme.error,
      ),
      title: Text('${t.code.split('_').first} ${t.name}'),
      trailing: Text(
        '${t.change >= 0 ? '+' : ''}${formatNet(t.change)} ${tr('net')}',
        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
    return ListView(
      key: const ValueKey('compare-summary'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        ...notices,
        Text(
          tr('{n} deneme · ortalama {avg} net', {
            'n': summary.exams.length,
            'avg': formatNet(summary.averageTotal),
          }),
          style: text.titleMedium,
        ),
        const SizedBox(height: 8),
        _TotalLine(exams: summary.exams),
        const SizedBox(height: 16),
        Text(tr('En çok gelişen dersler'), style: text.titleSmall),
        if (summary.improving.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(tr('Belirgin bir yükseliş yok.')),
          ),
        for (final t in summary.improving) trend(t),
        const SizedBox(height: 8),
        Text(tr('En çok gerileyen dersler'), style: text.titleSmall),
        if (summary.declining.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(tr('Belirgin bir düşüş yok.')),
          ),
        for (final t in summary.declining) trend(t),
        const SizedBox(height: 8),
        Text(tr('Ders bazında ortalama net'), style: text.titleSmall),
        for (final t in summary.averages)
          ListTile(
            dense: true,
            title: Text('${t.code.split('_').first} ${t.name}'),
            trailing: Text(formatNet(t.average)),
          ),
      ],
    );
  }
}

class _OutcomesView extends ConsumerWidget {
  const _OutcomesView({required this.exams});

  final List<Exam> exams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = <String, List<ExamAnswer>>{};
    var loading = false;
    for (final e in exams) {
      final v = ref.watch(examAnswersProvider(e.id));
      if (v.isLoading) loading = true;
      answers[e.id] = v.value ?? const [];
    }
    if (loading) return const SkeletonList();
    final rows = ExamComparator.outcomes(exams, answers);
    if (rows.isEmpty) {
      return _Hint(
        text: tr(
          'Ortak kazanım bulunamadı. Kazanım karşılaştırması optikle okunan denemelerde yapılır.',
        ),
      );
    }
    final sorted = [...exams]..sort(Exam.byDate);
    final text = Theme.of(context).textTheme;
    final brand = context.brand;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        Text(
          tr('Seçilen denemelerin en az ikisinde ölçülen kazanımlar.'),
          style: text.bodySmall,
        ),
        for (final r in rows)
          Card(
            child: ListTile(
              title: Text(r.label),
              subtitle: Text(
                [
                  subjectByCode(r.subject).name,
                  for (final (i, rate) in r.rates.indexed)
                    '${_examLabel(sorted[i])}: ${rate == null ? '—' : '%${rate.round()}'}',
                ].join(' · '),
              ),
              trailing: r.change == 0
                  ? const Icon(Icons.trending_flat_rounded)
                  : Icon(
                      r.change > 0
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: r.change > 0
                          ? brand.success
                          : Theme.of(context).colorScheme.error,
                    ),
            ),
          ),
      ],
    );
  }
}

/// Karşılaştırma tablosu: A4 yatay tek sayfa PDF.
Future<Uint8List> renderComparisonPdf(
  ComparisonTable t, {
  String? fontFamily,
}) async {
  const w = 1684, h = 1190;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w + 0.0, h + 0.0),
    Paint()..color = Colors.white,
  );
  void text(
    String s,
    Offset at, {
    double size = 20,
    FontWeight weight = FontWeight.w500,
    double width = 300,
    Color color = Colors.black87,
  }) {
    final p = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: width);
    p.paint(canvas, at);
  }

  const margin = 60.0, labelW = 300.0;
  text(
    tr('Deneme karşılaştırma'),
    const Offset(margin, 40),
    size: 40,
    weight: FontWeight.w800,
    width: 1200,
  );
  final colW = (w - 2 * margin - labelW) / t.exams.length;
  final rowH = ((h - 200 - margin) / (t.rows.length + 2)).clamp(30.0, 70.0);
  var y = 130.0;
  for (final (i, e) in t.exams.indexed) {
    text(
      '${_examLabel(e)}\n${_day(e.takenOn)} · ${e.examType.label}',
      Offset(margin + labelW + i * colW, y),
      weight: FontWeight.w800,
      width: colW - 10,
    );
  }
  y += 70;
  final line = Paint()..color = const Color(0xFFDDDDDD);
  for (final r in [...t.rows, null]) {
    canvas.drawLine(Offset(margin, y), Offset(w - margin, y), line);
    text(
      r == null ? tr('Toplam net') : '${r.code.split('_').first} ${r.name}',
      Offset(margin, y + 8),
      weight: r == null ? FontWeight.w800 : FontWeight.w500,
    );
    for (var i = 0; i < t.exams.length; i++) {
      final String v;
      var weight = FontWeight.w500;
      var color = Colors.black87;
      if (r == null) {
        v = '${formatNet(t.totals[i])}  (${t.ranks[i]}.)';
        weight = FontWeight.w800;
      } else {
        final c = r.cells[i];
        v = c == null
            ? '—'
            : '${formatNet(c.net)}   ${c.correct}D ${c.wrong}Y ${c.blank}B';
        if (r.best == i) {
          weight = FontWeight.w800;
          color = const Color(0xFF1E8A5A);
        } else if (r.worst == i) {
          color = Colors.black38;
        }
      }
      text(
        v,
        Offset(margin + labelW + i * colW, y + 8),
        weight: weight,
        color: color,
        width: colW - 10,
      );
    }
    y += rowH;
  }
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  final rgba = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: data!.buffer,
    numChannels: 4,
  );
  return jpegPagesToPdf([
    (img.encodeJpg(rgba, quality: 90), w, h),
  ], landscape: true);
}

/// Denemeler ekranındaki giriş düğmesi.
class CompareExamsButton extends StatelessWidget {
  const CompareExamsButton({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey('open-compare'),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExamComparisonScreen(studentId: studentId),
      ),
    ),
    icon: const Icon(Icons.compare_arrows_rounded),
    label: Text(tr('Denemeleri karşılaştır')),
  );
}
