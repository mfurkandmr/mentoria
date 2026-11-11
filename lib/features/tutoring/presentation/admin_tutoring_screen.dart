import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../admin/presentation/cockpit/cockpit_theme.dart';
import '../../admin/presentation/cockpit/section_states.dart';
import '../../schedule_generator/data/timetable_repository.dart';
import '../../schedule_generator/presentation/timetable_format.dart';
import '../data/tutoring_repository.dart';
import 'tutoring_widgets.dart';

/// Müdür: soru çözümü / birebir / etüt oturumları ve talepler (NOTLAR §87).
/// Oturumu müdür açar ve öğretmene atar; talebi öğretmen onaylar, müdür
/// yalnızca görür.
class TutoringAdminScreen extends ConsumerWidget {
  const TutoringAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 2,
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(tr('Soru çözümü ve birebir')),
          bottom: TabBar(
            tabs: [
              Tab(text: tr('Oturumlar')),
              Tab(text: tr('Talepler')),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('add-tutoring'),
          onPressed: () => showTutoringSessionDialog(context, ref),
          icon: const Icon(Icons.add),
          label: Text(tr('Oturum ekle')),
        ),
        body: const TabBarView(
          children: [_SessionsTab(), ManagedTutoringRequests()],
        ),
      ),
    ),
  );
}

/// Koç: kendi öğrencilerinin talepleri (salt okunur).
class CoachTutoringScreen extends StatelessWidget {
  const CoachTutoringScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('Soru çözümü talepleri'))),
    body: const ManagedTutoringRequests(),
  );
}

