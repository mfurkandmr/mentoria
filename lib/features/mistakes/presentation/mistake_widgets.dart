import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/motion.dart';
import '../../../shared/widgets/bizz.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../tracking/data/tracking_models.dart';
import '../../tracking/data/tracking_repository.dart';
import '../data/mistake_repository.dart';

/// Kartın tekrar merdiveni: 1 → 3 → 7 → 21 gün, sonra öğrenildi.
class StageLadder extends StatelessWidget {
  const StageLadder({super.key, required this.stage, this.compact = false});

  final int stage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final labels = [
      for (final g in mistakeGaps) tr('{n} g', {'n': g}),
      '',
    ];
    return Semantics(
      label: stage >= 4
          ? tr('Öğrenildi')
          : tr('{n}. tekrar basamağı', {'n': stage + 1}),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Container(
                width: compact ? 6 : 10,
                height: 2,
                color: i <= stage
                    ? brand.success
                    : brand.ink.withValues(alpha: 0.15),
              ),
            Container(
              width: compact ? 20 : 30,
              height: compact ? 20 : 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < stage
                    ? brand.success
                    : i == stage
                    ? brand.primary
                    : brand.ink.withValues(alpha: 0.08),
                border: i == stage
                    ? Border.all(color: brand.primaryDeep, width: 2)
                    : null,
              ),
              child: i == labels.length - 1
                  ? Icon(
                      Icons.emoji_events_rounded,
                      size: compact ? 12 : 16,
                      color: i < stage || stage >= 4
                          ? Colors.white
                          : brand.ink.withValues(alpha: 0.5),
                    )
                  : Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: compact ? 8 : 10,
                        fontWeight: FontWeight.w900,
                        color: i < stage ? Colors.white : brand.ink,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kart fotoğrafı (özel kovadan); yoksa ders renginde yer tutucu.
class MistakePhoto extends ConsumerWidget {
  const MistakePhoto({
    super.key,
    required this.card,
    this.height = 160,
    this.fit = BoxFit.cover,
  });

  final MistakeCard card;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = card.photoPath;
    final brand = context.brand;
    Widget placeholder([IconData icon = Icons.edit_note_rounded]) => Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            brand.primary.withValues(alpha: 0.35),
            brand.secondary.withValues(alpha: 0.25),
          ],
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      // Büyük görünümde fotoğraf yoksa not, sorunun yerine geçer.
      child: height > 200 && (card.note ?? '').isNotEmpty
          ? Text(
              card.note!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: brand.ink,
              ),
            )
          : Icon(icon, size: 40, color: brand.primaryDeep),
    );
    if (path == null) return placeholder();
    final photo = ref.watch(mistakePhotoProvider(path));
    return photo.when(
      data: (bytes) => bytes == null
          ? placeholder(Icons.broken_image_outlined)
          : Image.memory(
              bytes,
              height: height,
              width: double.infinity,
              fit: fit,
              gaplessPlayback: true,
              semanticLabel: tr('Soru fotoğrafı'),
            ),
      loading: () => SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => placeholder(Icons.broken_image_outlined),
    );
  }
}

String _topicName(List<Topic> topics, int? id) =>
    topics.where((t) => t.id == id).firstOrNull?.name ?? '';

/// Bir kart satırı (liste görünümü).
class MistakeTile extends ConsumerWidget {
  const MistakeTile({super.key, required this.card, this.onTap});

