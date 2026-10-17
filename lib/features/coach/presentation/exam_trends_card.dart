import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../data/exam_trends.dart';

String _net(double v) =>
    v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2).replaceAll('.', ',');

/// Koç ve müdür ana sayfası: son 5 denemede en çok yükselen ve en çok düşen
/// 5 öğrenci. Öğrenciye dokununca detayı açılır.
class ExamTrendsCard extends ConsumerStatefulWidget {
  const ExamTrendsCard({super.key, required this.basePath});

  /// `/coach` ya da `/admin`.
  final String basePath;

  @override
  ConsumerState<ExamTrendsCard> createState() => _ExamTrendsCardState();
}

class _ExamTrendsCardState extends ConsumerState<ExamTrendsCard> {
  ExamType _type = ExamType.tyt;

  @override
  Widget build(BuildContext context) {
    final trends = ref.watch(examTrendsProvider(_type));
    final brand = context.brand;
    return SectionCard(
      title: tr('Son 5 denemede değişim'),
      subtitle: tr('İlk ve son denemenin toplam neti karşılaştırılır'),
      trailing: SegmentedButton<ExamType>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          for (final t in const [ExamType.tyt, ExamType.ayt])
            ButtonSegment(value: t, label: Text(t.label)),
        ],
        selected: {_type},
        onSelectionChanged: (s) => setState(() => _type = s.first),
      ),
      child: trends.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => TextButton(
          onPressed: () => ref.invalidate(examTrendsProvider(_type)),
          child: Text(tr('Tekrar dene')),
        ),
        data: (all) {
          final m = topMovers(all);
          if (m.rising.isEmpty && m.falling.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                tr(
                  'Karşılaştırmak için en az 2 {type} denemesi olan öğrenci yok.',
                  {'type': _type.label},
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Group(
                title: tr('En çok yükselen'),
                icon: Icons.trending_up_rounded,
                color: brand.success,
                items: m.rising,
                empty: tr('Yükselen öğrenci yok.'),
                basePath: widget.basePath,
              ),
              const SizedBox(height: 12),
              _Group(
                title: tr('En çok düşen'),
                icon: Icons.trending_down_rounded,
                color: brand.danger,
                items: m.falling,
                empty: tr('Düşen öğrenci yok. 🎉'),
                basePath: widget.basePath,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.empty,
    required this.basePath,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<ExamTrend> items;
  final String empty;
  final String basePath;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
      const SizedBox(height: 4),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 26, top: 2),
          child: Text(empty, style: Theme.of(context).textTheme.bodySmall),
        ),
      for (final (i, t) in items.indexed)
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('$basePath/students/${t.studentId}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${i + 1}.',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        tr('{a} → {b} net · {n} deneme', {
                          'a': _net(t.firstNet),
                          'b': _net(t.lastNet),
                          'n': t.examCount,
                        }),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${t.delta > 0 ? '+' : '−'}${_net(t.delta.abs())}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
