import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../data/timetable_repository.dart';
import '../domain/constraints.dart';
import '../domain/models.dart';
import '../domain/schedule_generator.dart';
import 'schedule_export.dart';
import 'timetable_format.dart';
import '../../../core/design/motion.dart';

final _inline = FilledButton.styleFrom(minimumSize: const Size(0, 44));

/// Üretimi ayrı isolate'te çalıştırır (arayüz donmasın). Web'de [compute]
/// aynı iş parçacığında çalışır.
Future<GenerationResult> runGenerator(GenerationInput input) async =>
    GenerationResult.fromJson(
      await compute(ScheduleGenerator.generateJson, input.toJson()),
    );

/// Üretici çalıştırıcı (testler isolate'siz doğrudan çağrıyla değiştirir;
/// ileride sunucuda üretim de buradan bağlanır).
final scheduleGeneratorProvider =
    Provider<Future<GenerationResult> Function(GenerationInput)>(
      (_) => runGenerator,
    );

/// Programlar listesi ve kuruluma giriş (yalnızca müdür).
class TimetableHomeScreen extends ConsumerWidget {
  const TimetableHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(timetableSetupProvider);
    final schedules = ref.watch(schedulesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Ders programı')),
        actions: [
          IconButton(
            tooltip: tr('Kurulum'),
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push('/admin/schedule/setup'),
          ),
        ],
      ),
      floatingActionButton: (setup.value?.isEmpty ?? true)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _newSchedule(context, ref),
              icon: const Icon(Icons.add),
              label: Text(tr('Yeni program')),
            ),
      body: AsyncView(
        value: schedules,
        onRetry: () => ref.invalidate(schedulesProvider),
        builder: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            if (setup.value?.isEmpty ?? false)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome_rounded),
                  title: Text(tr('Kurulumu başlat')),
                  subtitle: Text(
                    tr(
                      'Ders saatlerini, sınıfları, öğretmenleri ve dersleri gir; program çakışmasız oluşturulsun.',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/admin/schedule/setup'),
                ),
              ),
            if (list.isEmpty && !(setup.value?.isEmpty ?? true))
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr('Henüz program yok.'),
                  textAlign: TextAlign.center,
                ),
              ),
            for (final s in list)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(s.name),
                  subtitle: Text(
                    [
                      if (s.term != null) s.term!,
                      s.published ? tr('Yayında') : tr('Taslak'),
                      if (s.softScore != null)
                        tr('ceza puanı {n}', {'n': s.softScore!}),
                    ].join(' · '),
                  ),
                  leading: Icon(
                    s.published
                        ? Icons.public_rounded
                        : Icons.edit_calendar_outlined,
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: tr('Diğer'),
                    onSelected: (_) => _deleteSchedule(context, ref, s),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'delete', child: Text(tr('Sil'))),
                    ],
                  ),
                  onTap: () => context.push('/admin/schedule/${s.id}'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _newSchedule(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(text: tr('Haftalık program'));
    final ok = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.overlayStyle(context),
      builder: (c) => AlertDialog(
        title: Text(tr('Yeni program')),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: InputDecoration(labelText: tr('Program adı')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('Vazgeç')),
          ),
          FilledButton(
            style: _inline,
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('Oluştur')),
          ),
        ],
      ),
    );
    final n = name.text.trim();
    name.dispose();
    if (ok != true || n.isEmpty || !context.mounted) return;
    try {
      final id = await ref.read(timetableRepositoryProvider).createSchedule(n);
      ref.invalidate(schedulesProvider);
      if (context.mounted) context.push('/admin/schedule/$id?generate=1');
    } catch (_) {
      if (context.mounted) {
        showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
      }
    }
  }

  Future<void> _deleteSchedule(
    BuildContext context,
    WidgetRef ref,
    ScheduleInfo s,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.overlayStyle(context),
      builder: (c) => AlertDialog(
        title: Text(tr('{name} silinsin mi?', {'name': s.name})),
        content: s.published
            ? Text(
                tr(
                  'Yayındaki program silinirse öğretmen ve öğrenciler programı göremez.',
                ),
              )
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('Vazgeç')),
          ),
          FilledButton(
            style: _inline,
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('Sil')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(timetableRepositoryProvider).deleteSchedule(s.id);
      ref.invalidate(schedulesProvider);
    } catch (_) {
      if (context.mounted) {
        showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
      }
    }
  }
}

