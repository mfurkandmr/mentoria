import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/bizz.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../auth/data/auth_repository.dart';
import '../data/assignment_repository.dart';
import 'assignment_widgets.dart';

/// Öğrencinin tüm ödevleri: devam edenler üstte, bitenler altta.
class StudentHomeworkScreen extends ConsumerWidget {
  const StudentHomeworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentProfileProvider).value?.id;
    if (uid == null) return const Scaffold(body: Center(child: BizzLoader()));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Ödevlerim'))),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(assignmentsProvider(uid).future),
        child: AsyncView(
          value: ref.watch(assignmentsProvider(uid)),
          onRetry: () => ref.invalidate(assignmentsProvider(uid)),
          builder: (all) {
            if (all.isEmpty) {
              return ListView(
                children: [
                  EmptyState(
                    title: tr('Henüz ödevin yok'),
                    message: tr('Koçun ödev gönderdiğinde burada göreceksin.'),
                  ),
                ],
              );
            }
            final active = all.where((a) => !a.isComplete).toList();
            final done = all.where((a) => a.isComplete).toList();
            Widget card(int i, Assignment a) => FadeSlideIn(
              delay: FadeSlideIn.stagger(i.clamp(0, 8), 60),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AssignmentCard(
                  assignment: a,
                  studentId: uid,
                  viewer: AssignmentViewer.student,
                  initiallyExpanded: !a.isComplete,
                ),
              ),
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (active.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        const Bizz(size: 56, mood: BizzMood.happy),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tr('Bütün ödevlerin bitti, süpersin! 🎉'),
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final (i, a) in active.indexed) card(i, a),
                if (done.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                    child: Text(
                      tr('Tamamlananlar ({n})', {'n': done.length}),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  for (final (i, a) in done.indexed) card(active.length + i, a),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
