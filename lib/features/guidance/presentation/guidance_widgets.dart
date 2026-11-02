import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/profile.dart';
import '../data/guidance_repository.dart';

/// Öğrencinin rehberlik görüşme geçmişi, zaman çizelgesi olarak (en yeni
/// üstte). Koç ve müdür görür; öğrenci ve veli görmez.
class GuidanceTimeline extends ConsumerWidget {
  const GuidanceTimeline({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(guidanceLogsProvider(studentId));
    final me = ref.watch(currentProfileProvider).value;
    return AsyncView(
      value: logs,
      onRetry: () => ref.invalidate(guidanceLogsProvider(studentId)),
      builder: (list) => RefreshIndicator(
        onRefresh: () => ref.refresh(guidanceLogsProvider(studentId).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Text(
              tr(
                'Kurum içi kayıt: öğrenci ve veli görmez. Koç değişse de geçmiş kurumda kalır.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              EmptyState(
                title: tr('Henüz görüşme kaydı yok'),
                message: tr(
                  'Her görüşmeden sonra "Görüşme kaydı"na dokun; 2 dakikada not bırak.',
                ),
                bizzSize: 90,
              )
            else
              for (final (i, log) in list.indexed)
                _TimelineEntry(
                  log: log,
                  isLast: i == list.length - 1,
                  canDelete:
                      me != null &&
                      log.deletableBy(
                        me.id,
                        isAdmin: me.role == UserRole.admin,
                      ),
                  onDelete: () => _delete(context, ref, log),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    GuidanceLog log,
  ) async {
    final ok = await confirm(
      context,
      title: tr('Kayıt silinsin mi?'),
      message: tr('Bu görüşme kaydı kalıcı olarak silinir.'),
      action: tr('Sil'),
    );
    if (!ok) return;
    try {
      await ref.read(guidanceRepositoryProvider).delete(log.id);
    } catch (_) {
      if (context.mounted) showMessage(context, tr('Silinemedi. Tekrar dene.'));
    }
    ref.invalidate(guidanceLogsProvider(studentId));
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.log,
    required this.isLast,
    required this.canDelete,
    required this.onDelete,
  });

  final GuidanceLog log;
  final bool isLast;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.65);
    final day = DateFormat('d MMMM yyyy, EEEE', localeTag);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Zaman çizgisi: nokta ve alttaki çizgi.
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: log.kind == GuidanceKind.parent
                        ? brand.secondary
                        : brand.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: brand.primary.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(top: 6, bottom: 6),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            day.format(log.metOn),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (canDelete)
                          IconButton(
                            tooltip: tr('Sil'),
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: onDelete,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Tag(log.kind.label, color: brand.primaryDeep),
                        for (final t in log.topics) _Tag(t.label, color: muted),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(log.note),
                    if (log.nextStep != null) ...[
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${tr('Sonraki adım')}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(text: log.nextStep),
                          ],
                        ),
                      ),
                    ],
                    if (log.followUpOn != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_repeat_rounded,
                              size: 16,
                              color: brand.primaryDeep,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tr('Takip: {date}', {
                                'date': DateFormat(
                                  'd MMMM',
                                  localeTag,
                                ).format(log.followUpOn!),
                              }),
                              style: TextStyle(
                                color: brand.primaryDeep,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      log.authorName.isEmpty
                          ? tr('Yazan bilinmiyor')
                          : '— ${log.authorName}',
                      style: text.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );
}

/// Görüşme kaydı ekleme (2 dakikalık form). Eklendiyse true döner.
Future<bool?> showAddGuidanceSheet(BuildContext context, String studentId) =>
    showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddGuidanceSheet(studentId: studentId),
    );

class _AddGuidanceSheet extends ConsumerStatefulWidget {
  const _AddGuidanceSheet({required this.studentId});
  final String studentId;

  @override
  ConsumerState<_AddGuidanceSheet> createState() => _AddGuidanceSheetState();
}

class _AddGuidanceSheetState extends ConsumerState<_AddGuidanceSheet> {
  late DateTime _metOn = _today();
  GuidanceKind _kind = GuidanceKind.inPerson;
  final _topics = <GuidanceTopic>{};
  final _note = TextEditingController();
  final _next = TextEditingController();
  DateTime? _followUp;
  bool _saving = false;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _note.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final note = _note.text.trim();
    if (note.isEmpty) {
      showMessage(context, tr('Kısa bir not yaz.'));
      return;
    }
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    try {
      await ref
          .read(guidanceRepositoryProvider)
          .add(
            widget.studentId,
            GuidanceDraft(
              metOn: _metOn,
              kind: _kind,
              topics: [
                for (final t in GuidanceTopic.values)
                  if (_topics.contains(t)) t,
              ],
              note: note,
              nextStep: _next.text.trim().isEmpty ? null : _next.text.trim(),
              followUpOn: _followUp,
            ),
          );
      ref.invalidate(guidanceLogsProvider(widget.studentId));
      nav.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMMM yyyy', localeTag);
    final today = _today();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('Görüşme kaydı'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: Text(fmt.format(_metOn)),
                subtitle: Text(tr('Görüşme tarihi')),
                trailing: const Icon(Icons.edit_calendar_rounded),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _metOn,
                    firstDate: today.subtract(const Duration(days: 60)),
                    lastDate: today,
                  );
                  if (d != null && mounted) setState(() => _metOn = d);
                },
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final k in GuidanceKind.values)
                    ChoiceChip(
                      label: Text(k.label),
                      selected: _kind == k,
                      onSelected: (_) => setState(() => _kind = k),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tr('Konular (en çok 5)'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in GuidanceTopic.values)
                    FilterChip(
                      label: Text(t.label),
                      selected: _topics.contains(t),
                      onSelected: (on) => setState(() {
                        if (!on) {
                          _topics.remove(t);
                        } else if (_topics.length < 5) {
                          _topics.add(t);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                minLines: 3,
                maxLines: 8,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: tr('Ne konuşuldu?'),
                  hintText: tr(
                    'ör. Son denemede matematik düştü, çalışma düzeni konuşuldu.',
                  ),
                ),
              ),
              TextField(
                controller: _next,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: tr('Sonraki adım (isteğe bağlı)'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_repeat_rounded),
                title: Text(
                  _followUp == null
                      ? tr('Takip tarihi (isteğe bağlı)')
                      : tr('Takip: {date}', {'date': fmt.format(_followUp!)}),
                ),
                trailing: _followUp == null
                    ? null
                    : IconButton(
                        tooltip: tr('Tarihi kaldır'),
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _followUp = null),
                      ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate:
                        _followUp ?? _metOn.add(const Duration(days: 7)),
                    firstDate: _metOn,
                    lastDate: today.add(const Duration(days: 365)),
                  );
                  if (d != null && mounted) setState(() => _followUp = d);
                },
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(tr('Kaydet')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
