import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/sound/app_sounds.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../avatar/data/avatar_repository.dart';
import '../../avatar/presentation/student_avatar.dart';
import '../../learn/data/practice_repository.dart';
import '../../learn/presentation/learn_screen.dart';
import '../data/duel_repository.dart';

const _duelColors = [Color(0xFFFF7A45), Color(0xFFC2185B)];

/// "1:35,2" (dakika:saniye,onda bir).
String formatDuelTime(int ms) {
  final d = Duration(milliseconds: ms);
  final s = d.inSeconds % 60;
  final tenth = (ms % 1000) ~/ 100;
  return '${d.inMinutes}:${s.toString().padLeft(2, '0')},$tenth';
}

/// Eğitim sekmesindeki düello kartı; sırası gelen düello sayısını gösterir.
class DuelEntryCard extends ConsumerWidget {
  const DuelEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duels = ref.watch(duelsProvider).value ?? const [];
    final waiting = duels.where((d) => d.status == DuelStatus.yourTurn).length;
    return Semantics(
      button: true,
      label: tr('Arkadaş düellosu'),
      child: GestureDetector(
        onTap: () => context.push('/student/duels'),
        child: PressScale(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _duelColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: _duelColors.last.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text('⚔️', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Arkadaş düellosu'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        waiting > 0
                            ? tr('{n} düello seni bekliyor', {'n': waiting})
                            : tr(
                                'Arkadaşınla aynı 10 soruyu çöz, kazanan ödül alsın',
                              ),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (waiting > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$waiting',
                      style: TextStyle(
                        color: _duelColors.last,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Düellolarım: sırası gelenler, bekleyenler ve sonuçlananlar.
class DuelsScreen extends ConsumerWidget {
  const DuelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duels = ref.watch(duelsProvider);
    // Kazanılan düello avatar ödülü açmış olabilir.
    ref.listen(duelsProvider, (prev, next) {
      final won = next.value?.where((d) => d.result == DuelResult.won).length;
      final before = prev?.value
          ?.where((d) => d.result == DuelResult.won)
          .length;
      if (won != null && won != before) ref.invalidate(avatarUnlocksProvider);
    });
    return Scaffold(
      appBar: AppBar(title: Text(tr('Arkadaş düellosu'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showNewDuelSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('Düello başlat')),
      ),
      body: AsyncView(
        value: duels,
        onRetry: () => ref.invalidate(duelsProvider),
        builder: (list) {
          final mine = list.where((d) => d.status == DuelStatus.yourTurn);
          final wait = list.where((d) => d.status == DuelStatus.waiting);
          final past = list.where(
            (d) =>
                d.status == DuelStatus.done || d.status == DuelStatus.expired,
          );
          return RefreshIndicator(
            onRefresh: () => ref.refresh(duelsProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                const _RulesCard(compact: true),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: EmptyState(
                      title: tr('Henüz düello yok'),
                      message: tr(
                        'Bir arkadaşını seç, aynı 10 soruyu çözün. Kim daha iyi, görelim!',
                      ),
                    ),
                  ),
                if (mine.isNotEmpty) _Section(tr('Sıra sende'), mine),
                if (wait.isNotEmpty) _Section(tr('Rakibin bekleniyor'), wait),
                if (past.isNotEmpty) _Section(tr('Sonuçlananlar'), past),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.duels);
  final String title;
  final Iterable<Duel> duels;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      for (final d in duels) _DuelTile(duel: d),
    ],
  );
}

class _DuelTile extends StatelessWidget {
  const _DuelTile({required this.duel});
  final Duel duel;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final look = subjectLook(duel.subject);
    final (String label, Color color) = switch ((duel.status, duel.result)) {
      (DuelStatus.yourTurn, _) => (
        duel.isChallenger ? tr('Başla') : tr('Kabul et'),
        _duelColors.first,
      ),
      (DuelStatus.waiting, _) => (tr('Bekleniyor'), brand.secondary),
      (DuelStatus.done, DuelResult.won) => (tr('Kazandın 🏆'), brand.success),
      (DuelStatus.done, DuelResult.lost) => (tr('Kaybettin'), brand.danger),
      (DuelStatus.done, _) => (tr('Berabere'), brand.info),
      _ => (tr('Süresi doldu'), brand.ink.withValues(alpha: 0.5)),
    };
    final sub = switch (duel.status) {
      DuelStatus.yourTurn when !duel.isChallenger =>
        duel.theirFinished
            ? tr('{name} bitirdi, sıra sende', {'name': duel.opponentName})
            : tr('{name} seni düelloya çağırdı', {'name': duel.opponentName}),
      DuelStatus.yourTurn => tr('Daveti gönderdin, önce sen çöz'),
      DuelStatus.waiting => tr('{c} / 10 doğru · {t}', {
        'c': duel.myCorrect,
        't': formatDuelTime(duel.myMs ?? 0),
      }),
      DuelStatus.done => tr('{a} - {b} doğru', {
        'a': duel.myCorrect,
        'b': duel.theirCorrect,
      }),
      DuelStatus.expired => tr('Düello tamamlanmadı'),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              StudentAvatar(config: duel.opponentAvatar, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      duel.opponentName,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Row(
                      children: [
                        Icon(look.icon, size: 15, color: look.color),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            practiceSubjectLabel(duel.subject),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: look.color,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(sub, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: duel.status == DuelStatus.yourTurn
                      ? color
                      : color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: duel.status == DuelStatus.yourTurn
                        ? Colors.white
                        : color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final nav = Navigator.of(context, rootNavigator: true);
    if (duel.status == DuelStatus.yourTurn) {
      nav.push(
        MaterialPageRoute<void>(builder: (_) => DuelIntroScreen(duel: duel)),
      );
    } else if (duel.status != DuelStatus.expired) {
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => DuelResultScreen(duelId: duel.id),
        ),
      );
    }
  }
}

/// Düello kuralları. Test başlamadan önce mutlaka gösterilir.
class _RulesCard extends StatelessWidget {
  const _RulesCard({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rules = [
      ('📝', tr('İkiniz de aynı 10 soruyu çözersiniz.')),
      ('✅', tr('En çok doğru yapan kazanır.')),
      (
        '⏱️',
        tr('Doğru sayınız eşitse testi daha kısa sürede bitiren kazanır.'),
      ),
      if (!compact) ...[
        (
          '▶️',
          tr(
            'Süre "Başla"ya bastığın anda başlar ve durmaz. 30 dakika içinde bitirmelisin.',
          ),
        ),
        (
          '➡️',
          tr(
            'Cevabı seçince sonraki soruya geçersin, geri dönülmez. Emin değilsen "Boş geç".',
          ),
        ),
      ],
      (
        '🏅',
        tr(
          'Kazanana avatar ödülü: 1. galibiyette madalya, 5\'te defne tacı, 10\'da şampiyon pelerini.',
        ),
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _duelColors.first.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _duelColors.first.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Kurallar'),
            style: TextStyle(
              color: _duelColors.last,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          for (final (icon, text) in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(fontWeight: FontWeight.w700),
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

// --- Yeni düello ------------------------------------------------------------

Future<void> showNewDuelSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _NewDuelSheet(),
    );

class _NewDuelSheet extends ConsumerStatefulWidget {
  const _NewDuelSheet();

  @override
  ConsumerState<_NewDuelSheet> createState() => _NewDuelSheetState();
}

class _NewDuelSheetState extends ConsumerState<_NewDuelSheet> {
  String _subject = 'TYT_MAT';
  String? _opponent;
  bool _saving = false;

  Future<void> _create() async {
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final rootNav = Navigator.of(context, rootNavigator: true);
    try {
      final id = await ref
          .read(duelRepositoryProvider)
          .create(_opponent!, _subject);
      ref.invalidate(duelsProvider);
      final duels = await ref.read(duelsProvider.future);
      final duel = duels.firstWhere((d) => d.id == id);
      nav.pop();
      rootNav.push(
        MaterialPageRoute<void>(builder: (_) => DuelIntroScreen(duel: duel)),
      );
    } on DuelException catch (e) {
      if (!mounted) return;
      showMessage(context, switch (e.error) {
        DuelError.alreadyOpen => tr(
          'Bu arkadaşınla zaten açık bir düellon var.',
        ),
        DuelError.dailyLimit => tr('Bugün en fazla 10 düello başlatabilirsin.'),
        _ => tr('Düello başlatılamadı. Tekrar dene.'),
      });
    } catch (_) {
      if (mounted) {
        showMessage(context, tr('Düello başlatılamadı. Tekrar dene.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ops = ref.watch(duelOpponentsProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Yeni düello'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _subject,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('Ders')),
              items: [
                for (final s in practiceSubjects)
                  DropdownMenuItem(
                    value: s,
                    child: Text(
                      s.startsWith('AYT_')
                          ? 'AYT · ${practiceSubjectLabel(s).replaceFirst('AYT ', '')}'
                          : 'TYT · ${practiceSubjectLabel(s)}',
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _subject = v!),
            ),
            const SizedBox(height: 12),
            Text(
              tr('Rakibini seç'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: AsyncView(
                value: ops,
                onRetry: () => ref.invalidate(duelOpponentsProvider),
                builder: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          tr('Dershanende henüz başka öğrenci yok.'),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final o in list)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              leading: StudentAvatar(
                                config: o.avatar,
                                size: 40,
                              ),
                              title: Text(
                                o.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              trailing: Icon(
                                _opponent == o.id
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: _opponent == o.id
                                    ? _duelColors.last
                                    : null,
                              ),
                              onTap: () => setState(() => _opponent = o.id),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _opponent == null || _saving ? null : _create,
              style: FilledButton.styleFrom(
                backgroundColor: _duelColors.last,
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Text('⚔️'),
              label: Text(tr('Davet et')),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Başlamadan önce ---------------------------------------------------------

/// Kuralların gösterildiği ekran; süre yalnızca "Başla" ile başlar.
class DuelIntroScreen extends ConsumerStatefulWidget {
  const DuelIntroScreen({super.key, required this.duel});
  final Duel duel;

  @override
  ConsumerState<DuelIntroScreen> createState() => _DuelIntroScreenState();
}

class _DuelIntroScreenState extends ConsumerState<DuelIntroScreen> {
  bool _starting = false;

  Future<void> _start() async {
    setState(() => _starting = true);
    final nav = Navigator.of(context);
    try {
      final ids = await ref.read(duelRepositoryProvider).start(widget.duel.id);
      final pool = await ref.read(
        questionPoolProvider(widget.duel.subject).future,
      );
      final byId = {for (final q in pool) q.id: q};
      final questions = [for (final id in ids) byId[id]!];
      nav.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              DuelPlayScreen(duel: widget.duel, questions: questions),
        ),
      );
    } on DuelException catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      showMessage(
        context,
        e.error == DuelError.expired
            ? tr('Bu düellonun süresi doldu.')
            : tr('Düello başlatılamadı. Tekrar dene.'),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _starting = false);
      showMessage(context, tr('Düello başlatılamadı. Tekrar dene.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.duel;
    final look = subjectLook(d.subject);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Düello'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: _duelColors),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tr('Sen'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('⚔️', style: TextStyle(fontSize: 34)),
                    ),
                    StudentAvatar(config: d.opponentAvatar, size: 52),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        d.opponentName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(look.icon, size: 16, color: look.color),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          tr('{subject} · 10 soru', {
                            'subject': practiceSubjectLabel(d.subject),
                          }),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: look.color,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (d.theirFinished) ...[
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      '{name} testi bitirdi. Sonucu sen bitirince görünecek.',
                      {'name': d.opponentName},
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _RulesCard(),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _starting ? null : _start,
            style: FilledButton.styleFrom(
              backgroundColor: _duelColors.last,
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(tr('Başla')),
          ),
          const SizedBox(height: 8),
          Text(
            tr('Süre Başla\'ya bastığında başlar.'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// --- Oyun ---------------------------------------------------------------------

class DuelPlayScreen extends ConsumerStatefulWidget {
  const DuelPlayScreen({
    super.key,
    required this.duel,
    required this.questions,
  });
  final Duel duel;
  final List<PracticeQuestion> questions;

  @override
  ConsumerState<DuelPlayScreen> createState() => _DuelPlayScreenState();
}

class _DuelPlayScreenState extends ConsumerState<DuelPlayScreen> {
  final _watch = Stopwatch()..start();
  late final Timer _tick;
  final _answers = <int>[];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  Future<void> _answer(int option) async {
    if (_sending) return;
    HapticFeedback.selectionClick();
    setState(() => _answers.add(option));
    if (_answers.length < widget.questions.length) return;
    _watch.stop();
    setState(() => _sending = true);
    final nav = Navigator.of(context);
    try {
      await ref.read(duelRepositoryProvider).finish(widget.duel.id, _answers);
      ref.invalidate(duelsProvider);
      nav.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DuelResultScreen(
            duelId: widget.duel.id,
            questions: widget.questions,
            answers: List.of(_answers),
          ),
        ),
      );
    } on DuelException catch (e) {
      if (!mounted) return;
      showMessage(
        context,
        e.error == DuelError.timeout
            ? tr('30 dakika doldu; bu düello tamamlanamadı.')
            : tr('Cevaplar gönderilemedi. İnternet bağlantını kontrol et.'),
      );
      setState(() {
        _sending = false;
        if (e.error != DuelError.timeout) _answers.removeLast();
      });
    } catch (_) {
      if (!mounted) return;
      showMessage(
        context,
        tr('Cevaplar gönderilemedi. İnternet bağlantını kontrol et.'),
      );
      setState(() {
        _sending = false;
        _answers.removeLast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = _answers.length.clamp(0, widget.questions.length - 1);
    final q = widget.questions[i];
    final look = subjectLook(widget.duel.subject);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final leave = await confirm(
          context,
          title: tr('Düellodan çıkılsın mı?'),
          message: tr(
            'Süre işlemeye devam eder ve cevapların kaydedilmez. 30 dakika içinde dönüp baştan çözebilirsin.',
          ),
          action: tr('Çık'),
        );
        if (leave) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _duelColors.last,
          foregroundColor: Colors.white,
          title: Text(
            tr('Soru {n} / {t}', {'n': i + 1, 't': widget.questions.length}),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '⏱ ${formatDuelTime(_watch.elapsedMilliseconds)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: _sending
            ? const Center(child: BizzLoader())
            : ListView(
                key: ValueKey(i),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                children: [
                  AnimatedLinearProgress(
                    value: i / widget.questions.length,
                    color: _duelColors.last,
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            q.topic,
                            style: TextStyle(
                              color: look.color,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            q.text,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var k = 0; k < q.options.length; k++)
                    OptionTile(
                      letter: 'ABCDE'[k],
                      text: q.options[k],
                      state: OptState.idle,
                      onTap: () => _answer(k),
                    ),
                  TextButton(
                    onPressed: () => _answer(-1),
                    child: Text(tr('Boş geç')),
                  ),
                ],
              ),
      ),
    );
  }
}

// --- Sonuç ----------------------------------------------------------------------

class DuelResultScreen extends ConsumerStatefulWidget {
  const DuelResultScreen({
    super.key,
    required this.duelId,
    this.questions,
    this.answers,
  });
  final String duelId;

  /// Oyundan gelindiyse cevap özeti için.
  final List<PracticeQuestion>? questions;
  final List<int>? answers;

  @override
  ConsumerState<DuelResultScreen> createState() => _DuelResultScreenState();
}

class _DuelResultScreenState extends ConsumerState<DuelResultScreen> {
  bool _celebrated = false;

  @override
  Widget build(BuildContext context) {
    final duels = ref.watch(duelsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Düello sonucu'))),
      body: AsyncView(
        value: duels,
        onRetry: () => ref.invalidate(duelsProvider),
        builder: (list) {
          final d = list.where((x) => x.id == widget.duelId).firstOrNull;
          if (d == null) return const Center(child: BizzLoader());
          if (d.result == DuelResult.won && !_celebrated) {
            _celebrated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              AppSounds.play(AppSound.bizzTap);
              celebrate(context);
              ref.invalidate(avatarUnlocksProvider);
            });
          }
          return _ResultBody(
            duel: d,
            questions: widget.questions,
            answers: widget.answers,
          );
        },
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.duel, this.questions, this.answers});
  final Duel duel;
  final List<PracticeQuestion>? questions;
  final List<int>? answers;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final d = duel;
    final (String emoji, String title) = switch (d.result) {
      DuelResult.won => ('🏆', tr('Kazandın!')),
      DuelResult.lost => ('💪', tr('{name} kazandı', {'name': d.opponentName})),
      DuelResult.draw => ('🤝', tr('Berabere!')),
      null => ('⏳', tr('Rakibin bekleniyor')),
    };
    final tieOnCorrect = d.result != null && d.myCorrect == d.theirCorrect;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Center(child: Text(emoji, style: const TextStyle(fontSize: 64))),
        Center(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            d.result == null
                ? tr(
                    '{name} bitirince sonuç gelecek; sana bildirim göndereceğiz.',
                    {'name': d.opponentName},
                  )
                : tieOnCorrect
                ? tr(
                    'Doğru sayınız eşit; testi daha kısa sürede bitiren kazandı.',
                  )
                : tr('En çok doğru yapan kazandı.'),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ScoreCard(
                title: tr('Sen'),
                correct: d.myCorrect,
                ms: d.myMs,
                highlight: d.result == DuelResult.won,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ScoreCard(
                title: d.opponentName,
                avatar: StudentAvatar(config: d.opponentAvatar, size: 36),
                correct: d.theirCorrect,
                ms: d.theirMs,
                highlight: d.result == DuelResult.lost,
              ),
            ),
          ],
        ),
        if (d.result == DuelResult.won) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: brand.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('🏅', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr(
                      'Galibiyetler avatar ödülü açar: 1. galibiyette madalya, 5\'te defne tacı, 10\'da şampiyon pelerini.',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/student/avatar'),
                  child: Text(tr('Avatarım')),
                ),
              ],
            ),
          ),
        ],
        if (questions != null && answers != null) ...[
          const SizedBox(height: 18),
          Text(
            tr('Cevapların'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < questions!.length; i++)
            _ReviewRow(index: i, q: questions![i], picked: answers![i]),
        ],
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.title,
    required this.correct,
    required this.ms,
    required this.highlight,
    this.avatar,
  });
  final String title;
  final Widget? avatar;
  final int? correct;
  final int? ms;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? brand.success : brand.ink.withValues(alpha: 0.12),
          width: highlight ? 2.5 : 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (avatar != null) ...[avatar!, const SizedBox(width: 6)],
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            correct == null ? '?' : '$correct / 10',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          Text(tr('doğru'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            ms == null ? '—' : '⏱ ${formatDuelTime(ms!)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.index,
    required this.q,
    required this.picked,
  });
  final int index;
  final PracticeQuestion q;
  final int picked;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final right = picked == q.answer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            picked < 0
                ? Icons.remove_circle_outline_rounded
                : right
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            color: picked < 0
                ? brand.ink.withValues(alpha: 0.4)
                : right
                ? brand.success
                : brand.danger,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${index + 1}. ${q.text}\n${tr('Doğru cevap')}: ${'ABCDE'[q.answer]}) ${q.options[q.answer]}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
