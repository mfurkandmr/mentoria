import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../garden/presentation/garden_screen.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/daily_bar_chart.dart';
import '../../../shared/widgets/panel.dart';
import '../../auth/data/auth_repository.dart';
import '../../coach/data/coach_repository.dart';
import '../../student/presentation/home_sky.dart';
import '../../../core/settings/app_settings.dart';
import '../data/pomodoro_alarm.dart';
import '../data/tracking_models.dart';
import '../data/tracking_repository.dart';
import 'honey_dial.dart';
import 'questions_view.dart';
import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/effects.dart';

/// Öğrencinin çalışma süresi sekmesi: zamanlayıcı + istatistikler.
class StudyScreen extends ConsumerWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    return Scaffold(
      appBar: SkyAppBar(
        title: Text(tr('Çalışma süresi')),
        actions: [
          IconButton(
            tooltip: tr('Odak Bahçem'),
            onPressed: () => context.push('/student/garden'),
            icon: const Icon(Icons.local_florist_rounded),
          ),
        ],
      ),
      body: profile == null
          ? const BizzLoader()
          : RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(studySessionsProvider(profile.id).future),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  StudyTimerCard(studentId: profile.id),
                  const SizedBox(height: 12),
                  StudyStatsSection(studentId: profile.id, canEdit: true),
                ],
              ),
            ),
    );
  }
}

enum _Phase { idle, work, paused, rest }

/// Pomodoro / kronometre. Süre, başlangıç zamanından hesaplanır; uygulama
/// arka plana alınsa da doğru kalır.
class StudyTimerCard extends ConsumerStatefulWidget {
  const StudyTimerCard({super.key, required this.studentId});

  final String studentId;

  @override
  ConsumerState<StudyTimerCard> createState() => _StudyTimerCardState();
}

class _StudyTimerCardState extends ConsumerState<StudyTimerCard> {
  SessionType _mode = SessionType.pomodoro;
  int _workMinutes = 25;
  int _restMinutes = 5;
  String? _subject;

  _Phase _phase = _Phase.idle;
  DateTime? _sessionStart; // oturumun ilk başladığı an (kayıt için)
  DateTime? _segmentStart; // şu anki çalışma parçasının başlangıcı
  Duration _accumulated = Duration.zero; // duraklatmadan önce geçen süre
  DateTime? _restEnd;
  Timer? _ticker;
  bool _saving = false;

  /// Bitiş alarmı bildirim olarak kurulabildi mi? Kurulamadıysa (web, izin
  /// yok) süre bitince sesi uygulama kendisi çalar.
  bool _alarmSet = false;
  bool _askedExact = false;

  static const _stateKey = 'pomodoro_state';

  @override
  void initState() {
    super.initState();
    // Uygulama kapatılıp açıldıysa süren zamanlayıcıyı geri yükle.
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  @override
  void dispose() {
    // Alarm ve sayaç bildirimi bilerek iptal edilmez: zamanlayıcı arka planda
    // sürer, durum cihazda saklıdır.
    _ticker?.cancel();
    super.dispose();
  }

  Duration get _elapsed =>
      _accumulated +
      (_segmentStart == null
          ? Duration.zero
          : DateTime.now().difference(_segmentStart!));

  AlarmTone get _tone => ref.read(settingsProvider).pomodoroTone;

  String get _subjectName => _subject == null
      ? tr('Ders belirtilmedi')
      : subjectByCode(_subject!).name;

  // --- Kalıcı durum (uygulama kapanırsa geri yüklemek için) ---------------

  void _persist() {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs == null) return;
    if (_phase == _Phase.idle) {
      prefs.remove(_stateKey);
      return;
    }
    prefs.setString(
      _stateKey,
      jsonEncode({
        'phase': _phase.name,
        'mode': _mode.name,
        'work': _workMinutes,
        'rest': _restMinutes,
        'subject': _subject,
        'sessionStart': _sessionStart?.toIso8601String(),
        'segmentStart': _segmentStart?.toIso8601String(),
        'accumulatedMs': _accumulated.inMilliseconds,
        'restEnd': _restEnd?.toIso8601String(),
        'alarmSet': _alarmSet,
      }),
    );
  }