class _SessionsTab extends ConsumerWidget {
  const _SessionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(tutoringSessionsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(tutoringSessionsProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Text(
            tr(
              'Haftalık saatler her hafta tekrarlanır. Öğrenci önümüzdeki 14 gün için talep eder, öğretmen onaylar. Öğretmenin programda dersi olan saate oturum açılamaz.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          CockpitAsync<List<TutoringSession>>(
            value: sessions,
            onRetry: () => ref.invalidate(tutoringSessionsProvider),
            builder: (list) {
              if (list.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SectionEmpty(
                      icon: Icons.quiz_outlined,
                      message: tr(
                        'Henüz oturum yok. Öğretmenlere soru çözümü ya da birebir ders saati aç.',
                      ),
                      actionLabel: tr('Oturum ekle'),
                      actionIcon: Icons.add,
                      onAction: () => showTutoringSessionDialog(context, ref),
                    ),
                  ),
                );
              }
              final days = {for (final s in list) s.day}.toList()..sort();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final d in days) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                      child: Text(dayLong(d), style: cockpitLabel(context)),
                    ),
                    for (final s in list.where((x) => x.day == d))
                      Card(
                        key: ValueKey('tutoring-${s.id}'),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(tutoringIcon(s.kind)),
                          title: Text(
                            '${s.timeLabel} · ${[s.kind.label, ?s.branch].join(' · ')}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              s.teacherName ?? '',
                              if (s.capacity > 1)
                                tr('{n} kişilik', {'n': s.capacity}),
                              ?s.roomName,
                              if (!s.active) tr('Kapalı'),
                            ].join(' · '),
                          ),
                          onTap: () =>
                              showTutoringSessionDialog(context, ref, edit: s),
                          trailing: IconButton(
                            tooltip: tr('Sil'),
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(context, ref, s),
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TutoringSession s,
  ) async {
    final ok = await confirm(
      context,
      title: tr('Oturum silinsin mi?'),
      message: tr('Bu saate gelmiş bütün talepler de silinir.'),
      action: tr('Sil'),
    );
    if (!ok) return;
    await ref.read(tutoringRepositoryProvider).deleteSession(s.id);
    ref.invalidate(tutoringSessionsProvider);
  }
}

/// Koç ve müdür: önümüzdeki 14 günün talepleri, gün gün.
class ManagedTutoringRequests extends ConsumerWidget {
  const ManagedTutoringRequests({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(managedTutoringRequestsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(managedTutoringRequestsProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Text(
            tr(
              'Önümüzdeki 14 günün talepleri. Onayı öğretmen verir; buradan yalnızca izlenir.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          CockpitAsync<List<TutoringRequest>>(
            value: requests,
            onRetry: () => ref.invalidate(managedTutoringRequestsProvider),
            builder: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      tr('Talep yok.'),
                      textAlign: TextAlign.center,
                      style: cockpitLabel(context),
                    ),
                  )
                : Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        children: [
                          for (final r in list)
                            TutoringRequestTile(
                              key: ValueKey('managed-${r.id}'),
                              request: r,
                              showStudent: true,
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

/// Oturum ekle / düzenle.
Future<void> showTutoringSessionDialog(
  BuildContext context,
  WidgetRef ref, {
  TutoringSession? edit,
}) => showDialog<void>(
  context: context,
  builder: (_) => _SessionDialog(edit: edit),
);

class _SessionDialog extends ConsumerStatefulWidget {
  const _SessionDialog({this.edit});

  final TutoringSession? edit;

  @override
  ConsumerState<_SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends ConsumerState<_SessionDialog> {
  late String? _teacher = widget.edit?.teacherId;
  late TutoringKind _kind = widget.edit?.kind ?? TutoringKind.questionSolving;
  late int _day = widget.edit?.day ?? 1;
  late int _start = widget.edit?.start ?? 15 * 60;
  late int _end = widget.edit?.end ?? 16 * 60;
  late final _capacity = TextEditingController(
    text: '${widget.edit?.capacity ?? 4}',
  );
  late final _branch = TextEditingController(text: widget.edit?.branch ?? '');
  late bool _active = widget.edit?.active ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _capacity.dispose();
    _branch.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final m = start ? _start : _end;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (t == null) return;
    setState(() {
      final v = t.hour * 60 + t.minute;
      if (start) {
        final len = _end - _start;
        _start = v;
        if (_end <= _start) {
          _end = (_start + (len > 0 ? len : 60)).clamp(0, 1439);
        }
      } else {
        _end = v;
      }
    });
  }

  Future<void> _save() async {
    if (_teacher == null) {
      showMessage(context, tr('Öğretmeni seç.'));
      return;
    }
    if (_end <= _start) {
      showMessage(context, tr('Bitiş saati başlangıçtan sonra olmalı.'));
      return;
    }
    final cap = (int.tryParse(_capacity.text) ?? 1).clamp(1, 60);
    setState(() => _saving = true);
    try {
      await ref
          .read(tutoringRepositoryProvider)
          .saveSession(
            TutoringSession(
              id: widget.edit?.id ?? '',
              teacherId: _teacher!,
              kind: _kind,
              day: _day,
              start: _start,
              end: _end,
              capacity: _kind == TutoringKind.privateLesson ? 1 : cap,
              branch: _branch.text.trim().isEmpty ? null : _branch.text.trim(),
              roomId: widget.edit?.roomId,
              active: _active,
            ),
          );
      ref.invalidate(tutoringSessionsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, tutoringErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teachers =
        ref.watch(timetableSetupProvider).value?.teachers ?? const [];
    return AlertDialog(
      title: Text(
        widget.edit == null ? tr('Oturum ekle') : tr('Oturumu düzenle'),
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                key: const ValueKey('tutoring-teacher'),
                initialValue: _teacher,
                isExpanded: true,
                decoration: InputDecoration(labelText: tr('Öğretmen')),
                items: [
                  for (final t in teachers)
                    DropdownMenuItem(
                      value: t.teacher.id,
                      child: Text(
                        '${t.teacher.name} (${t.teacher.branches.join(', ')})',
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _teacher = v),
              ),
              const SizedBox(height: 12),
              SegmentedButton<TutoringKind>(
                showSelectedIcon: false,
                segments: [
                  for (final k in TutoringKind.values)
                    ButtonSegment(value: k, label: Text(k.label)),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: const ValueKey('tutoring-day'),
                initialValue: _day,
                decoration: InputDecoration(labelText: tr('Gün')),
                items: [
                  for (var d = 1; d <= 7; d++)
                    DropdownMenuItem(value: d, child: Text(dayLong(d))),
                ],
                onChanged: (v) => setState(() => _day = v ?? _day),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('tutoring-start'),
                      onPressed: () => _pick(true),
                      child: Text(tr('Başlangıç {t}', {'t': formatHm(_start)})),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('tutoring-end'),
                      onPressed: () => _pick(false),
                      child: Text(tr('Bitiş {t}', {'t': formatHm(_end)})),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_kind != TutoringKind.privateLesson)
                TextField(
                  key: const ValueKey('tutoring-capacity'),
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: tr('Kontenjan (kişi)'),
                  ),
                ),
              TextField(
                controller: _branch,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: tr('Ders (boşsa öğretmenin branşı)'),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: Text(tr('Talebe açık')),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Vazgeç')),
        ),
        TextButton(
          key: const ValueKey('tutoring-save'),
          onPressed: _saving ? null : _save,
          child: Text(tr('Kaydet')),
        ),
      ],
    );
  }
}
