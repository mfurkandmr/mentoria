import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/panel.dart';
import '../data/tutoring_repository.dart';
import 'tutoring_widgets.dart';

/// Öğrenci ana sayfası ve Eğitim sekmesi: soru çözümü / birebir girişi.
/// Her zaman görünür; kurum henüz saat açmadıysa bunu söyler.
class TutoringHomeCard extends ConsumerWidget {
  const TutoringHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(openTutoringSlotsProvider).value ?? const [];
    final mine = ref.watch(myTutoringRequestsProvider).value ?? const [];
    final next = mine
        .where((r) => r.status == TutoringStatus.approved)
        .firstOrNull;
    final pending = mine
        .where((r) => r.status == TutoringStatus.pending)
        .length;
    return Card(
      child: ListTile(
        key: const ValueKey('tutoring-home-card'),
        leading: const Icon(Icons.quiz_outlined),
        title: Text(tr('Soru çözümü ve birebir')),
        subtitle: Text(
          next != null
              ? tr('Onaylı: {d} {t} · {b}', {
                  'd': tutoringDateLabel(next.date),
                  't': formatHm(next.start),
                  'b': next.branch ?? next.kind.label,
                })
              : pending > 0
              ? tr('{n} talebin onay bekliyor', {'n': pending})
              : slots.isEmpty
              ? tr('Kurumun henüz açık saat girmedi')
              : tr('Öğretmenlerden soru çözümü ya da birebir ders iste'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/student/study'),
      ),
    );
  }
}

/// Öğrenci: önümüzdeki 7 günün açık oturumları ve talepleri.
class StudentTutoringScreen extends ConsumerStatefulWidget {
  const StudentTutoringScreen({super.key});

  @override
  ConsumerState<StudentTutoringScreen> createState() =>
      _StudentTutoringScreenState();
}

class _StudentTutoringScreenState extends ConsumerState<StudentTutoringScreen> {
  DateTime? _day;

  Future<void> _refresh() async {
    ref.invalidate(myTutoringRequestsProvider);
    final _ = await ref.refresh(openTutoringSlotsProvider.future);
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      await _refresh();
      if (mounted) showMessage(context, done);
    } catch (e) {
      await _refresh();
      if (mounted) showMessage(context, tutoringErrorMessage(e));
    }
  }

  Future<void> _request(TutoringSlot s) async {
    final topic = await showDialog<String>(
      context: context,
      builder: (_) => _RequestDialog(slot: s),
    );
    if (topic == null) return;
    await _run(
      () => ref
          .read(tutoringRepositoryProvider)
          .request(s.sessionId, s.date, topic: topic),
      tr('Talebin öğretmene gönderildi'),
    );
  }

  Future<void> _cancel(String id) async {
    final ok = await confirm(
      context,
      title: tr('Talep iptal edilsin mi?'),
      message: tr('Öğretmen bu saatte seni beklemeyecek.'),
      action: tr('İptal et'),
    );
    if (!ok) return;
    await _run(
      () => ref.read(tutoringRepositoryProvider).cancel(id),
      tr('Talep iptal edildi'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(openTutoringSlotsProvider);
    final mine = ref.watch(myTutoringRequestsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(tr('Soru çözümü ve birebir'))),
      body: AsyncView(
        value: slots,
        onRetry: _refresh,
        builder: (list) {
          final days = {for (final s in list) s.date}.toList()..sort();
          final day = days.contains(_day) ? _day : days.firstOrNull;
          final todays = [
            for (final s in list)
              if (s.date == day) s,
          ];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (mine.isNotEmpty) ...[
                  _Heading(tr('Taleplerim')),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        children: [
                          for (final r in mine)
                            TutoringRequestTile(
                              key: ValueKey('my-request-${r.id}'),
                              request: r,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TutoringStatusPill(r.status),
                                  if (r.status == TutoringStatus.pending ||
                                      r.status == TutoringStatus.approved)
                                    IconButton(
                                      key: ValueKey('cancel-${r.id}'),
                                      tooltip: tr('İptal et'),
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () => _cancel(r.id),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (list.isEmpty)
                  EmptyState(
                    title: tr('Açık oturum yok'),
                    message: tr(
                      'Kurumun önümüzdeki günler için soru çözümü ya da birebir ders saati açmadı. Açtığında burada görünür; buradan talep edersin.',
                    ),
                  )
                else ...[
                  _Heading(tr('Açık oturumlar')),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final d in days)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              key: ValueKey('day-${d.day}'),
                              label: Text(tutoringDateLabel(d)),
                              selected: d == day,
                              onSelected: (_) => setState(() => _day = d),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final s in todays)
                    _SlotCard(slot: s, onRequest: _request),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      'Talebini öğretmen onaylar. Bir güne en çok 3 talep verebilirsin.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.slot, required this.onRequest});

  final TutoringSlot slot;
  final ValueChanged<TutoringSlot> onRequest;

  @override
  Widget build(BuildContext context) {
    final s = slot;
    final Widget action;
    if (s.requested) {
      action = TutoringStatusPill(s.myStatus!);
    } else if (s.full) {
      action = InfoPill(icon: Icons.block_outlined, text: tr('Dolu'));
    } else {
      action = FilledButton(
        key: ValueKey('request-${s.sessionId}'),
        onPressed: () => onRequest(s),
        child: Text(tr('Talep et')),
      );
    }
    return Card(
      key: ValueKey('slot-${s.sessionId}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Icon(tutoringIcon(s.kind)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [s.kind.label, ?s.branch].join(' · '),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      '${formatHm(s.start)}–${formatHm(s.end)}',
                      s.teacherName,
                      ?s.roomName,
                    ].join(' · '),
                  ),
                  if (s.capacity > 1)
                    Text(
                      tr('{t}/{c} dolu', {'t': s.taken, 'c': s.capacity}),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            action,
          ],
        ),
      ),
    );
  }
}

class _RequestDialog extends StatefulWidget {
  const _RequestDialog({required this.slot});

  final TutoringSlot slot;

  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _topic = TextEditingController();

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.slot;
    return AlertDialog(
      title: Text(tr('Talep et')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${tutoringDateLabel(s.date)} ${formatHm(s.start)} · '
            '${[s.kind.label, ?s.branch].join(' · ')} · ${s.teacherName}',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('request-topic'),
            controller: _topic,
            maxLength: 200,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: tr('Konu ya da soru (isteğe bağlı)'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Vazgeç')),
        ),
        TextButton(
          key: const ValueKey('request-send'),
          onPressed: () => Navigator.pop(context, _topic.text.trim()),
          child: Text(tr('Gönder')),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    ),
  );
}
