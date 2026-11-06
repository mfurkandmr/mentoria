import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../exam_import/domain/exam_scorer.dart';
import '../data/exam_report_repository.dart';
import '../domain/outcome_analysis.dart';
import 'report_card_pdf.dart';

Future<void> shareReportCards(
  BuildContext context,
  List<ReportCard> cards, {
  required String fileName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final font = Theme.of(context).textTheme.bodyMedium?.fontFamily;
  try {
    final pdf = await renderReportCardsPdf(cards, fontFamily: font);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(pdf, mimeType: 'application/pdf', name: fileName),
        ],
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(tr('Dosya hazırlanamadı. Tekrar dene.'))),
    );
  }
}

/// Öğrencinin kurum sınavı karneleri (öğrenci, veli, koç).
class ReportCardsScreen extends ConsumerWidget {
  const ReportCardsScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(reportCardsProvider(studentId));
    return Scaffold(
      appBar: AppBar(title: Text(tr('Sınav karneleri'))),
      body: AsyncView(
        value: cards,
        onRetry: () => ref.invalidate(reportCardsProvider(studentId)),
        builder: (list) => list.isEmpty
            ? ListView(
                children: [
                  EmptyState(
                    title: tr('Henüz karne yok'),
                    message: tr(
                      'Kurumun optikle okuttuğu sınavların sonuçları yayınlanınca burada görünür.',
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _TrendCard(studentId: studentId),
                  for (final c in list)
                    Card(
                      child: ListTile(
                        key: ValueKey('card-${c.examId}'),
                        title: Text(c.name),
                        subtitle: Text(
                          '${formatShortDate(c.takenOn)} · ${c.examType.label}${c.rankOrg == null ? '' : ' · ${tr('kurumda {n}.', {'n': c.rankOrg})}'}',
                        ),
                        trailing: Text(
                          formatNet(c.totalNet),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ReportCardScreen(examId: c.examId),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Birden çok sınavda ölçülen kazanımların gidişatı.
class _TrendCard extends ConsumerWidget {
  const _TrendCard({required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(outcomeHistoryProvider(studentId)).value;
    if (history == null) return const SizedBox.shrink();
    final trends = outcomeTrends(history);
    final moving = [
      for (final t in trends)
        if (t.direction != TrendDirection.steady) t,
    ];
    if (moving.isEmpty) return const SizedBox.shrink();
    final b = context.brand;
    return SectionCard(
      title: tr('Konularda gidişat'),
      subtitle: tr('Birden çok sınavda ölçülen kazanımlar'),
      child: Column(
        children: [
          for (final t in moving.take(6))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                t.direction == TrendDirection.improving
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: t.direction == TrendDirection.improving
                    ? b.success
                    : b.danger,
              ),
              title: Text('${subjectByCode(t.subject).name} · ${t.outcome}'),
              subtitle: Text(
                t.points.map((p) => '%${formatNet(p.successPct)}').join(' → '),
              ),
            ),
        ],
      ),
    );
  }
}

/// Karne: üstte toplam net, puan ve sıralamalar; ders tablosu, konu analizi
/// ve soru soru inceleme.
class ReportCardScreen extends ConsumerWidget {
  const ReportCardScreen({super.key, required this.examId});

  final String examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(reportCardProvider(examId));
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(card.value?.examName ?? tr('Karne')),
          actions: [
            if (card.value != null)
              IconButton(
                key: const ValueKey('share-card-pdf'),
                tooltip: tr('PDF olarak paylaş'),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: () => shareReportCards(context, [
                  card.value!,
                ], fileName: 'karne.pdf'),
              ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: tr('Özet')),
              Tab(text: tr('Konu analizi')),
              Tab(text: tr('Soru soru')),
            ],
          ),
        ),
        body: AsyncView(
          value: card,
          onRetry: () => ref.invalidate(reportCardProvider(examId)),
          builder: (c) => TabBarView(
            children: [
              _Summary(card: c),
              _Outcomes(card: c),
              _Questions(card: c),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.card});
  final ReportCard card;

  @override
  Widget build(BuildContext context) {
    final c = card;
    final b = context.brand;
    final text = Theme.of(context).textTheme;
    final score = estimatedScore(c);
    Widget tile(String label, String value) => Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              Text(
                value,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(label, style: text.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${formatLongDate(c.takenOn)} · ${c.examType.label}${c.booklet == null ? '' : ' · ${tr('{b} kitapçığı', {'b': c.booklet!})}'}',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            tile(tr('Toplam net'), formatNet(c.totalNet)),
            if (score != null)
              tile(scoreLabel(score.type), score.score.toStringAsFixed(1)),
          ],
        ),
        Row(
          children: [
            tile(tr('Kurum sırası'), rankText(c.rankOrg, c.orgCount)),
            tile(
              c.className == null
                  ? tr('Sınıf sırası')
                  : tr('{c} sırası', {'c': c.className}),
              rankText(c.rankClass, c.classCount),
            ),
          ],
        ),
        if (c.previousTotal != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              tr('Önceki denemede {n} net ({d})', {
                'n': formatNet(c.previousTotal!),
                'd': formatChange(c.totalNet - c.previousTotal!),
              }),
              style: text.bodyMedium?.copyWith(
                color: c.totalNet >= c.previousTotal! ? b.success : b.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              key: const ValueKey('card-subjects'),
              columnSpacing: 18,
              columns: [
                DataColumn(label: Text(tr('Ders'))),
                DataColumn(label: Text(tr('D')), numeric: true),
                DataColumn(label: Text(tr('Y')), numeric: true),
                DataColumn(label: Text(tr('B')), numeric: true),
                DataColumn(label: Text(tr('Net')), numeric: true),
                DataColumn(label: Text(tr('Önceki'))),
                DataColumn(label: Text(tr('Sınıf ort.')), numeric: true),
                DataColumn(label: Text(tr('Kurum ort.')), numeric: true),
              ],
              rows: [
                for (final s in c.subjects)
                  DataRow(
                    cells: [
                      DataCell(Text(subjectByCode(s.subject).name)),
                      DataCell(Text('${s.correct}')),
                      DataCell(Text('${s.wrong}')),
                      DataCell(Text('${s.blank}')),
                      DataCell(
                        Text(
                          formatNet(s.net),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      DataCell(_Arrow(now: s.net, before: s.previousNet)),
                      DataCell(
                        Text(s.classAvg == null ? '—' : formatNet(s.classAvg!)),
                      ),
                      DataCell(
                        Text(s.orgAvg == null ? '—' : formatNet(s.orgAvg!)),
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
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.now, this.before});
  final double now;
  final double? before;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    if (before == null) return const Text('—');
    final up = now > before!;
    final same = now == before;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          same
              ? Icons.remove_rounded
              : up
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
          size: 16,
          color: same ? null : (up ? b.success : b.danger),
          semanticLabel: same
              ? tr('değişmedi')
              : up
              ? tr('yükseldi')
              : tr('düştü'),
        ),
        Text(formatNet(before!)),
      ],
    );
  }
}

class _Outcomes extends StatelessWidget {
  const _Outcomes({required this.card});
  final ReportCard card;

  @override
  Widget build(BuildContext context) {
    final weak = weakestOutcomes(card.outcomes, limit: 5);
    final loss = lostNetMap(card.outcomes);
    final b = context.brand;
    if (card.outcomes.isEmpty) {
      return ListView(
        children: [
          EmptyState(
            title: tr('Kazanım bilgisi yok'),
            message: tr('Bu sınavın sorularına kazanım eşleştirilmemiş.'),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: tr('Zayıf kazanımlar'),
          subtitle: tr('Başarısı en düşük konular'),
          child: Column(
            children: [
              for (final o in weak)
                _OutcomeBar(stat: o, trailing: '%${formatNet(o.successPct)}'),
            ],
          ),
        ),
        SectionCard(
          title: tr('Net kaybı haritası'),
          subtitle: tr(
            'Bu konular düzelince en çok net kazanırsın (yanlış 1 + yanlış katsayısı, boş 1 net).',
          ),
          child: Column(
            children: [
              for (final o in loss)
                _OutcomeBar(
                  key: ValueKey('loss-${o.outcomeKey}'),
                  stat: o,
                  trailing: tr('−{n} net', {'n': formatNet(o.lostNet)}),
                  color: b.danger,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OutcomeBar extends StatelessWidget {
  const _OutcomeBar({
    super.key,
    required this.stat,
    required this.trailing,
    this.color,
  });

  final OutcomeStat stat;
  final String trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${subjectByCode(stat.subject).name} · ${stat.outcome}',
                  style: text.bodyMedium,
                ),
              ),
              Text(
                trailing,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: stat.successPct / 100,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
          Text(
            tr('{c} doğru · {w} yanlış · {b} boş / {q} soru', {
              'c': stat.correct,
              'w': stat.wrong,
              'b': stat.blank,
              'q': stat.questions,
            }),
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Questions extends StatelessWidget {
  const _Questions({required this.card});
  final ReportCard card;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final bySubject = <String, List<QuestionResponse>>{};
    for (final r in card.responses) {
      bySubject.putIfAbsent(r.subject, () => []).add(r);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final e in bySubject.entries)
          SectionCard(
            title: subjectByCode(e.key).name,
            child: Column(
              children: [
                for (final r in e.value)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: switch (r.result) {
                        ResponseResult.correct => b.success,
                        ResponseResult.wrong => b.danger,
                        ResponseResult.blank => Colors.grey,
                        ResponseResult.cancelled => Colors.grey.shade300,
                      },
                      child: Text(
                        '${r.shownNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(switch (r.result) {
                      ResponseResult.cancelled => tr('İptal edilen soru'),
                      ResponseResult.blank => tr('Boş · doğru cevap {c}', {
                        'c': r.correct,
                      }),
                      _ => tr('Senin cevabın {m} · doğru cevap {c}', {
                        'm': r.marked,
                        'c': r.correct,
                      }),
                    }),
                    subtitle: r.outcome == null ? null : Text(r.outcome!),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Denemeler ekranındaki giriş düğmesi.
class ReportCardsButton extends StatelessWidget {
  const ReportCardsButton({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey('open-report-cards'),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportCardsScreen(studentId: studentId),
      ),
    ),
    icon: const Icon(Icons.assignment_outlined),
    label: Text(tr('Kurum sınavı karneleri')),
  );
}