/// Bir program: sınıf / öğretmen / derslik ızgarası, oluşturma, elle
/// taşıma, kilit, çakışma paneli, dışa aktarma ve yayın.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({
    super.key,
    required this.scheduleId,
    this.autoGenerate = false,
  });

  final String scheduleId;

  /// Açılınca (program boşsa) hemen oluştur.
  final bool autoGenerate;

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  TimetableSetup? _setup;
  List<ScheduleEntry>? _entries;
  GenerationResult? _last;
  Object? _error;
  bool _dirty = false;
  bool _busy = false;
  final _targets = <TimetableMode, String?>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final setup = await ref.read(timetableSetupProvider.future);
      final entries = await ref
          .read(timetableRepositoryProvider)
          .fetchEntries(widget.scheduleId);
      if (!mounted) return;
      setState(() {
        _setup = setup;
        _entries = entries;
        _error = null;
      });
      if (widget.autoGenerate && entries.isEmpty && !setup.isEmpty) {
        await _generate();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  ScheduleInfo? get _info => ref
      .watch(schedulesProvider)
      .value
      ?.where((s) => s.id == widget.scheduleId)
      .firstOrNull;

  Future<void> _generate() async {
    final setup = _setup;
    if (setup == null || _busy) return;
    final locked = [
      for (final e in _entries ?? const <ScheduleEntry>[])
        if (e.locked) e,
    ];
    setState(() => _busy = true);
    try {
      final result = await ref.read(scheduleGeneratorProvider)(
        setup.toInput(
          locked: locked,
          seed: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
        ),
      );
      if (!mounted) return;
      setState(() {
        _entries = result.entries;
        _last = result;
        _dirty = true;
        _busy = false;
      });
      showMessage(
        context,
        result.complete
            ? tr('Program oluşturuldu ({ms} ms).', {'ms': result.durationMs})
            : tr('{n} saat yerleşmedi; nedenleri aşağıda.', {
                'n': result.unassigned.fold<int>(
                  0,
                  (s, u) => s + u.missingHours,
                ),
              }),
      );
    } catch (e) {
      debugPrint('Program oluşturulamadı: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, tr('Program oluşturulamadı. Tekrar dene.'));
    }
  }

  Future<bool> _save() async {
    final entries = _entries;
    final setup = _setup;
    if (entries == null || setup == null) return false;
    setState(() => _busy = true);
    try {
      await ref
          .read(timetableRepositoryProvider)
          .saveEntries(
            widget.scheduleId,
            entries,
            softScore: softScore(setup.toInput(), entries),
          );
      ref.invalidate(schedulesProvider);
      ref.invalidate(myTimetableProvider);
      if (!mounted) return true;
      setState(() {
        _dirty = false;
        _busy = false;
      });
      showMessage(context, tr('Program kaydedildi.'));
      return true;
    } catch (_) {
      if (!mounted) return false;
      setState(() => _busy = false);
      showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
      return false;
    }
  }

  Future<void> _togglePublish(ScheduleInfo info) async {
    final repo = ref.read(timetableRepositoryProvider);
    if (info.published) {
      await repo.unpublish(info.id);
    } else {
      final missing = _missing();
      if (_dirty && !await _save()) return;
      final (classes, students) = await repo
          .scheduleReach(info.id)
          .catchError((_) => (0, 0));
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        animationStyle: AppMotion.overlayStyle(context),
        builder: (c) => AlertDialog(
          title: Text(tr('Program yayınlansın mı?')),
          content: Text(
            [
              tr(
                '{c} sınıf ve {s} öğrenci etkilenecek; öğrencilere bildirim gider.',
                {'c': classes, 's': students},
              ),
              tr(
                'Öğretmenler, öğrenciler ve veliler programı uygulamada görür. Yayındaki öteki program taslağa döner.',
              ),
              if (missing.isNotEmpty)
                tr('Dikkat: {n} saat ders henüz yerleşmedi.', {
                  'n': missing.fold<int>(0, (s, m) => s + m.$2),
                }),
            ].join('\n\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('Vazgeç')),
            ),
            FilledButton(
              style: _inline,
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('Yayınla')),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await repo.publish(info.id);
    }
    ref.invalidate(schedulesProvider);
    ref.invalidate(myTimetableProvider);
    if (mounted) {
      showMessage(
        context,
        info.published
            ? tr('Program yayından kaldırıldı.')
            : tr('Program yayınlandı.'),
      );
    }
  }

  /// Ders başına eksik saat: (metin, saat).
  List<(String, int)> _missing() {
    final setup = _setup, entries = _entries;
    if (setup == null || entries == null) return const [];
    final count = <String, int>{};
    for (final e in entries) {
      final k = '${e.classroomId}|${e.branch}';
      count[k] = (count[k] ?? 0) + 1;
    }
    final names = {
      for (final c in setup.classrooms) c.classroom.id: c.classroom.name,
    };
    return [
      for (final l in setup.lessons)
        if ((count['${l.classroomId}|${l.branch}'] ?? 0) < l.weeklyHours)
          (
            '${names[l.classroomId] ?? ''} ${l.branch}',
            l.weeklyHours - (count['${l.classroomId}|${l.branch}'] ?? 0),
          ),
    ];
  }

  /// [index] dersini [slotId] saatine taşı; kural bozulursa uyar, taşıma.
  void _move(int index, String slotId) {
    final setup = _setup!, entries = _entries!;
    final e = entries[index];
    if (e.timeSlotId == slotId) return;
    if (e.locked) {
      _warn([tr('Kilitli ders taşınamaz; önce kilidi aç.')]);
      return;
    }
    final room = _roomFor(setup, entries, index, slotId);
    final problems = moveProblems(
      setup.toInput(),
      entries,
      index,
      slotId,
      roomId: room,
    );
    if (problems.isNotEmpty) {
      _warn([for (final p in problems) hardRuleMessage(p)]);
      return;
    }
    final before = [...entries];
    setState(() {
      _entries = [...entries]
        ..[index] = e.copyWith(
          timeSlotId: slotId,
          roomId: room,
          clearRoom: room == null,
        );
      _dirty = true;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(tr('Ders taşındı.')),
          action: SnackBarAction(
            label: tr('Geri al'),
            onPressed: () => setState(() => _entries = before),
          ),
        ),
      );
  }

  /// Taşınan dersin yeni saatteki dersliği: sınıfın kendi dersliği, yoksa
  /// eski derslik boşsa o, değilse boş bir ortak derslik.
  String? _roomFor(
    TimetableSetup setup,
    List<ScheduleEntry> entries,
    int index,
    String slotId,
  ) {
    final e = entries[index];
    final home = setup.classrooms
        .where((c) => c.classroom.id == e.classroomId)
        .firstOrNull
        ?.classroom
        .homeRoomId;
    if (home != null) return home;
    final used = {
      for (final (i, o) in entries.indexed)
        if (i != index && o.timeSlotId == slotId && o.roomId != null) o.roomId,
    };
    final homes = {
      for (final c in setup.classrooms)
        if (c.classroom.homeRoomId != null) c.classroom.homeRoomId,
    };
    if (e.roomId != null && !used.contains(e.roomId)) return e.roomId;
    for (final r in setup.rooms) {
      if (!used.contains(r.id) && !homes.contains(r.id)) return r.id;
    }
    return null;
  }

  void _warn(List<String> messages) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: scheme.error,
          content: Text(
            '${tr('Taşınamadı:')} ${messages.join(' ')}',
            style: TextStyle(color: scheme.onError),
          ),
        ),
      );
  }

  void _toggleLock(int index) {
    final e = _entries![index];
    setState(() {
      _entries = [..._entries!]..[index] = e.copyWith(locked: !e.locked);
      _dirty = true;
    });
  }

  Future<void> _openEntry(int index) async {
    final setup = _setup!, entries = _entries!;
    final e = entries[index];
    final input = setup.toInput();
    final slots = {for (final s in setup.slots) s.id: s};
    final legal = [
      for (final s in setup.slots)
        if (s.id != e.timeSlotId &&
            moveProblems(
              input,
              entries,
              index,
              s.id,
              roomId: _roomFor(setup, entries, index, s.id),
            ).isEmpty)
          s,
    ];
    final teacher = setup.teachers
        .where((t) => t.teacher.id == e.teacherId)
        .firstOrNull
        ?.teacher
        .name;
    final klass = setup.classrooms
        .where((c) => c.classroom.id == e.classroomId)
        .firstOrNull
        ?.classroom
        .name;
    final choice = await showModalBottomSheet<String>(
      context: context,
      sheetAnimationStyle: AppMotion.overlayStyle(context),
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(e.branch),
              subtitle: Text(
                [
                  klass ?? '',
                  teacher ?? '',
                  if (slots[e.timeSlotId] != null)
                    '${dayLong(slots[e.timeSlotId]!.day)} ${slotLabel(slots[e.timeSlotId]!)}',
                ].join(' · '),
              ),
            ),
            ListTile(
              key: const ValueKey('entry-lock'),
              leading: Icon(
                e.locked ? Icons.lock_open_rounded : Icons.lock_rounded,
              ),
              title: Text(e.locked ? tr('Kilidi aç') : tr('Bu saate kilitle')),
              subtitle: Text(
                tr('Kilitli ders yeniden oluşturmada yerinde kalır.'),
              ),
              onTap: () => Navigator.pop(c, 'lock'),
            ),
            if (!e.locked) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  legal.isEmpty
                      ? tr('Çakışmasız taşınabileceği saat yok.')
                      : tr('Çakışmasız taşınabileceği saatler'),
                  style: Theme.of(c).textTheme.titleSmall,
                ),
              ),
              for (final s in legal)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.east_rounded),
                  title: Text('${dayLong(s.day)} ${slotLabel(s)}'),
                  onTap: () => Navigator.pop(c, s.id),
                ),
            ],
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    choice == 'lock' ? _toggleLock(index) : _move(index, choice);
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.overlayStyle(context),
      builder: (c) => AlertDialog(
        title: Text(tr('Kaydedilmemiş değişiklikler')),
        content: Text(tr('Program kaydedilmeden çıkılsın mı?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('Vazgeç')),
          ),
          FilledButton(
            style: _inline,
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('Çık')),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final setup = _setup;
    final entries = _entries;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          setState(() => _dirty = false);
          context.pop();
        }
      },
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text(info?.name ?? tr('Ders programı')),
            actions: [
              IconButton(
                key: const ValueKey('regenerate'),
                tooltip: tr('Yeniden oluştur (kilitliler korunur)'),
                icon: const Icon(Icons.auto_awesome_rounded),
                onPressed: _busy || setup == null || setup.isEmpty
                    ? null
                    : _generate,
              ),
              if (setup != null && entries != null)
                PopupMenuButton<(TimetableMode, ExportFormat)>(
                  tooltip: tr('Dışa aktar'),
                  icon: const Icon(Icons.ios_share_rounded),
                  onSelected: (v) => shareSchedule(
                    context,
                    setup: setup,
                    entries: entries,
                    mode: v.$1,
                    format: v.$2,
                    title: info?.name ?? tr('Ders programı'),
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: (TimetableMode.classroom, ExportFormat.pdf),
                      child: Text(tr('Sınıflar · PDF')),
                    ),
                    PopupMenuItem(
                      value: (TimetableMode.teacher, ExportFormat.pdf),
                      child: Text(tr('Öğretmenler · PDF')),
                    ),
                    PopupMenuItem(
                      value: (TimetableMode.classroom, ExportFormat.excel),
                      child: Text(tr('Sınıflar · Excel')),
                    ),
                    PopupMenuItem(
                      value: (TimetableMode.teacher, ExportFormat.excel),
                      child: Text(tr('Öğretmenler · Excel')),
                    ),
                  ],
                ),
              if (info != null)
                IconButton(
                  key: const ValueKey('publish'),
                  tooltip: info.published
                      ? tr('Yayından kaldır')
                      : tr('Yayınla'),
                  icon: Icon(
                    info.published
                        ? Icons.public_off_rounded
                        : Icons.publish_rounded,
                  ),
                  onPressed: _busy ? null : () => _togglePublish(info),
                ),
            ],
            bottom: TabBar(
              tabs: [
                Tab(text: tr('Sınıf')),
                Tab(text: tr('Öğretmen')),
                Tab(text: tr('Derslik')),
              ],
            ),
          ),
          bottomNavigationBar: _dirty
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton.icon(
                      key: const ValueKey('save-schedule'),
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(tr('Programı kaydet')),
                    ),
                  ),
                )
              : null,
          body: _error != null
              ? Center(
                  child: TextButton(
                    onPressed: _load,
                    child: Text(tr('Yüklenemedi. Tekrar dene.')),
                  ),
                )
              : setup == null || entries == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    TabBarView(
                      children: [
                        for (final mode in TimetableMode.values)
                          _ModeView(
                            setup: setup,
                            entries: entries,
                            mode: mode,
                            target: _targets[mode],
                            onTarget: (id) =>
                                setState(() => _targets[mode] = id),
                            onMove: _move,
                            onOpen: _openEntry,
                            header: _Header(
                              info: info,
                              softScore: softScore(setup.toInput(), entries),
                              last: _last,
                              missing: _missing(),
                            ),
                          ),
                      ],
                    ),
                    if (_busy)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.7),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 12),
                                Text(
                                  tr('Program hazırlanıyor… (en çok 10 sn)'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Durum, puan ve çakışma paneli.
class _Header extends StatelessWidget {
  const _Header({
    required this.info,
    required this.softScore,
    required this.last,
    required this.missing,
  });

  final ScheduleInfo? info;
  final int softScore;
  final GenerationResult? last;
  final List<(String, int)> missing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final conflicts = last?.conflicts ?? const <Conflict>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              avatar: Icon(
                info?.published ?? false
                    ? Icons.public_rounded
                    : Icons.edit_outlined,
                size: 18,
              ),
              label: Text(
                info?.published ?? false
                    ? info?.publishedAt == null
                          ? tr('Yayında')
                          : tr('Yayında · {d}', {
                              'd': DateFormat(
                                'd MMMM yyyy',
                                localeTag,
                              ).format(info!.publishedAt!),
                            })
                    : tr('Taslak'),
              ),
            ),
            Chip(
              label: Text(tr('Ceza puanı {n}', {'n': softScore})),
              avatar: const Icon(Icons.tune_rounded, size: 18),
            ),
          ],
        ),
        Text(
          tr(
            'Ceza puanı düşükse program dengeli: öğretmen penceresi, aynı derse yığılma, öğleden sonra sayısal ders ve sık sınıf değişimi puan ekler.',
          ),
          style: text.bodySmall,
        ),
        if (missing.isNotEmpty || conflicts.isNotEmpty)
          Card(
            color: scheme.errorContainer,
            margin: const EdgeInsets.only(top: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: scheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr('Çakışmalar ve eksikler'),
                          style: text.titleSmall?.copyWith(
                            color: scheme.onErrorContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final (name, n) in missing)
                    Text(
                      '• ${tr('{lesson}: {n} saat yerleşmedi', {'lesson': name, 'n': n})}',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  for (final c in conflicts)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '• ${conflictMessage(c)}',
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _ModeView extends StatelessWidget {
  const _ModeView({
    required this.setup,
    required this.entries,
    required this.mode,
    required this.target,
    required this.onTarget,
    required this.onMove,
    required this.onOpen,
    required this.header,
  });

  final TimetableSetup setup;
  final List<ScheduleEntry> entries;
  final TimetableMode mode;
  final String? target;
  final ValueChanged<String?> onTarget;
  final void Function(int index, String slotId) onMove;
  final ValueChanged<int> onOpen;
  final Widget header;

  @override
  Widget build(BuildContext context) {
    final options = switch (mode) {
      TimetableMode.classroom => [
        for (final c in setup.classrooms) (c.classroom.id, c.classroom.name),
      ],
      TimetableMode.teacher => [
        for (final t in setup.teachers) (t.teacher.id, t.teacher.name),
      ],
      TimetableMode.room => [for (final r in setup.rooms) (r.id, r.name)],
    };
    final selected = options.any((o) => o.$1 == target)
        ? target
        : options.firstOrNull?.$1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        header,
        if (options.isEmpty)
          Text(
            mode == TimetableMode.room
                ? tr('Derslik tanımlı değil.')
                : tr('Kayıt yok.'),
          )
        else ...[
          DropdownButtonFormField<String>(
            key: ValueKey('target-${mode.name}'),
            initialValue: selected,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: switch (mode) {
                TimetableMode.classroom => tr('Sınıf'),
                TimetableMode.teacher => tr('Öğretmen'),
                TimetableMode.room => tr('Derslik'),
              },
            ),
            items: [
              for (final (id, name) in options)
                DropdownMenuItem(value: id, child: Text(name)),
            ],
            onChanged: onTarget,
          ),
          const SizedBox(height: 10),
          Text(
            tr(
              'Derse dokun: kilitle ya da taşı. Basılı tutup sürükle: başka saate taşı.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          _Grid(
            setup: setup,
            entries: entries,
            mode: mode,
            targetId: selected!,
            onMove: onMove,
            onOpen: onOpen,
          ),
        ],
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.setup,
    required this.entries,
    required this.mode,
    required this.targetId,
    required this.onMove,
    required this.onOpen,
  });

  final TimetableSetup setup;
  final List<ScheduleEntry> entries;
  final TimetableMode mode;
  final String targetId;
  final void Function(int index, String slotId) onMove;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final (days, maxSeq) = gridShape(setup.slots);
    final cells = cellsFor(setup, entries, mode, targetId);
    final slotAt = {for (final s in setup.slots) (s.day, s.seq): s};
    final teachers = {
      for (final t in setup.teachers) t.teacher.id: t.teacher.name,
    };
    final classes = {
      for (final c in setup.classrooms) c.classroom.id: c.classroom.name,
    };
    final rooms = {for (final r in setup.rooms) r.id: r.name};
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget tile(int i, {bool dragging = false}) {
      final e = entries[i];
      final sub = switch (mode) {
        TimetableMode.classroom => teachers[e.teacherId] ?? '',
        TimetableMode.teacher => classes[e.classroomId] ?? '',
        TimetableMode.room => classes[e.classroomId] ?? '',
      };
      final color = branchColor(e.branch);
      return Container(
        width: 92,
        height: 64,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dragging ? 0.5 : 0.18),
          border: Border.all(color: color, width: e.locked ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    e.branch,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (e.locked)
                  Icon(Icons.lock_rounded, size: 14, color: scheme.onSurface),
              ],
            ),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall,
            ),
            if (mode != TimetableMode.room && e.roomId != null)
              Text(
                rooms[e.roomId] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall,
              ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(98),
        columnWidths: const {0: FixedColumnWidth(52)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              const SizedBox.shrink(),
              for (final d in days)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    dayLong(d),
                    textAlign: TextAlign.center,
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          for (var seq = 1; seq <= maxSeq; seq++)
            TableRow(
              children: [
                Text(rowLabel(setup.slots, seq), style: text.labelSmall),
                for (final d in days)
                  Builder(
                    builder: (context) {
                      final slot = slotAt[(d, seq)];
                      final here = cells[(d, seq)] ?? const <int>[];
                      if (slot == null) return const SizedBox(height: 70);
                      return DragTarget<int>(
                        onWillAcceptWithDetails: (_) => true,
                        onAcceptWithDetails: (det) => onMove(det.data, slot.id),
                        builder: (context, candidate, _) => Container(
                          key: ValueKey('cell-${slot.id}'),
                          height: 70,
                          margin: const EdgeInsets.all(1),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: candidate.isNotEmpty
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: here.isEmpty
                              ? null
                              : Semantics(
                                  button: true,
                                  label: entries[here.first].branch,
                                  child: LongPressDraggable<int>(
                                    data: here.first,
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: tile(here.first, dragging: true),
                                    ),
                                    childWhenDragging: Opacity(
                                      opacity: 0.3,
                                      child: tile(here.first),
                                    ),
                                    child: InkWell(
                                      key: ValueKey('entry-${slot.id}'),
                                      onTap: () => onOpen(here.first),
                                      child: tile(here.first),
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
