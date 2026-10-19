import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../account/data/account_repository.dart';
import '../../avatar/data/avatar_models.dart';
import '../../avatar/presentation/student_avatar.dart';
import '../data/ranking_repository.dart';

/// Kurum içi başarı sıralaması: son 5 denemenin ortalama netine göre.
/// TYT ve AYT (alan alan) ayrı; ilk 3 kürsüde, kalanlar listede.
/// Ödüller (taç, kanatlar) TYT sırasından gelir ve avatarlarda görünür.
class SuccessRankingScreen extends ConsumerStatefulWidget {
  const SuccessRankingScreen({super.key});

  static const pageSize = 50;

  @override
  ConsumerState<SuccessRankingScreen> createState() =>
      _SuccessRankingScreenState();
}

class _SuccessRankingScreenState extends ConsumerState<SuccessRankingScreen> {
  ExamType _type = ExamType.tyt;
  FieldType? _field;
  final _entries = <SuccessRankEntry>[];
  bool _loading = false;
  bool _hasMore = true;
  bool _disabled = false;
  Object? _error;

  /// Seçim değişince eski isteğin sonucu yeni listeye karışmasın.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  /// AYT alanı: seçilmediyse öğrencinin kendi alanı, o da yoksa sayısal.
  FieldType get _effectiveField =>
      _field ?? ref.read(profileDetailsProvider).value?.field ?? FieldType.say;

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final gen = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final type = _type;
      final field = type == ExamType.ayt ? _effectiveField : null;
      final offset = _entries.length;
      final page = await ref.read(successRankingCacheProvider).get(
        (type, field, offset),
        () => ref
            .read(successRankingRepositoryProvider)
            .fetchRanking(
              examType: type,
              field: field,
              limit: SuccessRankingScreen.pageSize,
              offset: offset,
            ),
      );
      if (!mounted || gen != _generation) return;
      setState(() {
        _entries.addAll(page);
        _hasMore = page.length == SuccessRankingScreen.pageSize;
        _loading = false;
        _disabled = false;
      });
    } on RankingDisabledException {
      if (!mounted || gen != _generation) return;
      setState(() {
        _disabled = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _reload() async {
    setState(() {
      _generation++;
      _entries.clear();
      _hasMore = true;
      _loading = false;
    });
    ref.invalidate(successStatusProvider);
    await _loadMore();
  }

  void _select(ExamType type, [FieldType? field]) {
    _type = type;
    if (field != null) _field = field;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(successStatusProvider).value;
    final previewOnly = status != null && !status.enabled && !_disabled;
    final podium = _entries.where((e) => e.rank <= 3).toList();
    final rest = _entries.where((e) => e.rank > 3).toList();

    final header = <Widget>[
      _TypePicker(
        type: _type,
        field: _type == ExamType.ayt ? _effectiveField : null,
        onChanged: _select,
      ),
      const SizedBox(height: 12),
      if (previewOnly) ...[
        Card(
          color: context.brand.secondary.withValues(alpha: 0.18),
          child: ListTile(
            leading: const Icon(Icons.visibility_off_rounded),
            title: Text(tr('Sıralama kapalı')),
            subtitle: Text(
              tr('Bu bir önizleme. Öğrenciler, sen açana kadar göremez.'),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      const _RewardLegend(),
      const SizedBox(height: 16),
    ];

    final Widget body;
    if (_disabled) {
      body = ListView(
        children: [
          EmptyState(
            title: tr('Sıralama kapalı'),
            message: tr(
              'Kurumun başarı sıralamasını açtığında burada göreceksin.',
            ),
          ),
        ],
      );
    } else if (_entries.isEmpty && _loading) {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [...header, const BizzLoader()],
      );
    } else if (_entries.isEmpty) {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ...header,
          _error != null
              ? EmptyState(
                  title: tr('Sıralama yüklenemedi'),
                  message: tr('İnternet bağlantını kontrol edip aşağı çek.'),
                )
              : EmptyState(
                  title: tr('Henüz sıralama yok'),
                  message: tr('Bu türde denemesi olan öğrenci yok.'),
                ),
        ],
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ...header,
          if (podium.isNotEmpty) _Podium(entries: podium),
          const SizedBox(height: 12),
          for (final (i, e) in rest.indexed)
            FadeSlideIn(
              key: ValueKey('${_type.db}-${e.studentId}'),
              delay: FadeSlideIn.stagger(i.clamp(0, 10), 30),
              offset: 12,
              child: _Row(entry: e),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_hasMore)
            Center(
              child: TextButton(
                onPressed: _loadMore,
                child: Text(tr('Daha fazla')),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('Başarı sıralaması'))),
      body: RefreshIndicator(
        onRefresh: () {
          // Aşağı çekince önbellek değil, sunucudaki güncel sıralama.
          ref.read(successRankingCacheProvider).clear();
          return _reload();
        },
        child: body,
      ),
    );
  }
}

class _TypePicker extends StatelessWidget {
  const _TypePicker({
    required this.type,
    required this.field,
    required this.onChanged,
  });

  final ExamType type;
  final FieldType? field;
  final void Function(ExamType type, [FieldType? field]) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ExamType>(
          segments: const [
            ButtonSegment(value: ExamType.tyt, label: Text('TYT')),
            ButtonSegment(value: ExamType.ayt, label: Text('AYT')),
          ],
          selected: {type},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        if (field != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final f in FieldType.values)
                ChoiceChip(
                  label: Text(f.label),
                  selected: f == field,
                  onSelected: (_) => onChanged(ExamType.ayt, f),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(
          tr('Son 5 denemenin ortalama netine göre, kurumundaki öğrenciler.'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Ödüllerin açıklaması: küçük önizlemeleriyle.
class _RewardLegend extends StatelessWidget {
  const _RewardLegend();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget item(String asset, String place, String name) => Expanded(
      child: Column(
        children: [
          SizedBox.square(
            dimension: 44,
            child: SvgPicture.asset(asset, fit: BoxFit.contain),
          ),
          const SizedBox(height: 4),
          Text(
            place,
            style: text.labelMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(name, textAlign: TextAlign.center, style: text.bodySmall),
        ],
      ),
    );
    return SectionCard(
      title: tr('TYT ödülleri'),
      subtitle: tr('Sıranı korudukça avatarında kalır.'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item(
            AvatarReward.king.frontAsset!,
            tr('1.'),
            AvatarReward.king.label,
          ),
          item(
            AvatarReward.gold.backAsset,
            tr('İlk 3'),
            AvatarReward.gold.label,
          ),
          item(
            AvatarReward.silver.backAsset,
            tr('4. ve 5.'),
            AvatarReward.silver.label,
          ),
        ],
      ),
    );
  }
}

/// İlk 3: ortada 1., solda 2., sağda 3. (beraberlikte sıra korunur).
class _Podium extends StatelessWidget {
  const _Podium({required this.entries});

  final List<SuccessRankEntry> entries;

  @override
  Widget build(BuildContext context) {
    final order = switch (entries.length) {
      1 => [entries[0]],
      2 => [entries[1], entries[0]],
      _ => [entries[1], entries[0], entries[2]],
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final e in order)
          Expanded(
            child: FadeSlideIn(
              delay: FadeSlideIn.stagger(e.rank, 90),
              child: _PodiumStep(entry: e, first: identical(e, entries[0])),
            ),
          ),
      ],
    );
  }
}

class _PodiumStep extends StatelessWidget {
  const _PodiumStep({required this.entry, required this.first});

  final SuccessRankEntry entry;
  final bool first;

  static const _colors = [
    Color(0xFFFFC531),
    Color(0xFFB8C2CC),
    Color(0xFFD08C4A),
  ];

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final brand = context.brand;
    final text = Theme.of(context).textTheme;
    final color = _colors[(e.rank - 1).clamp(0, 2)];
    return Semantics(
      label: tr('{rank}. sıra, {name}, {net} net', {
        'rank': e.rank,
        'name': e.displayName,
        'net': formatNet(e.avgNet),
      }),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StudentAvatar(
              config: e.avatar,
              reward: AvatarReward.fromRank(e.rewardRank),
              size: first ? 104 : 80,
            ),
            const SizedBox(height: 6),
            Text(
              e.isMe
                  ? tr('{name} (sen)', {'name': e.displayName})
                  : e.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              tr('{net} net', {'net': formatNet(e.avgNet)}),
              style: text.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: brand.primaryDeep,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: first ? 76 : (e.rank == 2 ? 56 : 42),
              decoration: BoxDecoration(
                color: color.withValues(alpha: e.isMe ? 1 : 0.85),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                border: e.isMe
                    ? Border.all(color: brand.primaryDeep, width: 3)
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '${e.rank}',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF2B2350),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});

  final SuccessRankEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final brand = context.brand;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: tr('{rank}. sıra, {name}, {net} net', {
        'rank': e.rank,
        'name': e.displayName,
        'net': formatNet(e.avgNet),
      }),
      excludeSemantics: true,
      child: Card(
        color: e.isMe ? brand.primary.withValues(alpha: 0.18) : null,
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '${e.rank}',
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StudentAvatar(
                config: e.avatar,
                reward: AvatarReward.fromRank(e.rewardRank),
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.isMe
                          ? tr('{name} (sen)', {'name': e.displayName})
                          : e.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        fontWeight: e.isMe ? FontWeight.w900 : FontWeight.w700,
                      ),
                    ),
                    Text(
                      tr('{n} deneme', {'n': e.examCount}),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                tr('{net} net', {'net': formatNet(e.avgNet)}),
                style: text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: brand.primaryDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
