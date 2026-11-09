import '../../../shared/widgets/tool_tile.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../admin/presentation/cockpit/cockpit_motion.dart';
import '../../admin/presentation/cockpit/cockpit_theme.dart';
import '../../admin/data/admin_repository.dart';
import '../../schedule_generator/data/timetable_repository.dart';
import '../../student_management/data/student_management_repository.dart';
import '../data/bulk_sms_repository.dart';

final _inline = FilledButton.styleFrom(minimumSize: const Size(0, 44));

/// Kurum müdürü: velilere istediği metni SMS olarak gönderir (resmi tatil,
/// toplantı, duyuru…). Herkese, seçili sınıflara ya da seçili öğrencilerin
/// velilerine.
class BulkSmsScreen extends ConsumerStatefulWidget {
  const BulkSmsScreen({super.key});

  @override
  ConsumerState<BulkSmsScreen> createState() => _BulkSmsScreenState();
}

class _BulkSmsScreenState extends ConsumerState<BulkSmsScreen> {
  final _body = TextEditingController();
  SmsAudience _audience = SmsAudience.all;
  final _classes = <String>{};
  final _students = <String>{};
  SmsReach? _reach;
  bool _busy = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _body.addListener(() => setState(() {}));
    _preview();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _body.dispose();
    super.dispose();
  }

  void _preview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final r = await ref
            .read(bulkSmsRepositoryProvider)
            .send(
              body: '',
              audience: _audience,
              classroomIds: _classes.toList(),
              studentIds: _students.toList(),
              dryRun: true,
            );
        if (mounted) setState(() => _reach = r);
      } catch (_) {
        if (mounted) setState(() => _reach = null);
      }
    });
  }

  void _setAudience(SmsAudience a) {
    setState(() {
      _audience = a;
      _reach = null;
    });
    _preview();
  }

  Future<void> _pickStudents() async {
    final all = await ref.read(managedStudentsProvider.future);
    if (!mounted) return;
    final picked = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _StudentPicker(students: all, initial: _students),
    );
    if (picked == null) return;
    setState(() {
      _students
        ..clear()
        ..addAll(picked);
    });
    _preview();
  }

  /// Yeni bildirim eskisinin arkasında sıra beklemesin.
  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _send(String org) async {
    final text = _body.text.trim();
    final reach = _reach;
    if (text.isEmpty || reach == null || reach.recipients == 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(
          tr('{n} veliye SMS gönderilsin mi?', {'n': reach.recipients}),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('$org: $text'),
              ),
            ),
            if (reach.noPhone > 0)
              Text(
                tr(
                  '{n} öğrencinin veli telefonu kayıtlı değil; onlara gitmez.',
                  {'n': reach.noPhone},
                ),
                style: Theme.of(d).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr('Vazgeç')),
          ),
          FilledButton(
            key: const ValueKey('sms-confirm'),
            style: _inline,
            onPressed: () => Navigator.pop(d, true),
            child: Text(tr('Gönder')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(bulkSmsRepositoryProvider)
          .send(
            body: text,
            audience: _audience,
            classroomIds: _classes.toList(),
            studentIds: _students.toList(),
          );
      ref.invalidate(smsHistoryProvider);
      if (!mounted) return;
      _body.clear();
      setState(() => _busy = false);
      CockpitHaptics.commit();
      _toast(tr('{n} veliye SMS sırasına alındı.', {'n': r.recipients}));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(
        '$e'.contains('SMS_TOO_SOON')
            ? tr(
                'Son gönderimin üzerinden 10 dakika geçmeden yeni SMS gönderilemez.',
              )
            : '$e'.contains('NO_RECIPIENTS')
            ? tr('Seçilenlerin hiçbirinde veli telefonu yok.')
            : tr('Gönderilemedi. Tekrar dene.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(orgProvider).value?.name ?? '';
    final classes =
        ref.watch(timetableSetupProvider).value?.classrooms ??
        const <ClassroomRecord>[];
    final history = ref.watch(smsHistoryProvider);
    final text = Theme.of(context).textTheme;
    final full = org.isEmpty ? _body.text : '$org: ${_body.text}';
    final reach = _reach;
    final templates = <String, String>{
      tr('Resmi tatil'): tr(
        'Resmi tatil nedeniyle kurumumuz {gün} günü kapalıdır. Dersler {gün2} günü normal programla devam edecektir.',
      ),
      tr('Deneme sınavı'): tr(
        '{gün} saat {saat}\'te kurumumuzda deneme sınavı yapılacaktır. Öğrencimizin kimliği ve kurşun kalemiyle zamanında gelmesini rica ederiz.',
      ),
      tr('Veli toplantısı'): tr(
        '{gün} saat {saat}\'te veli toplantımız yapılacaktır. Katılımınızı bekleriz.',
      ),
    };
    return Scaffold(
      appBar: AppBar(title: Text(tr('Velilere SMS'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in templates.entries)
                ActionChip(
                  label: Text(e.key),
                  onPressed: () => _body.text = e.value,
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('sms-body'),
            controller: _body,
            minLines: 4,
            maxLines: 8,
            maxLength: 600,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: tr('Mesaj'),
              hintText: tr('Velilere gidecek metni yaz'),
              helperText: tr(
                'Başına "{org}:" eklenir. {n} karakter · yaklaşık {k} SMS',
                {'org': org, 'n': full.length, 'k': smsSegments(full)},
              ),
              helperMaxLines: 2,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          CockpitHeading(tr('Kime')),
          SlidingSegments<SmsAudience>(
            value: _audience,
            onChanged: _setAudience,
            segments: {
              SmsAudience.all: (
                key: const ValueKey('sms-audience-all'),
                label: tr('Tüm veliler'),
                count: null,
              ),
              SmsAudience.classes: (
                key: const ValueKey('sms-audience-classes'),
                label: tr('Sınıflar'),
                count: null,
              ),
              SmsAudience.students: (
                key: const ValueKey('sms-audience-students'),
                label: tr('Öğrenciler'),
                count: null,
              ),
            },
          ),
          const SizedBox(height: 8),
          if (_audience == SmsAudience.classes)
            classes.isEmpty
                ? Text(tr('Henüz sınıf yok.'))
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in classes)
                        FilterChip(
                          key: ValueKey('sms-class-${c.classroom.id}'),
                          label: Text(c.classroom.name),
                          selected: _classes.contains(c.classroom.id),
                          onSelected: (v) {
                            setState(
                              () => v
                                  ? _classes.add(c.classroom.id)
                                  : _classes.remove(c.classroom.id),
                            );
                            _preview();
                          },
                        ),
                    ],
                  ),
          if (_audience == SmsAudience.students)
            OutlinedButton.icon(
              key: const ValueKey('sms-pick-students'),
              onPressed: _pickStudents,
              icon: const Icon(Icons.person_search_rounded),
              label: Text(tr('Öğrenci seç ({n})', {'n': _students.length})),
            ),
          const SizedBox(height: 10),
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.people_alt_outlined),
              title: Text(
                reach == null
                    ? tr('Alıcılar hesaplanıyor…')
                    : tr('{n} veliye gidecek', {'n': reach.recipients}),
              ),
              subtitle: reach == null || reach.noPhone == 0
                  ? null
                  : Text(
                      tr('{n} öğrencinin veli telefonu yok', {
                        'n': reach.noPhone,
                      }),
                    ),
              trailing: reach != null && reach.noPhone > 0
                  ? TextButton(
                      onPressed: () => context.push('/admin/attendance'),
                      child: Text(tr('Telefon ekle')),
                    )
                  : null,
            ),
          ),
          Text(
            tr(
              'Yalnızca bilgilendirme gönder: reklam ya da kampanya içerikli SMS için velinin ticari ileti izni (İYS) gerekir.',
            ),
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('sms-send'),
            onPressed:
                _busy ||
                    _body.text.trim().isEmpty ||
                    reach == null ||
                    reach.recipients == 0
                ? null
                : () => _send(org),
            icon: const Icon(Icons.send_rounded),
            label: Text(
              reach == null || reach.recipients == 0
                  ? tr('Gönder')
                  : tr('Gönder ({n})', {'n': reach.recipients}),
            ),
          ),
          const SizedBox(height: 20),
          CockpitHeading(tr('Otomatik SMS')),
          const _ExamResultSmsTile(),
          const SizedBox(height: 12),
          CockpitHeading(tr('Gönderilenler')),
          AsyncView(
            value: history,
            onRetry: () => ref.invalidate(smsHistoryProvider),
            builder: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(tr('Henüz SMS gönderilmedi.')),
                  )
                : Column(
                    children: [
                      for (final b in list)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              b.body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                DateFormat(
                                  'd MMMM HH:mm',
                                  localeTag,
                                ).format(b.createdAt),
                                tr('{n} veli', {'n': b.recipients}),
                                if (b.sent > 0) tr('{n} gitti', {'n': b.sent}),
                                if (b.queued > 0)
                                  tr('{n} sırada', {'n': b.queued}),
                                if (b.failed > 0)
                                  tr('{n} başarısız', {'n': b.failed}),
                              ].join(' · '),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Kurum sınavı sonucu velilere otomatik SMS (açık/kapalı).
class _ExamResultSmsTile extends ConsumerStatefulWidget {
  const _ExamResultSmsTile();

  @override
  ConsumerState<_ExamResultSmsTile> createState() => _ExamResultSmsTileState();
}

class _ExamResultSmsTileState extends ConsumerState<_ExamResultSmsTile> {
  bool _busy = false;

  Future<void> _set(bool value) async {
    setState(() => _busy = true);
    try {
      await ref.read(bulkSmsRepositoryProvider).setExamResultSms(value);
      ref.invalidate(examResultSmsProvider);
    } catch (_) {
      if (mounted) showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = ref.watch(examResultSmsProvider);
    return Card(
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        key: const ValueKey('sms-exam-results'),
        secondary: const Icon(Icons.fact_check_outlined),
        title: Text(tr('Deneme sonuçları velilere gitsin')),
        subtitle: Text(
          tr(
            'Kurum sınavı yayınlanınca her öğrencinin velisine toplam net, kurum sırası ve ders ders doğru, yanlış, net SMS ile gider; sonradan yüklenen optikler de. Her öğrenci için bir kez. Ders sayısına göre mesaj birkaç SMS tutar.',
          ),
        ),
        value: on.value ?? false,
        onChanged: _busy || !on.hasValue ? null : _set,
      ),
    );
  }
}

class _StudentPicker extends StatefulWidget {
  const _StudentPicker({required this.students, required this.initial});

  final List<ManagedStudent> students;
  final Set<String> initial;

  @override
  State<_StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<_StudentPicker> {
  late final _picked = {...widget.initial};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final shown = [
      for (final s in widget.students)
        if (q.isEmpty ||
            s.fullName.toLowerCase().contains(q) ||
            (s.studentNumber ?? '').contains(q))
          s,
    ];
    return AlertDialog(
      title: Text(tr('Öğrenci seç')),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: tr('Ad soyad veya öğrenci no ara'),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final s in shown)
                    CheckboxListTile(
                      key: ValueKey('sms-pick-${s.id}'),
                      dense: true,
                      value: _picked.contains(s.id),
                      title: Text(s.fullName),
                      subtitle: Text(s.classroomName ?? tr('Atanmadı')),
                      onChanged: (v) => setState(
                        () => v == true
                            ? _picked.add(s.id)
                            : _picked.remove(s.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Vazgeç')),
        ),
        FilledButton(
          key: const ValueKey('sms-pick-done'),
          style: _inline,
          onPressed: () => Navigator.pop(context, _picked),
          child: Text(tr('Seç ({n})', {'n': _picked.length})),
        ),
      ],
    );
  }
}

/// Müdür ana sayfası: velilere SMS.
/// Müdür: velilere toplu SMS kısayolu.
ToolInfo bulkSmsTool() => ToolInfo(
  id: 'bulk-sms-card',
  icon: Icons.sms_outlined,
  title: tr('Velilere SMS'),
  status: tr('Resmi tatil, toplantı, duyuru: istediğin metni gönder'),
  open: (context) => context.push('/admin/sms'),
);

class BulkSmsHomeCard extends StatelessWidget {
  const BulkSmsHomeCard({super.key});

  @override
  Widget build(BuildContext context) => ToolListCard(tool: bulkSmsTool());
}
