import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/bizz.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/panel.dart';
import '../../auth/data/auth_repository.dart';
import '../../student/presentation/home_sky.dart';
import '../data/exam.dart';
import '../data/exam_repository.dart';
import 'exam_analysis_view.dart';
import 'exam_detail_sheet.dart';
import 'net_trend_chart.dart';
import '../../../shared/widgets/effects.dart';
import '../../../core/i18n/i18n.dart';

/// Öğrencinin kendi denemeleri (salt okunur; denemeleri koç yükler).
class ExamsScreen extends ConsumerWidget {
  const ExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    return Scaffold(
      appBar: SkyAppBar(
        title: Text(tr('Denemeler')),
        actions: [
          IconButton(
            tooltip: tr('Puan hesapla'),
            icon: const Icon(Icons.calculate_rounded),
            onPressed: () => context.push('/student/score'),
          ),
        ],
      ),
      body: profile == null
          ? const BizzLoader()
          : ExamsView(studentId: profile.id),
    );
  }
}

/// Sınav türü seçici + özet, grafik ve deneme listesi.
///
/// [onAdd] verilirse (koç) boş durumda "Deneme gir" butonu çıkar ve
/// deneme detayında silme açılır.
class ExamsView extends ConsumerStatefulWidget {
  const ExamsView({super.key, required this.studentId, this.onAdd});

  final String studentId;
  final void Function(ExamType type)? onAdd;

  @override
  ConsumerState<ExamsView> createState() => _ExamsViewState();
}

class _ExamsViewState extends ConsumerState<ExamsView> {
  ExamType _type = ExamType.tyt;

  /// Deneme listesi yerine ders ders analiz.
  bool _analysis = false;

