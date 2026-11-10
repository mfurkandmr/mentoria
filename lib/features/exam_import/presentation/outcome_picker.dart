import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../data/exam_admin_repository.dart';
import '../../../core/design/motion.dart';

/// Seçilen kazanım; [id] `null` ise kazanım kaldırıldı.
class PickedOutcome {
  const PickedOutcome(this.id, this.label);
  final String? id;
  final String label;
}

/// Arama destekli kazanım seçici; havuza yeni konu da eklenebilir.
/// Vazgeçilirse `null`.
Future<PickedOutcome?> pickOutcome(
  BuildContext context, {
  required String subject,
}) => showModalBottomSheet<PickedOutcome>(
  context: context,
  sheetAnimationStyle: AppMotion.overlayStyle(context),
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _OutcomePicker(subject: subject),
);

class _OutcomePicker extends ConsumerStatefulWidget {
  const _OutcomePicker({required this.subject});
  final String subject;

  @override
  ConsumerState<_OutcomePicker> createState() => _OutcomePickerState();
}

class _OutcomePickerState extends ConsumerState<_OutcomePicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _addNew() async {
    final name = _query.text.trim();
    if (name.isEmpty) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final o = await ref
          .read(examAdminRepositoryProvider)
          .addOutcome(subject: widget.subject, name: name);
      ref.invalidate(learningOutcomesProvider);
      nav.pop(PickedOutcome(o.id, o.name));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Bu kazanım havuzda zaten var.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tree = ref.watch(learningOutcomesProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                key: const ValueKey('outcome-search'),
                controller: _query,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: tr('Kazanım ya da kod ara'),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: tree.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    Center(child: Text(tr('Kazanımlar yüklenemedi.'))),
                data: (t) {
                  final list = t.search(widget.subject, _query.text);
                  return ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.block_rounded),
                        title: Text(tr('Kazanımı kaldır')),
                        onTap: () => Navigator.pop(
                          context,
                          const PickedOutcome(null, ''),
                        ),
                      ),
                      if (_query.text.trim().isNotEmpty)
                        ListTile(
                          key: const ValueKey('outcome-add-new'),
                          leading: const Icon(Icons.add_rounded),
                          title: Text(
                            tr('"{name}" havuza ekle ve seç', {
                              'name': _query.text.trim(),
                            }),
                          ),
                          onTap: _addNew,
                        ),
                      for (final o in list)
                        ListTile(
                          key: ValueKey('outcome-${o.id}'),
                          contentPadding: EdgeInsets.only(
                            left: o.parentId == null ? 16 : 40,
                            right: 16,
                          ),
                          title: Text(
                            o.name,
                            style: TextStyle(
                              fontWeight: o.parentId == null
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          subtitle: o.code == null ? null : Text(o.code!),
                          onTap: () => Navigator.pop(
                            context,
                            PickedOutcome(o.id, t.label(o.id)),
                          ),
                        ),
                      if (list.isEmpty && _query.text.trim().isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            tr(
                              'Bu derste kazanım yok. Yukarıya yazıp havuza ekleyebilir ya da Kazanım havuzu ekranından Excel ile yükleyebilirsin.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
