import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/effects.dart';
import '../../auth/data/auth_repository.dart';
import '../../student/presentation/home_sky.dart';
import 'mistake_widgets.dart';

/// Öğrencinin hata defteri (`/student/mistakes`).
class MistakesScreen extends ConsumerWidget {
  const MistakesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(currentProfileProvider).value?.id;
    return Scaffold(
      appBar: SkyAppBar(title: Text(tr('Hata Defteri'))),
      floatingActionButton: id == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showAddMistakeSheet(context, id),
              icon: const Icon(Icons.add_a_photo_rounded),
              label: Text(tr('Hata ekle')),
            ),
      body: id == null
          ? const Center(child: BizzLoader())
          : MistakesView(studentId: id),
    );
  }
}
