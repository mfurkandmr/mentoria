import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/effects.dart';
import '../../../shared/widgets/panel.dart';
import '../../student/presentation/home_sky.dart';
import '../../tracking/presentation/study_view.dart';
import '../data/coach_repository.dart';

export '../../../shared/widgets/panel.dart';

/// Koç ve kurum müdürü panellerinin ortak parçaları. Öğrenci paneliyle aynı
/// görsel dil: canlı gökyüzü başlığı ve konuşan Bızz, renkli özet kutuları,
/// süzülerek gelen kartlar.

const _skyHeaderHeight = 250.0;

/// Gökyüzü başlıklı, kaydırınca daralan üst çubuk (öğrenci ana sayfasındakiyle
/// aynı). [CustomScrollView] içinde ilk sliver olarak kullanılır.
class ManagerSkyAppBar extends StatelessWidget {
  const ManagerSkyAppBar({
    super.key,
    required this.firstName,
    required this.lines,
    this.actions = const [],
  });

  final String firstName;

  /// Bızz'ın söyleyecekleri (dokundukça sıradakine geçer).
  final List<String> lines;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final phase = DayPhase.of(DateTime.now());
    return SliverAppBar(
      pinned: true,
      expandedHeight: _skyHeaderHeight,
      backgroundColor: phase.sky.first,
      foregroundColor: phase.ink,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: phase.ink == Colors.white
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      actions: actions,
      flexibleSpace: LayoutBuilder(
        builder: (context, c) {
          final top = MediaQuery.paddingOf(context).top;
          final min = kToolbarHeight + top;
          final open =
              ((c.maxHeight - min) / (_skyHeaderHeight - kToolbarHeight)).clamp(
                0.0,
                1.0,
              );
          return Stack(
            fit: StackFit.expand,
            children: [
              SkyHeader(
                firstName: firstName,
                lines: lines.isEmpty ? [''] : lines,
                phase: phase,
                contentOpacity: Curves.easeIn.transform(open),
              ),
              Positioned(
                left: 16,
                top: top,
                height: kToolbarHeight,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 1 - open,
                    child: const Center(
                      child: BrandLogo(fontSize: 22, onDark: true),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bızz'ın koç / müdür paneline göre söyleyecekleri.
List<String> managerBizzLines(List<StudentSummary> students) {
  if (students.isEmpty) {
    return [tr('Hadi ilk öğrencini davet edelim! 🐝')];
  }
  final week = students.fold<int>(0, (a, s) => a + s.weekQuestions);
  final pending = students.fold<int>(0, (a, s) => a + s.pendingTasks);
  final inactive = students.where((s) => !s.activeThisWeek).length;
  final star = students.reduce(
    (a, b) => b.weekQuestions > a.weekQuestions ? b : a,
  );
  return [
    tr('Bu hafta öğrencilerin {n} soru çözdü 🐝', {'n': week}),
    if (star.weekQuestions > 0)
      tr('{name} bu haftanın yıldızı: {n} soru! ⭐', {
        'name': star.fullName.split(' ').first,
        'n': star.weekQuestions,
      }),
    if (inactive > 0)
      tr('{n} öğrencin bu hafta hiç çalışmadı. Bir not bıraksan?', {
        'n': inactive,
      })
    else
      tr('Herkes bu hafta çalışmış, süper takım! 🎉'),
    if (pending > 0) tr('{n} görev öğrencilerinde bekliyor.', {'n': pending}),
  ];
}

/// Öğrenci kartı (koç listesi, müdürün öğrenci sekmesi, hareketsizler).
/// Renkli baş harf rozeti ve "bu hafta aktif" noktası, son deneme, haftalık
/// soru/süre hapları ve sınıfın en çalışkanına göre haftalık ilerleme çubuğu.
class StudentCard extends StatelessWidget {
  const StudentCard({
    super.key,
    required this.student,
    required this.onTap,
    this.maxWeekQuestions = 0,
    this.showCoach = false,
    this.trailing,
    this.deletionRequested = false,
  });

  final StudentSummary student;

  /// Öğrenci hesabının silinmesini istedi (koç/müdür sonuçlandırmalı;
  /// 29 günde sonuçlanmazsa sunucu siler).
  final bool deletionRequested;
  final VoidCallback onTap;

  /// Listedeki en yüksek haftalık soru sayısı (ilerleme çubuğu ölçeği).
  final int maxWeekQuestions;

  /// Müdür görünümü: koçun adı da yazılır.
  final bool showCoach;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = student;
    final brand = context.brand;
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);
    final ratio = maxWeekQuestions <= 0
        ? 0.0
        : (s.weekQuestions / maxWeekQuestions).clamp(0.0, 1.0);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialsAvatar(name: s.fullName, active: s.activeThisWeek),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.lastTotalNet == null
                              ? tr('Henüz deneme yok')
                              : tr('{p0} · {p1} net · {p2}', {
                                  'p0': s.lastExamType!.label,
                                  'p1': formatNet(s.lastTotalNet!),
                                  'p2': formatShortDate(s.lastTakenOn!),
                                }),
                          style: text.bodySmall?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                  _NumberChip(number: s.studentNumber),
                  trailing ?? const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (deletionRequested)
                    InfoPill(
                      icon: Icons.person_remove_outlined,
                      text: tr('Silme talebi'),
                      color: brand.danger,
                    ),
                  InfoPill(
                    icon: Icons.edit_note_rounded,
                    text: tr('{n} soru', {'n': s.weekQuestions}),
                    color: s.weekQuestions > 0 ? brand.secondary : null,
                  ),
                  InfoPill(
                    icon: Icons.timer_outlined,
                    text: formatMinutes(s.weekMinutes),
                  ),
                  if (s.pendingTasks > 0)
                    InfoPill(
                      icon: Icons.assignment_late_outlined,
                      text: tr('{n} görev bekliyor', {'n': s.pendingTasks}),
                      color: brand.primaryDeep,
                    ),
                  if (showCoach)
                    InfoPill(
                      icon: Icons.person_outline,
                      text: tr('Koç: {p0}', {'p0': s.coachName ?? '—'}),
                    ),
                  if (!s.activeThisWeek)
                    InfoPill(
                      icon: Icons.bedtime_outlined,
                      text: tr('Bu hafta hareketsiz'),
                      color: brand.danger,
                    ),
                ],
              ),
              if (maxWeekQuestions > 0) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: AnimatedLinearProgress(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.07),
                      color: brand.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberChip extends StatelessWidget {
  const _NumberChip({required this.number});

  final String? number;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.labelSmall;
    if (number == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 14, color: context.brand.primaryDeep),
          const SizedBox(width: 2),
          Text(tr('No yok'), style: text),
        ],
      );
    }
    return Text(
      tr('No: {number}', {'number': number}),
      style: text?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