  void _restore() {
    if (!mounted || _phase != _Phase.idle) return;
    final raw = ref.read(sharedPreferencesProvider)?.getString(_stateKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      DateTime? d(String k) =>
          j[k] == null ? null : DateTime.parse(j[k] as String);
      setState(() {
        _phase = _Phase.values.byName(j['phase'] as String);
        _mode = SessionType.values.byName(j['mode'] as String);
        _workMinutes = j['work'] as int;
        _restMinutes = j['rest'] as int;
        _subject = j['subject'] as String?;
        _sessionStart = d('sessionStart');
        _segmentStart = d('segmentStart');
        _accumulated = Duration(milliseconds: j['accumulatedMs'] as int);
        _restEnd = d('restEnd');
        _alarmSet = j['alarmSet'] as bool? ?? false;
      });
      if (_phase == _Phase.work || _phase == _Phase.rest) _startTicker();
      // Kapalıyken süre dolduysa ilk tıkta kaydedilir / mola biter.
      _tick();
    } catch (_) {
      ref.read(sharedPreferencesProvider)?.remove(_stateKey);
    }
  }

  // --- Alarm ----------------------------------------------------------------

  /// Çalışma için bitiş alarmını ve bildirim çubuğundaki sayacı kurar.
  Future<void> _armWork() async {
    if (_mode != SessionType.pomodoro) {
      await PomodoroAlarm.cancel();
      _alarmSet = false;
      await PomodoroAlarm.showRunning(
        title: tr('Kronometre · {subject}', {'subject': _subjectName}),
        body: tr('Çalışma süren sayılıyor'),
        startedAt: DateTime.now().subtract(_elapsed),
      );
      _persist();
      return;
    }
    final end = DateTime.now().add(Duration(minutes: _workMinutes) - _elapsed);
    final tone = _tone;
    _alarmSet = await PomodoroAlarm.schedule(
      at: end,
      tone: tone,
      title: tr('Pomodoro bitti! 🐝'),
      body: tr('{n} dakikalık odak tamamlandı. Mola zamanı.', {
        'n': _workMinutes,
      }),
    );
    await PomodoroAlarm.showRunning(
      title: tr('Odak · {subject}', {'subject': _subjectName}),
      body: tr('Bitince {tone}', {'tone': tone.label}),
      endsAt: end,
    );
    _persist();
    _maybeAskExact();
  }

  Future<void> _armRest() async {
    final end = _restEnd!;
    final tone = _tone;
    _alarmSet = await PomodoroAlarm.schedule(
      at: end,
      tone: tone,
      title: tr('Mola bitti'),
      body: tr('Yeni bir pomodoroya hazır mısın? 🐝'),
    );
    await PomodoroAlarm.showRunning(
      title: tr('Mola'),
      body: tr('Bitince {tone}', {'tone': tone.label}),
      endsAt: end,
    );
    _persist();
  }