  final MistakeCard card;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicsProvider).value ?? const <Topic>[];
    final text = Theme.of(context).textTheme;
    final topic = _topicName(topics, card.topicId);
    final now = DateTime.now();
    final due = card.isDue(now);
    final when = card.mastered
        ? tr('Öğrenildi')
        : due
        ? tr('Bugün tekrar')
        : tr('{date} tekrar', {
            'date': DateFormat('d MMM', localeTag).format(card.dueOn),
          });
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              height: 92,
              child: MistakePhoto(card: card, height: 92),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        card.subject?.name ?? card.subjectCode,
                        if (topic.isNotEmpty) topic,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((card.note ?? '').isNotEmpty)
                      Text(
                        card.note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    const SizedBox(height: 6),
                    // Dar ekranda / büyük yazıda tarih alta iner.
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StageLadder(stage: card.stage, compact: true),
                        Text(
                          when,
                          style: text.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: due ? context.brand.danger : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Öğrencinin ya da (salt okunur) koç / velinin gördüğü defter içeriği.
class MistakesView extends ConsumerWidget {
  const MistakesView({
    super.key,
    required this.studentId,
    this.readOnly = false,
    this.bottomPadding = 96,
  });

  final String studentId;
  final bool readOnly;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(mistakeCardsProvider(studentId));
    return AsyncView(
      value: cards,
      onRetry: () => ref.invalidate(mistakeCardsProvider(studentId)),
      builder: (all) {
        final now = DateTime.now();
        final due = all.where((c) => c.isDue(now)).toList();
        final upcoming = all
            .where((c) => !c.mastered && !c.isDue(now))
            .toList();
        final mastered = all.where((c) => c.mastered).toList();
        if (all.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              EmptyState(
                title: readOnly
                    ? tr('Hata defteri boş')
                    : tr('Hata defterin boş'),
                message: readOnly
                    ? tr(
                        'Öğrenci yanlış yaptığı soruları ekledikçe burada görünür.',
                      )
                    : tr(
                        'Yanlış yaptığın bir sorunun fotoğrafını çek; Bızz onu 1, 3, 7 ve 21 gün sonra sana yeniden sorsun. Unutma eğrisini birlikte yeneriz!',
                      ),
              ),
            ],
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(mistakeCardsProvider(studentId).future),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
            children: [
              _SummaryHeader(
                due: due.length,
                upcoming: upcoming.length,
                mastered: mastered.length,
                readOnly: readOnly,
                onReview: due.isEmpty || readOnly
                    ? null
                    : () => openMistakeReview(context, studentId, due),
              ),
              const SizedBox(height: 12),
              if (readOnly) ...[
                _WeakTopics(cards: all),
                const SizedBox(height: 12),
              ],
              for (final (title, list) in [
                (tr('Bugün tekrar'), due),
                (tr('Yaklaşan tekrarlar'), upcoming),
                (tr('Öğrenildi'), mastered),
              ])
                if (list.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                    child: Text(
                      '$title · ${list.length}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  for (final c in list)
                    MistakeTile(
                      card: c,
                      onTap: () =>
                          showMistakeDetail(context, c, canDelete: !readOnly),
                    ),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.due,
    required this.upcoming,
    required this.mastered,
    required this.readOnly,
    this.onReview,
  });

  final int due;
  final int upcoming;
  final int mastered;
  final bool readOnly;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    Widget stat(int n, String label) => Expanded(
      child: Column(
        children: [
          CountUp(
            value: n.toDouble(),
            format: (v) => '${v.round()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brand.primaryDeep, brand.secondary],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              stat(due, tr('bugün tekrar')),
              stat(upcoming, tr('yolda')),
              stat(mastered, tr('öğrenildi')),
              if (!readOnly)
                const Bizz(size: 64, mood: BizzMood.happy, interactive: false),
            ],
          ),
          if (onReview != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onReview,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: brand.primaryDeep,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(tr('{n} soruyu şimdi tekrar et', {'n': due})),
            ),
          ] else if (!readOnly && due == 0) ...[
            const SizedBox(height: 8),
            Text(
              tr('Bugünlük tekrar yok. Harika! 🎉'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Koç / veli için: en çok hata yapılan dersler ve konular.
class _WeakTopics extends ConsumerWidget {
  const _WeakTopics({required this.cards});

  final List<MistakeCard> cards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicsProvider).value ?? const <Topic>[];
    final counts = <String, int>{};
    for (final c in cards) {
      final topic = _topicName(topics, c.topicId);
      final key = [
        c.subject?.name ?? c.subjectCode,
        if (topic.isNotEmpty) topic,
      ].join(' · ');
      // Tekrarda yeniden yanlış yapılanlar daha ağır sayılır.
      counts[key] = (counts[key] ?? 0) + 1 + c.fails;
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = top.isEmpty ? 1 : top.first.value;
    return SectionCard(
      title: tr('En çok takıldığı yerler'),
      subtitle: tr('Hata sayısı ve tekrarda yeniden yanlışlara göre'),
      child: Column(
        children: [
          for (final e in top.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      e.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: AnimatedLinearProgress(value: e.value / max),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${e.value}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w800),
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

/// Kart ayrıntısı: büyük fotoğraf, not, tekrar merdiveni; öğrenci silebilir.
Future<void> showMistakeDetail(
  BuildContext context,
  MistakeCard card, {
  required bool canDelete,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => Consumer(
    builder: (context, ref, _) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: MistakePhoto(
                  card: card,
                  height: 320,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              card.subject?.name ?? card.subjectCode,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            if ((card.note ?? '').isNotEmpty) Text(card.note!),
            const SizedBox(height: 12),
            Center(child: StageLadder(stage: card.stage)),
            if (card.fails > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  tr('Tekrarda {n} kez yeniden yanlış yapıldı', {
                    'n': card.fails,
                  }),
                  textAlign: TextAlign.center,
                ),
              ),
            if (canDelete) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () async {
                  final ok = await confirm(
                    context,
                    title: tr('Kart silinsin mi?'),
                    message: tr('Fotoğrafı ve tekrar geçmişi de silinir.'),
                    action: tr('Sil'),
                  );
                  if (!ok || !context.mounted) return;
                  final nav = Navigator.of(context);
                  await ref.read(mistakeRepositoryProvider).deleteCard(card);
                  ref.invalidate(mistakeCardsProvider(card.studentId));
                  nav.pop();
                },
                icon: const Icon(Icons.delete_outline),
                label: Text(tr('Kartı sil')),
              ),
            ],
          ],
        ),
      ),
    ),
  ),
);

/// Yeni hata kartı: fotoğraf (kamera / galeri), ders, konu, not.
Future<void> showAddMistakeSheet(BuildContext context, String studentId) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddMistakeSheet(studentId: studentId),
    );

class _AddMistakeSheet extends ConsumerStatefulWidget {
  const _AddMistakeSheet({required this.studentId});

  final String studentId;

  @override
  ConsumerState<_AddMistakeSheet> createState() => _AddMistakeSheetState();
}

class _AddMistakeSheetState extends ConsumerState<_AddMistakeSheet> {
  final _note = TextEditingController();
  Uint8List? _photo;
  String _ext = 'jpg';
  String _subject = 'TYT_MAT';
  int? _topic;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final ext = file.name.split('.').last.toLowerCase();
      setState(() {
        _photo = bytes;
        _ext = const {'png', 'webp'}.contains(ext) ? ext : 'jpg';
      });
    } catch (_) {
      if (mounted) {
        showMessage(context, tr('Fotoğraf alınamadı. İzinleri kontrol et.'));
      }
    }
  }

  Future<void> _save() async {
    if (_photo == null && _note.text.trim().isEmpty) {
      showMessage(context, tr('Bir fotoğraf ya da kısa bir not ekle.'));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(mistakeRepositoryProvider)
          .addCard(
            widget.studentId,
            MistakeDraft(
              subjectCode: _subject,
              topicId: _topic,
              note: _note.text,
              photo: _photo,
              photoExtension: _ext,
            ),
          );
      ref.invalidate(mistakeCardsProvider(widget.studentId));
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
      showMessage(
        context,
        tr('Deftere eklendi. Bızz yarın sana yeniden soracak! 🐝'),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topics = (ref.watch(topicsProvider).value ?? const <Topic>[])
        .where((t) => t.subjectCode == _subject)
        .toList();
    final brand = context.brand;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('Hata defterine ekle'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _photo == null
                    ? Container(
                        height: 150,
                        color: brand.primary.withValues(alpha: 0.18),
                        child: Row(
                          children: [
                            Expanded(
                              child: _PickButton(
                                icon: Icons.photo_camera_rounded,
                                label: tr('Fotoğraf çek'),
                                onTap: () => _pick(ImageSource.camera),
                              ),
                            ),
                            Expanded(
                              child: _PickButton(
                                icon: Icons.photo_library_rounded,
                                label: tr('Galeriden seç'),
                                onTap: () => _pick(ImageSource.gallery),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        children: [
                          Image.memory(
                            _photo!,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: IconButton.filledTonal(
                              tooltip: tr('Fotoğrafı kaldır'),
                              onPressed: () => setState(() => _photo = null),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _subject,
                isExpanded: true,
                decoration: InputDecoration(labelText: tr('Ders')),
                items: [
                  for (final s in examSubjects)
                    DropdownMenuItem(
                      value: s.code,
                      child: Text('${s.examType.label} · ${s.name}'),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _subject = v ?? _subject;
                  _topic = null;
                }),
              ),
              if (topics.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  key: ValueKey(_subject),
                  initialValue: _topic,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: tr('Konu (isteğe bağlı)'),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text(tr('Seçilmedi'))),
                    for (final t in topics)
                      DropdownMenuItem(
                        value: t.id,
                        child: Text(t.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _topic = v),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLength: 500,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: tr('Nerede takıldın? (isteğe bağlı)'),
                  hintText: tr('ör. işlem hatası, formülü unuttum'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bookmark_add_rounded),
                label: Text(tr('Deftere ekle')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 36, color: context.brand.primaryDeep),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

// --- Tekrar oturumu ------------------------------------------------------------

Future<void> openMistakeReview(
  BuildContext context,
  String studentId,
  List<MistakeCard> due,
) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => MistakeReviewScreen(studentId: studentId, cards: due),
  ),
);

/// Tekrarı gelen kartlar tek tek: önce soru, öğrenci kağıtta çözer, sonra
/// "Çözdüm" / "Yine yapamadım".
class MistakeReviewScreen extends ConsumerStatefulWidget {
  const MistakeReviewScreen({
    super.key,
    required this.studentId,
    required this.cards,
  });

  final String studentId;
  final List<MistakeCard> cards;

  @override
  ConsumerState<MistakeReviewScreen> createState() =>
      _MistakeReviewScreenState();
}

class _MistakeReviewScreenState extends ConsumerState<MistakeReviewScreen> {
  int _i = 0;
  int _solved = 0;
  int _mastered = 0;
  bool _busy = false;

  Future<void> _answer(bool solved) async {
    if (_busy) return;
    setState(() => _busy = true);
    final card = widget.cards[_i];
    try {
      final next = await ref
          .read(mistakeRepositoryProvider)
          .review(card, solved: solved);
      if (!mounted) return;
      solved ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
      setState(() {
        if (solved) _solved++;
        if (next.mastered) _mastered++;
        _i++;
        _busy = false;
      });
      if (_i == widget.cards.length) {
        ref.invalidate(mistakeCardsProvider(widget.studentId));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _solved > 0) celebrate(context);
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.cards.length;
    final done = _i >= total;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          done
              ? tr('Tekrar bitti')
              : tr('{i} / {n}', {'i': _i + 1, 'n': total}),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: AnimatedLinearProgress(value: _i / total),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: Motion.of(context)
              ? const Duration(milliseconds: 320)
              : Duration.zero,
          transitionBuilder: (child, anim) => SlideTransition(
            position: Tween(
              begin: const Offset(0.3, 0),
              end: Offset.zero,
            ).animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: done
              ? _ReviewDone(
                  key: const ValueKey('done'),
                  solved: _solved,
                  total: total,
                  mastered: _mastered,
                )
              : Padding(
                  key: ValueKey(_i),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: InteractiveViewer(
                            child: MistakePhoto(
                              card: widget.cards[_i],
                              height: double.infinity,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.cards[_i].subject?.name ?? '',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if ((widget.cards[_i].note ?? '').isNotEmpty)
                        Text(tr('Notun: {n}', {'n': widget.cards[_i].note!})),
                      const SizedBox(height: 8),
                      Center(child: StageLadder(stage: widget.cards[_i].stage)),
                      const SizedBox(height: 8),
                      Text(
                        tr(
                          'Soruyu kağıtta yeniden çöz, sonra dürüstçe işaretle.',
                        ),
                        textAlign: TextAlign.center,
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : () => _answer(false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: context.brand.danger,
                                minimumSize: const Size.fromHeight(56),
                              ),
                              icon: const Icon(Icons.replay_rounded),
                              label: Text(tr('Yine yapamadım')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _busy ? null : () => _answer(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: context.brand.success,
                                minimumSize: const Size.fromHeight(56),
                              ),
                              icon: const Icon(Icons.check_rounded),
                              label: Text(tr('Çözdüm')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _ReviewDone extends StatelessWidget {
  const _ReviewDone({
    super.key,
    required this.solved,
    required this.total,
    required this.mastered,
  });

  final int solved;
  final int total;
  final int mastered;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Bizz(
              size: 150,
              mood: solved == total ? BizzMood.happy : BizzMood.idle,
              interactive: false,
            ),
            const SizedBox(height: 16),
            Text(
              tr('{s} / {n} soruyu çözdün', {'s': solved, 'n': total}),
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              mastered > 0
                  ? tr('{m} soru artık tamamen öğrenildi! 🏆', {'m': mastered})
                  : solved == total
                  ? tr(
                      'Hepsi doğru! Bir sonraki tekrar daha ileri bir tarihte.',
                    )
                  : tr(
                      'Yapamadıkların yarın yeniden gelecek. Pes etmek yok! 💪',
                    ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('Deftere dön')),
            ),
          ],
        ),
      ),
    );
  }
}
