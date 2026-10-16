import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../data/avatar_models.dart';
import '../data/avatar_repository.dart';
import 'student_avatar.dart';

/// Dershanedeki haftalık sıralama (son 7 gün çözülen soru).
/// Sayfa sayfa yüklenir; yalnızca ad + soyadın baş harfi, avatar JSON'u ve
/// puan gelir. Canlı (realtime) dinleme yok; aşağı çekince yenilenir.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  static const pageSize = 20;

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  final _scroll = ScrollController();
  final _entries = <LeaderboardEntry>[];
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(avatarRepositoryProvider)
          .fetchLeaderboard(
            limit: LeaderboardScreen.pageSize,
            offset: _entries.length,
          );
      if (!mounted) return;
      setState(() {
        _entries.addAll(page);
        _hasMore = page.length == LeaderboardScreen.pageSize;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _entries.clear();
      _hasMore = true;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Haftanın arıları'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _entries.isEmpty && _loading
            ? const BizzLoader()
            : _entries.isEmpty && _error != null
            ? ListView(
                children: [
                  EmptyState(
                    title: tr('Sıralama yüklenemedi'),
                    message: tr('İnternet bağlantını kontrol edip aşağı çek.'),
                  ),
                ],
              )
            : _entries.isEmpty
            ? ListView(
                children: [
                  EmptyState(
                    title: tr('Henüz sıralama yok'),
                    message: tr('Bu hafta soru çözen ilk arı sen ol!'),
                  ),
                ],
              )
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: _entries.length + 2,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        tr(
                          'Son 7 günde çözülen sorulara göre, dershanendeki öğrenciler.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  }
                  if (i == _entries.length + 1) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: _loading
                            ? const CircularProgressIndicator()
                            : _hasMore
                            ? TextButton(
                                onPressed: _loadMore,
                                child: Text(tr('Daha fazla')),
                              )
                            : const SizedBox.shrink(),
                      ),
                    );
                  }
                  final e = _entries[i - 1];
                  return FadeSlideIn(
                    key: ValueKey(e.studentId),
                    delay: FadeSlideIn.stagger((i - 1).clamp(0, 10), 30),
                    offset: 12,
                    child: _Row(entry: e),
                  );
                },
              ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final brand = context.brand;
    final text = Theme.of(context).textTheme;
    final medal = switch (e.rank) {
      1 => const Color(0xFFFFC531),
      2 => const Color(0xFFB8C2CC),
      3 => const Color(0xFFD08C4A),
      _ => null,
    };
    return Semantics(
      label: tr('{rank}. sıra, {name}, {n} soru', {
        'rank': e.rank,
        'name': e.displayName,
        'n': e.weekQuestions,
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
                child: medal == null
                    ? Text(
                        '${e.rank}',
                        textAlign: TextAlign.center,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : Icon(Icons.emoji_events_rounded, color: medal, size: 28),
              ),
              const SizedBox(width: 8),
              StudentAvatar(
                config: e.avatar,
                reward: AvatarReward.fromRank(e.rewardRank),
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e.isMe
                      ? tr('{name} (sen)', {'name': e.displayName})
                      : e.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(
                    fontWeight: e.isMe ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
              Text(
                tr('{n} soru', {'n': e.weekQuestions}),
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
