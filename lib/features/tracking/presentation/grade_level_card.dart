import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/grade_levels.dart';
import '../../../core/design/motion.dart';
import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../data/tracking_repository.dart';

/// Öğrencinin sınıfı; dokununca değiştirilir (öğrenci kendisi ya da koçu /
/// müdürü). Konu listeleri buna göre süzülür (NOTLAR §91).
class GradeLevelCard extends ConsumerWidget {
  const GradeLevelCard({super.key, required this.studentId, this.self = true});

  final String studentId;

  /// Öğrencinin kendi profili mi (metin "Sınıfın" / "Sınıfı").
  final bool self;

  Future<void> _pick(BuildContext context, WidgetRef ref, int? current) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      sheetAnimationStyle: AppMotion.overlayStyle(context),
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final g in gradeLevels)
              ListTile(
                key: ValueKey('grade-$g'),
                title: Text(gradeLabel(g)),
                trailing: g == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, g),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == current) return;
    try {
      await ref
          .read(trackingRepositoryProvider)
          .setGradeLevel(studentId, picked);
      ref.invalidate(studentGradeProvider(studentId));
      if (context.mounted) {
        showMessage(
          context,
          tr('Sınıf {grade} olarak kaydedildi. Konular buna göre listelenir.', {
            'grade': gradeLabel(picked),
          }),
        );
      }
    } catch (_) {
      if (context.mounted) showMessage(context, tr('Kaydedilemedi.'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grade = ref.watch(studentGradeProvider(studentId)).value;
    return Card(
      child: ListTile(
        key: const ValueKey('grade-level-card'),
        leading: const Icon(Icons.school_outlined),
        title: Text(self ? tr('Sınıfın') : tr('Sınıfı')),
        subtitle: Text(
          grade == null
              ? tr('Seçilmedi · bütün konular görünür')
              : gradeLabel(grade),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _pick(context, ref, grade),
      ),
    );
  }
}

/// Öğrencinin müfredatı (Maarif Modeli / eski müfredat); dokununca değiştirilir
/// (öğrenci kendisi ya da koçu / müdürü). Konu listeleri buna göre gelir
/// (NOTLAR §104). Seçilmediyse sınıftan türetilir: 9-11 Maarif, 12 / mezun eski.
class CurriculumCard extends ConsumerWidget {
  const CurriculumCard({super.key, required this.studentId, this.self = true});

  final String studentId;
  final bool self;

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    String? chosen,
    String derived,
  ) async {
    // Boş seçim "sınıfıma göre" demektir.
    const auto = '';
    final picked = await showModalBottomSheet<String>(
      context: context,
      sheetAnimationStyle: AppMotion.overlayStyle(context),
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('curriculum-auto'),
              title: Text(tr('Sınıfa göre otomatik')),
              subtitle: Text(
                tr('Şu an: {name}', {'name': curriculumLabel(derived)}),
              ),
              trailing: chosen == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, auto),
            ),
            for (final c in [curriculumMaarif, curriculumEski])
              ListTile(
                key: ValueKey('curriculum-$c'),
                title: Text(curriculumLabel(c)),
                trailing: c == chosen ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, c),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final value = picked.isEmpty ? null : picked;
    if (value == chosen) return;
    try {
      await ref
          .read(trackingRepositoryProvider)
          .setCurriculum(studentId, value);
      ref.invalidate(studentCurriculumRawProvider(studentId));
      if (context.mounted) {
        showMessage(
          context,
          tr('Müfredat kaydedildi. Konular buna göre listelenir.'),
        );
      }
    } catch (_) {
      if (context.mounted) showMessage(context, tr('Kaydedilemedi.'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grade = ref.watch(studentGradeProvider(studentId)).value;
    final chosen = ref.watch(studentCurriculumRawProvider(studentId)).value;
    final derived = defaultCurriculum(grade);
    final effective = effectiveCurriculum(grade, chosen);
    return Card(
      child: ListTile(
        key: const ValueKey('curriculum-card'),
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(self ? tr('Müfredatın') : tr('Müfredatı')),
        subtitle: Text(
          chosen == null
              ? tr('{name} · sınıfa göre otomatik', {
                  'name': curriculumLabel(effective),
                })
              : curriculumLabel(effective),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _pick(context, ref, chosen, derived),
      ),
    );
  }
}
