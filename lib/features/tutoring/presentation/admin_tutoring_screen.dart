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

/// Müdür: önümüzdeki 14 günün talepleri, gün gün.
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

/// Oturum ekle / düzenle. Ders programı tablosundan açılınca öğretmen,
/// derslik, gün ve saat dolu gelir (NOTLAR §95). Kaydedilince program da
/// tazelenir.
Future<void> showTutoringSessionDialog(
  BuildContext context,
  WidgetRef ref, {
  TutoringSession? edit,
  String? teacherId,
  String? roomId,
  int? day,
  int? start,
  int? end,
}) => showDialog<void>(
  context: context,
  builder: (_) => _SessionDialog(
    edit: edit,
    teacherId: teacherId,
    roomId: roomId,
    day: day,
    start: start,
    end: end,
  ),
);

class _SessionDialog extends ConsumerStatefulWidget {
  const _SessionDialog({
    this.edit,
    this.teacherId,
    this.roomId,
    this.day,
    this.start,
    this.end,
  });

  final TutoringSession? edit;
  final String? teacherId;
  final String? roomId;
  final int? day;
  final int? start;
  final int? end;

  @override
  ConsumerState<_SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends ConsumerState<_SessionDialog> {
  late String? _teacher = widget.edit?.teacherId ?? widget.teacherId;
  late String? _room = widget.edit?.roomId ?? widget.roomId;
  late TutoringKind _kind = widget.edit?.kind ?? TutoringKind.questionSolving;
  late int _day = widget.edit?.day ?? widget.day ?? 1;
  late int _start = widget.edit?.start ?? widget.start ?? 15 * 60;
  late int _end = widget.edit?.end ?? widget.end ?? 16 * 60;
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
              roomId: _room,
              active: _active,
            ),
          );
      ref.invalidate(tutoringSessionsProvider);
      ref.invalidate(timetableSetupProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, tutoringErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(timetableSetupProvider).value;
    final teachers = setup?.teachers ?? const [];
    final rooms = setup?.rooms ?? const [];
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
              if (rooms.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: const ValueKey('tutoring-room'),
                  initialValue: rooms.any((r) => r.id == _room) ? _room : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: tr('Derslik')),
                  items: [
                    DropdownMenuItem<String?>(child: Text(tr('Derslik yok'))),
                    for (final r in rooms)
                      DropdownMenuItem<String?>(
                        value: r.id,
                        child: Text(r.name),
                      ),
                  ],
                  onChanged: (v) => setState(() => _room = v),
                ),
              ],
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

/// Öğretmenin boş ders saatleri (gün, başlangıç, bitiş).
typedef FreeHour = ({int day, int start, int end});

/// Toplu açma: öğretmenin programdaki boş saatlerinden seçilenlere aynı
/// türde oturum açar (NOTLAR §95). Açılamayanlar (ör. yayındaki programda
/// dersi olan saat) sayıyla bildirilir.
Future<void> showBulkTutoringDialog(
  BuildContext context, {
  required String teacherId,
  required String teacherName,
  required List<FreeHour> hours,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _BulkDialog(teacherId: teacherId, teacherName: teacherName, hours: hours),
);

class _BulkDialog extends ConsumerStatefulWidget {
  const _BulkDialog({
    required this.teacherId,
    required this.teacherName,
    required this.hours,
  });

  final String teacherId;
  final String teacherName;
  final List<FreeHour> hours;

  @override
  ConsumerState<_BulkDialog> createState() => _BulkDialogState();
}

class _BulkDialogState extends ConsumerState<_BulkDialog> {
  final _picked = <FreeHour>{};
  TutoringKind _kind = TutoringKind.questionSolving;
  final _capacity = TextEditingController(text: '4');
  final _branch = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _capacity.dispose();
    _branch.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_picked.isEmpty) {
      showMessage(context, tr('En az bir saat seç.'));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(tutoringRepositoryProvider);
    final cap = (int.tryParse(_capacity.text) ?? 1).clamp(1, 60);
    final branch = _branch.text.trim();
    var done = 0, failed = 0;
    for (final h
        in _picked.toList()..sort(
          (a, b) => a.day != b.day
              ? a.day.compareTo(b.day)
              : a.start.compareTo(b.start),
        )) {
      try {
        await repo.saveSession(
          TutoringSession(
            id: '',
            teacherId: widget.teacherId,
            kind: _kind,
            day: h.day,
            start: h.start,
            end: h.end,
            capacity: _kind == TutoringKind.privateLesson ? 1 : cap,
            branch: branch.isEmpty ? null : branch,
          ),
        );
        done++;
      } catch (_) {
        failed++;
      }
    }
    ref.invalidate(tutoringSessionsProvider);
    ref.invalidate(timetableSetupProvider);
    if (!mounted) return;
    Navigator.pop(context);
    showMessage(
      context,
      failed == 0
          ? tr('{n} oturum açıldı', {'n': done})
          : tr('{n} oturum açıldı, {m} saat açılamadı (çakışma)', {
              'n': done,
              'm': failed,
            }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = {for (final h in widget.hours) h.day}.toList()..sort();
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(tr('Boş saatleri aç')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(
                  '{name} için programda boş olan ders saatleri. Seçtiklerine her hafta oturum açılır.',
                  {'name': widget.teacherName},
                ),
                style: text.bodySmall,
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
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_kind != TutoringKind.privateLesson) ...[
                    Expanded(
                      child: TextField(
                        controller: _capacity,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: tr('Kontenjan (kişi)'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TextField(
                      controller: _branch,
                      maxLength: 40,
                      decoration: InputDecoration(
                        labelText: tr('Ders (boşsa branşı)'),
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (widget.hours.isEmpty)
                Text(tr('Programda boş saati yok.'))
              else
                for (final d in days) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(dayLong(d), style: text.labelLarge),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final h in widget.hours.where((x) => x.day == d))
                        FilterChip(
                          key: ValueKey('free-${h.day}-${h.start}'),
                          label: Text(formatHm(h.start)),
                          selected: _picked.contains(h),
                          onSelected: (v) => setState(
                            () => v ? _picked.add(h) : _picked.remove(h),
                          ),
                        ),
                    ],
                  ),
                ],
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
          key: const ValueKey('bulk-tutoring-save'),
          onPressed: _saving ? null : _save,
          child: Text(
            _picked.isEmpty
                ? tr('Aç')
                : tr('{n} saati aç', {'n': _picked.length}),
          ),
        ),
      ],
    );
  }
}