  @override
  Widget build(BuildContext context) {
    final provider = examsForStudentProvider(widget.studentId);
    final exams = ref.watch(provider);
    final canManage = widget.onAdd != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<ExamType>(
              showSelectedIcon: false,
              segments: [
                for (final t in ExamType.values)
                  ButtonSegment(value: t, label: Text(t.label)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.list_alt_rounded),
                  label: Text(tr('Sonuçlar')),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.query_stats_rounded),
                  label: Text(tr('Analiz')),
                ),
              ],
              selected: {_analysis},
              onSelectionChanged: (s) => setState(() => _analysis = s.first),
            ),
          ),
        ),
        Expanded(
          child: exams.when(
            loading: () => const BizzLoader(),
            error: (e, _) =>
                _ErrorView(onRetry: () => ref.invalidate(provider)),
            data: (all) {
              final stats = ExamStats(
                all.where((e) => e.examType == _type).toList(),
              );
              if (stats.isEmpty) {
                return _EmptyView(
                  type: _type,
                  onAdd: canManage ? () => widget.onAdd!(_type) : null,
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(provider.future),
                child: _analysis
                    ? ExamAnalysisView(key: ValueKey(_type), exams: stats.exams)
                    : _ExamsList(
                        stats: stats,
                        studentId: widget.studentId,
                        canManage: canManage,
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExamsList extends StatelessWidget {
  const _ExamsList({
    required this.stats,
    required this.studentId,
    required this.canManage,
  });

  final ExamStats stats;
  final String studentId;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final brand = context.brand;
    final recentFirst = stats.exams.reversed.toList();
    final change = stats.lastChange;

    final top = <Widget>[
      StatRow(
        children: [
          GlowStat(
            icon: Icons.insights_rounded,
            label: tr('Son net'),
            value: stats.last!.totalNet,
            format: formatNet,
            // Yön ok ve işaretle de yazılır; yalnızca renge dayanmaz.
            caption: change == null
                ? null
                : '${change >= 0 ? '↑' : '↓'} ${formatChange(change)}',
            color: brand.primary,
          ),
          GlowStat(
            icon: Icons.functions_rounded,
            label: tr('Son 5 ort.'),
            value: stats.recentAverage!,
            format: formatNet,
            color: brand.secondary,
          ),
          GlowStat(
            icon: Icons.emoji_events_rounded,
            label: tr('En iyi'),
            value: stats.best!,
            format: formatNet,
            color: brand.success,
          ),
        ],
      ),
      if (stats.exams.length >= 2)
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 22, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    tr('Toplam net gelişimi'),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(height: 190, child: NetTrendChart(exams: stats.exams)),
              ],
            ),
          ),
        ),
      if (stats.exams.length >= 2) _SubjectTrendCard(exams: stats.exams),
      _SubjectAveragesCard(averages: stats.recentSubjectAverages()),
      PanelSectionTitle(
        title: tr('Tüm denemeler'),
        subtitle: tr('{n} deneme', {'n': stats.exams.length}),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        for (final (i, c) in top.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          staggered(i, c),
        ],
        const SizedBox(height: 8),
        for (final exam in recentFirst)
          _ExamTile(
            exam: exam,
            change: stats.changeFor(exam),
            studentId: studentId,
            canManage: canManage,
          ),
      ],
    );
  }
}

/// Artış/azalış: renk + ok ikonu + işaretli sayı (yalnızca renge dayanmaz).
class _ChangeLabel extends StatelessWidget {
  const _ChangeLabel({required this.change});

  final double change;

  @override
  Widget build(BuildContext context) {
    final up = change >= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 14,
          color: up ? context.brand.success : context.brand.danger,
        ),
        const SizedBox(width: 2),
        Text(
          formatChange(change),
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _SubjectAveragesCard extends StatelessWidget {
  const _SubjectAveragesCard({required this.averages});

  final Map<String, double> averages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final track = theme.colorScheme.onSurface.withValues(alpha: 0.08);
    final entries = averages.entries.toList()
      ..sort(
        (a, b) => examSubjects
            .indexWhere((s) => s.code == a.key)
            .compareTo(examSubjects.indexWhere((s) => s.code == b.key)),
      );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Ders bazlı ortalama'),
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(tr('Son 5 deneme'), style: text.bodySmall),
            const SizedBox(height: 12),
            for (final e in entries) ...[
              _SubjectBar(
                name: subjectByCode(e.key).name,
                net: e.value,
                max: subjectByCode(e.key).questionCount,
                track: track,
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubjectBar extends StatelessWidget {
  const _SubjectBar({
    required this.name,
    required this.net,
    required this.max,
    required this.track,
  });

  final String name;
  final double net;
  final int max;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ratio = (net / max).clamp(0.0, 1.0);
    return Semantics(
      label: tr('{name}: ortalama {p0} net, {max} soruda', {
        'name': name,
        'p0': formatNet(net),
        'max': max,
      }),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: text.bodyMedium)),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: formatNet(net),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: ' / $max', style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AnimatedLinearProgress(
              value: ratio,
              minHeight: 8,
              backgroundColor: track,
              color: context.brand.primaryDeep,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamTile extends StatelessWidget {
  const _ExamTile({
    required this.exam,
    required this.studentId,
    required this.canManage,
    this.change,
  });

  final Exam exam;
  final String studentId;
  final bool canManage;
  final double? change;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subtitle = [
      formatLongDate(exam.takenOn),
      if (exam.field != null) exam.field!.label,
      if (exam.publisher?.isNotEmpty ?? false) exam.publisher!,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          // Alt menünün üstünde açılsın (sekme içi gezgin değil).
          useRootNavigator: true,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => ExamDetailSheet(
            exam: exam,
            studentId: studentId,
            canDelete: canManage,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.name,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: text.bodySmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${formatNet(exam.totalNet)} net',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (change != null) _ChangeLabel(change: change!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.type, this.onAdd});

  final ExamType type;

  /// Yalnızca koç için; öğrencide null.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isCoach = onAdd != null;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Bizz(size: 130),
            const SizedBox(height: 16),
            Text(
              isCoach
                  ? tr('Henüz {p0} denemesi yok', {'p0': type.label})
                  : tr('Henüz {p0} denemen yok', {'p0': type.label}),
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              isCoach
                  ? tr('Deneme sonuçlarını girdikçe gelişim burada görünecek.')
                  : tr(
                      'Koçun deneme sonuçlarını yükledikçe netlerinin nasıl yükseldiğini burada göreceksin.',
                    ),
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            if (isCoach) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(tr('{p0} denemesi gir', {'p0': type.label})),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('Denemeler yüklenemedi. İnternet bağlantını kontrol et.'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: Text(tr('Tekrar dene'))),
          ],
        ),
      ),
    );
  }
}

/// Seçilen dersin denemeden denemeye net gelişimi.
class _SubjectTrendCard extends StatefulWidget {
  const _SubjectTrendCard({required this.exams});

  /// Eskiden yeniye.
  final List<Exam> exams;

  @override
  State<_SubjectTrendCard> createState() => _SubjectTrendCardState();
}

class _SubjectTrendCardState extends State<_SubjectTrendCard> {
  String? _code;

  @override
  Widget build(BuildContext context) {
    final codes =
        <String>{
          for (final e in widget.exams)
            for (final r in e.results) r.code,
        }.toList()..sort(
          (a, b) => examSubjects
              .indexWhere((s) => s.code == a)
              .compareTo(examSubjects.indexWhere((s) => s.code == b)),
        );
    if (codes.isEmpty) return const SizedBox.shrink();
    final code = codes.contains(_code) ? _code! : codes.first;

    double? netOf(Exam e) =>
        e.results.where((r) => r.code == code).firstOrNull?.net;
    final count = widget.exams.where((e) => netOf(e) != null).length;
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 22, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('Ders bazlı gelişim'),
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: code,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final c in codes)
                        DropdownMenuItem(
                          value: c,
                          child: Text(subjectByCode(c).name),
                        ),
                    ],
                    onChanged: (v) => setState(() => _code = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 170,
              child: count < 2
                  ? Center(
                      child: Text(
                        tr('Bu ders için en az 2 deneme gerekiyor.'),
                        style: text.bodySmall,
                      ),
                    )
                  : NetTrendChart(
                      key: ValueKey(code),
                      exams: widget.exams,
                      valueOf: netOf,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
