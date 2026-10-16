import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/motion.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../auth/data/auth_repository.dart';
import '../data/avatar_models.dart';
import '../data/avatar_repository.dart';
import 'avatar_rule_text.dart';
import 'student_avatar.dart';
import '../../ranking/data/ranking_repository.dart';

/// Avatar editörü: kategori sekmeleri, anlık önizleme, kilitli parçalar.
/// Fotoğraf ya da yüz verisi kullanılmaz; avatar yalnızca parça seçimidir.
class AvatarEditorScreen extends ConsumerStatefulWidget {
  const AvatarEditorScreen({super.key});

  @override
  ConsumerState<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends ConsumerState<AvatarEditorScreen> {
  AvatarConfig? _saved;
  AvatarConfig? _draft;
  bool _saving = false;
  int _bounce = 0;

  bool get _dirty => _draft != null && _draft != _saved;

  void _pick(AvatarCategory c, int? id) {
    HapticFeedback.selectionClick();
    setState(() {
      _draft = _draft!.withPart(c, id);
      _bounce++;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(avatarRepositoryProvider).saveAvatar(_draft!);
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      setState(() {
        _saved = _draft;
        _saving = false;
      });
      celebrate(context);
      showMessage(context, tr('Avatarın kaydedildi 🐝'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(
        context,
        '$e'.contains('AVATAR_ITEM_LOCKED')
            ? tr('Bu parça henüz açılmadı.')
            : tr('Kaydedilemedi. Tekrar dene.'),
      );
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    return confirm(
      context,
      title: tr('Değişiklikler kaydedilmedi'),
      message: tr('Çıkarsan yaptığın değişiklikler kaybolur.'),
      action: tr('Çık'),
    );
  }

  void _showLocked(AvatarItem item) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StudentAvatar(
                config: _draft!.withPart(item.category, item.id),
                size: 120,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    tr('Kilitli parça'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                tr('Açmak için: {rule}', {'rule': item.rule.describe()}),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final catalog = ref.watch(avatarCatalogProvider);
    final unlocks = ref.watch(avatarUnlocksProvider);

    // Yeni açılan parçalar varsa kutla.
    ref.listen(avatarUnlocksProvider, (_, next) {
      final fresh = next.value?.fresh ?? const [];
      if (fresh.isNotEmpty && mounted) {
        celebrate(context);
        showMessage(
          context,
          tr('{n} yeni avatar parçası açıldı! 🎉', {'n': fresh.length}),
        );
      }
    });

    if (profile != null && _saved == null) {
      _saved = AvatarConfig.fromJson(profile.avatar);
      _draft = _saved;
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) {
          setState(() => _draft = _saved);
          navigator.pop();
        }
      },
      child: DefaultTabController(
        length: AvatarCategory.editorOrder.length,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr('Avatarım')),
            bottom: TabBar(
              tabs: [
                for (final c in AvatarCategory.editorOrder) Tab(text: c.label),
              ],
            ),
          ),
          body: _draft == null
              ? const BizzLoader()
              : AsyncView(
                  value: catalog,
                  onRetry: () => ref.invalidate(avatarCatalogProvider),
                  builder: (items) {
                    final unlocked = unlocks.value?.unlocked ?? const <int>{};
                    return Column(
                      children: [
                        const SizedBox(height: 16),
                        _Preview(config: _draft!, bounce: _bounce),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                          child: Text(
                            tr(
                              'Avatarın yalnızca seçtiğin parçalardan oluşur; fotoğraf kullanılmaz.',
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              for (final c in AvatarCategory.editorOrder)
                                _ItemGrid(
                                  category: c,
                                  items:
                                      items.values
                                          .where((i) => i.category == c)
                                          .toList()
                                        ..sort(
                                          (a, b) => a.sort.compareTo(b.sort),
                                        ),
                                  draft: _draft!,
                                  unlocked: unlocked,
                                  onPick: (id) => _pick(c, id),
                                  onLocked: _showLocked,
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              onPressed: _dirty && !_saving ? _save : null,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_dirty ? tr('Kaydet') : tr('Kaydedildi')),
            ),
          ),
        ),
      ),
    );
  }
}

/// Büyük önizleme: her değişiklikte hafif bir zıplama.
class _Preview extends ConsumerWidget {
  const _Preview({required this.config, required this.bounce});

  final AvatarConfig config;
  final int bounce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = StudentAvatar(
      config: config,
      // Sıralama ödülü (taç, kanatlar) editörde de görünsün.
      reward: ref.watch(myAvatarRewardProvider),
      size: 168,
      semanticLabel: tr('Avatar önizlemesi'),
    );
    if (!Motion.of(context)) return avatar;
    return TweenAnimationBuilder<double>(
      key: ValueKey(bounce),
      tween: Tween(begin: bounce == 0 ? 1 : 0.92, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: avatar,
    );
  }
}

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({
    required this.category,
    required this.items,
    required this.draft,
    required this.unlocked,
    required this.onPick,
    required this.onLocked,
  });

  final AvatarCategory category;
  final List<AvatarItem> items;
  final AvatarConfig draft;
  final Set<int> unlocked;
  final ValueChanged<int?> onPick;
  final ValueChanged<AvatarItem> onLocked;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (category.optional)
        _Tile(
          selected: draft[category] == null,
          locked: false,
          label: tr('Yok'),
          onTap: () => onPick(null),
          child: StudentAvatar(
            config: draft.withPart(category, null),
            size: 76,
            background: false,
          ),
        ),
      for (final item in items)
        _Tile(
          selected: draft[category] == item.id,
          locked: !item.rule.isFree && !unlocked.contains(item.id),
          label: item.rule.isFree ? null : item.rule.describe(),
          onTap: () => !item.rule.isFree && !unlocked.contains(item.id)
              ? onLocked(item)
              : onPick(item.id),
          child: StudentAvatar(
            config: draft.withPart(category, item.id),
            size: 76,
            background: false,
          ),
        ),
    ];
    return GridView.extent(
      maxCrossAxisExtent: 120,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.82,
      children: tiles,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.selected,
    required this.locked,
    required this.onTap,
    required this.child,
    this.label,
  });

  final bool selected;
  final bool locked;
  final VoidCallback onTap;
  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: [
        if (locked) tr('Kilitli'),
        if (selected) tr('Seçili'),
        ?label,
      ].join(', '),
      child: PressScale(
        child: Material(
          color: selected
              ? brand.primary.withValues(alpha: 0.18)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              width: selected ? 3 : 1,
              color: selected ? brand.primaryDeep : scheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(opacity: locked ? 0.35 : 1, child: child),
                        if (locked)
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: brand.ink,
                            child: Icon(
                              Icons.lock_rounded,
                              size: 16,
                              color: brand.primary,
                            ),
                          ),
                        if (selected)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: brand.success,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (label != null)
                    Text(
                      label!,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