  /// Android 14+: tam zamanlı alarm izni yoksa bir kez sor (yoksa zil
  /// birkaç dakika gecikebilir).
  Future<void> _maybeAskExact() async {
    if (_askedExact || !_alarmSet) return;
    _askedExact = true;
    if (await PomodoroAlarm.exactAllowed() || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(
          tr(
            'Zilin tam zamanında çalması için "Alarmlar ve hatırlatıcılar" iznini aç.',
          ),
        ),
        action: SnackBarAction(
          label: tr('İzin ver'),
          onPressed: PomodoroAlarm.requestExact,
        ),
      ),
    );
  }

  // --- Akış -----------------------------------------------------------------

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    if (_phase == _Phase.work &&
        _mode == SessionType.pomodoro &&
        _elapsed >= Duration(minutes: _workMinutes)) {
      _finishWork(completed: true);
      return;
    }
    if (_phase == _Phase.rest && !DateTime.now().isBefore(_restEnd!)) {
      _ticker?.cancel();
      if (!_alarmSet) PomodoroAlarm.ringNow(_tone);
      PomodoroAlarm.cancelRunning();
      _alarmSet = false;
      setState(() => _phase = _Phase.idle);
      _persist();
      showMessage(
        context,
        tr('Mola bitti! Yeni bir pomodoroya hazır mısın? 🐝'),
      );
      return;
    }
    setState(() {});
  }

  void _start() {
    final now = DateTime.now();
    setState(() {
      _phase = _Phase.work;
      _sessionStart = now;
      _segmentStart = now;
      _accumulated = Duration.zero;
    });
    _startTicker();
    _armWork();
  }

  void _pause() {
    setState(() {
      _accumulated = _elapsed;
      _segmentStart = null;
      _phase = _Phase.paused;
    });
    _alarmSet = false;
    PomodoroAlarm.cancel();
    _persist();
  }

  void _resume() {
    setState(() {
      _segmentStart = DateTime.now();
      _phase = _Phase.work;
    });
    _armWork();
  }

  Future<void> _finishWork({required bool completed}) async {
    _ticker?.cancel();
    final pomodoroDone = _mode == SessionType.pomodoro && completed;
    final seconds = pomodoroDone ? _workMinutes * 60 : _elapsed.inSeconds;
    final start = _sessionStart!;
    // Mola, odağın gerçekten bittiği andan sayılır (uygulama arka plandaysa
    // bu an geçmişte kalmış olabilir).
    final workDoneAt = pomodoroDone
        ? DateTime.now().subtract(_elapsed - Duration(minutes: _workMinutes))
        : DateTime.now();
    if (pomodoroDone) {
      // Çalmış alarm bildirimi kalsın; yalnızca sayaç kalkar. Bildirim
      // kurulamadıysa sesi uygulama çalar.
      if (!_alarmSet) PomodoroAlarm.ringNow(_tone);
      PomodoroAlarm.cancelRunning();
    } else {
      PomodoroAlarm.cancel();
    }
    _alarmSet = false;
    setState(() {
      _phase = _Phase.idle;
      _segmentStart = null;
      _accumulated = Duration.zero;
    });
    _persist();

    if (seconds < 60) {
      showMessage(context, tr('1 dakikadan kısa oturumlar kaydedilmez.'));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(trackingRepositoryProvider)
          .addSession(
            widget.studentId,
            type: _mode,
            startedAt: start,
            durationSec: math.min(seconds, 43200),
            subjectCode: _subject,
          );
      ref.invalidate(studySessionsProvider(widget.studentId));
      ref.invalidate(allSessionsProvider(widget.studentId));
      ref.invalidate(studentSummariesProvider);
      if (!mounted) return;
      // Her oturum Odak Bahçesi'ne bir çiçek eker.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              tr('{p0} dakika kaydedildi, bahçende bir çiçek açtı 🌸', {
                'p0': (seconds / 60).round(),
              }),
            ),
            action: SnackBarAction(
              label: tr('Bahçeye bak'),
              onPressed: () => context.push('/student/garden'),
            ),
          ),
        );
      if (pomodoroDone) {
        celebrate(context);
        final restEnd = workDoneAt.add(Duration(minutes: _restMinutes));
        if (restEnd.isAfter(DateTime.now())) {
          setState(() {
            _phase = _Phase.rest;
            _restEnd = restEnd;
          });
          _startTicker();
          _armRest();
        }
      }
    } catch (_) {
      if (mounted) showMessage(context, tr('Oturum kaydedilemedi.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _skipRest() {
    _ticker?.cancel();
    _alarmSet = false;
    PomodoroAlarm.cancel();
    setState(() => _phase = _Phase.idle);
    _persist();
  }

  Future<void> _pickTone() async {
    final picked = await showModalBottomSheet<AlarmTone>(
      context: context,
      // Alt menünün üstünde açılsın (sekme içi gezgin değil).
      useRootNavigator: true,
      showDragHandle: true,
      builder: (_) => _TonePicker(selected: _tone),
    );
    if (picked != null) {
      ref.read(settingsProvider.notifier).setPomodoroTone(picked);
      setState(() {});
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final idle = _phase == _Phase.idle;

    late final Duration shown;
    late final double progress;
    late final String caption;
    switch (_phase) {
      case _Phase.rest:
        final left = _restEnd!.difference(DateTime.now());
        shown = left.isNegative ? Duration.zero : left;
        progress = 1 - shown.inSeconds / (_restMinutes * 60);
        caption = tr('Mola');
      case _ when _mode == SessionType.pomodoro:
        final total = Duration(minutes: _workMinutes);
        final left = total - _elapsed;
        shown = left.isNegative ? Duration.zero : left;
        progress = idle ? 0 : _elapsed.inSeconds / total.inSeconds;
        caption = _phase == _Phase.paused ? tr('Duraklatıldı') : tr('Odak');
      case _:
        shown = _elapsed;
        progress = (_elapsed.inSeconds % 3600) / 3600;
        caption = _phase == _Phase.paused
            ? tr('Duraklatıldı')
            : tr('Kronometre');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<SessionType>(
                showSelectedIcon: false,
                segments: [
                  for (final m in SessionType.values)
                    ButtonSegment(value: m, label: Text(m.label)),
                ],
                selected: {_mode},
                onSelectionChanged: idle
                    ? (s) => setState(() => _mode = s.first)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            SubjectDropdown(
              value: _subject,
              allowNone: true,
              label: tr('Ders (isteğe bağlı)'),
              onChanged: (v) => setState(() => _subject = v.isEmpty ? null : v),
            ),
            if (_mode == SessionType.pomodoro && idle) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MinutesPicker(
                      label: tr('Odak'),
                      value: _workMinutes,
                      options: const [15, 25, 30, 45, 50, 60],
                      onChanged: (v) => setState(() => _workMinutes = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MinutesPicker(
                      label: tr('Mola'),
                      value: _restMinutes,
                      options: const [5, 10, 15],
                      onChanged: (v) => setState(() => _restMinutes = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ToneButton(tone: _tone, onTap: _pickTone),
            ],
            const SizedBox(height: 20),
            _BreathingGlow(
              active: _phase == _Phase.work,
              color: context.brand.primary,
              // Pomodoroda süre azaldıkça bal azalır; molada kavanoz yeniden
              // dolar; kronometrede süre arttıkça bal yükselir (saatte bir
              // başa döner).
              child: HoneyDial(
                level: switch (_phase) {
                  _Phase.rest => progress,
                  _ when _mode == SessionType.pomodoro => 1 - progress,
                  _ => progress,
                },
                ring: progress,
                ringColor: _phase == _Phase.rest
                    ? context.brand.success
                    : context.brand.primaryDeep,
                flowing: _phase == _Phase.work || _phase == _Phase.rest,
                semanticsLabel: '$caption: ${_fmt(shown)}',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fmt(shown),
                      style: text.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      caption,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _Controls(
              phase: _phase,
              saving: _saving,
              onStart: _start,
              onPause: _pause,
              onResume: _resume,
              onFinish: () => _finishWork(completed: false),
              onSkipRest: _skipRest,
            ),
            if ((_phase == _Phase.work && _mode == SessionType.pomodoro) ||
                _phase == _Phase.rest) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _tone.silent
                        ? Icons.vibration_rounded
                        : Icons.notifications_active_outlined,
                    size: 16,
                    color: text.bodySmall?.color,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      tr('Uygulamadan çıksan da süre bitince: {tone}', {
                        'tone': _tone.label,
                      }),
                      textAlign: TextAlign.center,
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Bitiş sesi: Bal Kavanozu" düğmesi.
class _ToneButton extends StatelessWidget {
  const _ToneButton({required this.tone, required this.onTap});

  final AlarmTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                tone.silent
                    ? Icons.vibration_rounded
                    : Icons.music_note_rounded,
                color: context.brand.primaryDeep,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${tr('Bitiş sesi')}: '),
                      TextSpan(
                        text: tone.label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  style: text.bodyMedium,
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zil seçimi: 5 zil ve yalnızca titreşim. Dokununca dinletir ve seçer.
class _TonePicker extends StatefulWidget {
  const _TonePicker({required this.selected});

  final AlarmTone selected;

  @override
  State<_TonePicker> createState() => _TonePickerState();
}

class _TonePickerState extends State<_TonePicker> {
  late AlarmTone _tone = widget.selected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Bitiş sesi'),
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'Pomodoro ve mola bitince çalar; uygulama kapalıyken de. Dinlemek için dokun.',
              ),
              style: text.bodySmall,
            ),
            const SizedBox(height: 8),
            RadioGroup<AlarmTone>(
              groupValue: _tone,
              onChanged: (t) {
                if (t == null) return;
                setState(() => _tone = t);
                PomodoroAlarm.preview(t);
              },
              child: Column(
                children: [
                  for (final t in AlarmTone.values)
                    RadioListTile<AlarmTone>(
                      contentPadding: EdgeInsets.zero,
                      value: t,
                      title: Text(t.label),
                      secondary: Icon(
                        t.silent
                            ? Icons.vibration_rounded
                            : Icons.music_note_rounded,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context, _tone),
              child: Text(tr('Seç')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.phase,
    required this.saving,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onSkipRest,
  });

  final _Phase phase;
  final bool saving;
  final VoidCallback onStart, onPause, onResume, onFinish, onSkipRest;

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case _Phase.idle:
        return FilledButton.icon(
          onPressed: saving ? null : onStart,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(tr('Başlat')),
        );
      case _Phase.rest:
        return OutlinedButton(
          onPressed: onSkipRest,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: Text(tr('Molayı atla')),
        );
      case _Phase.work:
      case _Phase.paused:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: phase == _Phase.work ? onPause : onResume,
                icon: Icon(
                  phase == _Phase.work
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(
                  phase == _Phase.work ? tr('Duraklat') : tr('Devam'),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.stop_rounded),
                label: Text(tr('Bitir ve kaydet')),
              ),
            ),
          ],
        );
    }
  }
}

class _MinutesPicker extends StatelessWidget {
  const _MinutesPicker({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final o in options)
          DropdownMenuItem(
            value: o,
            child: Text(tr('{minutes} dk', {'minutes': o})),
          ),
      ],
      onChanged: (v) => onChanged(v ?? value),
    );
  }
}

/// Çalışma süresi istatistikleri (ListView içine gömülür).
class StudyStatsSection extends ConsumerWidget {
  const StudyStatsSection({
    super.key,
    required this.studentId,
    this.canEdit = false,
  });

  final String studentId;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(studySessionsProvider(studentId));
    final goal = ref.watch(goalsProvider(studentId)).value?.dailyMinutes;

    return AsyncView(
      value: sessions,
      onRetry: () => ref.invalidate(studySessionsProvider(studentId)),
      builder: (list) {
        final today = dateOnly(DateTime.now());
        final days = lastDays(7);
        int minutesOn(DateTime d) =>
            list
                .where((s) => dateOnly(s.startedAt) == d)
                .fold<int>(0, (m, s) => m + s.durationSec) ~/
            60;
        final perDay = [for (final d in days) minutesOn(d)];
        final week = perDay.fold<int>(0, (a, b) => a + b);
        final streak = studyStreak(list.map((s) => s.startedAt));

        final bySubject = <String?, int>{};
        for (final s in list.where((s) => !s.startedAt.isBefore(days.first))) {
          bySubject[s.subjectCode] =
              (bySubject[s.subjectCode] ?? 0) + s.durationSec;
        }
        final subjects = bySubject.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final timeFormat = DateFormat('d MMM HH:mm', localeTag);
        final brand = context.brand;

        final items = <Widget>[
          StatRow(
            children: [
              GlowStat(
                icon: Icons.timer_rounded,
                label: tr('Bugün'),
                value: minutesOn(today).toDouble(),
                format: (v) => formatMinutes(v.round()),
                caption: goal == null
                    ? tr('çalışma')
                    : tr('/ {time} hedef', {'time': formatMinutes(goal)}),
                color: brand.secondary,
              ),
              GlowStat(
                icon: Icons.date_range_rounded,
                label: tr('Son 7 gün'),
                value: week.toDouble(),
                format: (v) => formatMinutes(v.round()),
                caption: tr('çalışma'),
                color: brand.primary,
              ),
              GlowStat(
                icon: Icons.local_fire_department_rounded,
                label: tr('Seri'),
                value: streak.toDouble(),
                format: (v) => tr('{n} gün', {'n': v.round()}),
                caption: streak > 0 ? tr('devam ediyor 🔥') : tr('bugün başla'),
                color: brand.primaryDeep,
              ),
            ],
          ),
          SectionCard(
            title: tr('Son 7 gün'),
            subtitle: tr('Günlük çalışma (dakika)'),
            child: DailyBarChart(
              days: days,
              values: perDay,
              unit: tr('dk'),
              goal: goal,
            ),
          ),
          if (subjects.isNotEmpty)
            SectionCard(
              title: tr('Derslere göre'),
              subtitle: tr('Son 7 gün'),
              child: Column(
                children: [
                  for (final e in subjects)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        e.key == null
                            ? tr('Ders belirtilmedi')
                            : '${subjectByCode(e.key!).examType.label} '
                                  '${subjectByCode(e.key!).name}',
                      ),
                      trailing: Text(
                        formatMinutes(e.value ~/ 60),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            ),
          SectionCard(
            title: tr('Oturumlar'),
            subtitle: tr('Son 30 gün'),
            child: list.isEmpty
                ? Text(tr('Henüz kayıtlı çalışma oturumu yok.'))
                : Column(
                    children: [
                      for (final s in list.take(30))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            s.type == SessionType.pomodoro
                                ? Icons.timer_outlined
                                : Icons.av_timer,
                          ),
                          title: Text(
                            s.subjectCode == null
                                ? s.type.label
                                : subjectByCode(s.subjectCode!).name,
                          ),
                          subtitle: Text(timeFormat.format(s.startedAt)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatMinutes(s.minutes),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (canEdit)
                                IconButton(
                                  tooltip: tr('Sil'),
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final ok = await confirm(
                                      context,
                                      title: tr('Oturum silinsin mi?'),
                                      message: tr(
                                        '{p0} çalışma kaydı silinecek.',
                                        {'p0': formatMinutes(s.minutes)},
                                      ),
                                    );
                                    if (!ok) return;
                                    await ref
                                        .read(trackingRepositoryProvider)
                                        .deleteSession(s.id);
                                    ref.invalidate(
                                      studySessionsProvider(studentId),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, c) in items.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              staggered(i, c),
            ],
          ],
        );
      },
    );
  }
}

/// 135 → "2 sa 15 dk", 40 → "40 dk"
String formatMinutes(int minutes) {
  if (minutes < 60) return tr('{minutes} dk', {'minutes': minutes});
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0
      ? tr('{h} sa', {'h': h})
      : tr('{h} sa {m} dk', {'h': h, 'm': m});
}

/// Odak sürerken halkanın etrafında nefes alıp veren bal ışığı
/// (4 sn nefes al, 4 sn ver — sakinleştiren bir tempo).
class _BreathingGlow extends StatelessWidget {
  const _BreathingGlow({
    required this.active,
    required this.color,
    required this.child,
  });

  final bool active;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return LoopBuilder(
      period: const Duration(seconds: 8),
      child: child,
      builder: (_, t, child) {
        final b = 0.5 - 0.5 * math.cos(t * 2 * math.pi);
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.18 + 0.27 * b),
                blurRadius: 18 + 26 * b,
                spreadRadius: 2 + 8 * b,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
