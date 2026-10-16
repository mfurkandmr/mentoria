import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/sound/app_sounds.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/motion.dart';
import '../../../shared/widgets/bizz.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../auth/data/auth_repository.dart';
import '../data/notification_repository.dart';

/// Bildirimin gösterdiği yere gider. Ödev listesi üstüne açılır (geri
/// tuşuyla dönülebilsin); deneme ve görevler panelin sekmesine geçer.
void openNotification(BuildContext context, AppNotification n) {
  final router = GoRouter.of(context);
  if (n.route == '/student/homework') {
    router.push(n.route);
  } else {
    router.go(n.route);
  }
}

/// Okunmamış sayısını gösteren zil. Yeni bildirim gelince sallanır.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentProfileProvider).value?.id;
    if (uid == null) return const SizedBox.shrink();
    final unread = ref.watch(unreadNotificationCountProvider(uid));
    return IconButton(
      tooltip: tr('Bildirimler'),
      color: color,
      onPressed: () => context.push('/student/notifications'),
      icon: TweenAnimationBuilder<double>(
        key: ValueKey(unread),
        tween: Tween(begin: unread > 0 && Motion.of(context) ? 1 : 0, end: 0),
        duration: const Duration(milliseconds: 900),
        builder: (_, v, child) => Transform.rotate(
          // Sönümlenen sallanma.
          angle: 0.4 * v * math.sin(v * 6 * math.pi),
          alignment: Alignment.topCenter,
          child: child,
        ),
        child: Badge(
          isLabelVisible: unread > 0,
          backgroundColor: context.brand.danger,
          label: Text(unread > 9 ? '9+' : '$unread'),
          child: Icon(
            unread > 0
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
          ),
        ),
      ),
    );
  }
}

/// Bildirim listesi. Açılınca hepsi okundu sayılır; bu açılışta yeni olanlar
/// yine de vurgulu görünür.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Set<String>? _freshIds;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentProfileProvider).value?.id;
    if (uid == null) return const Scaffold(body: Center(child: BizzLoader()));
    final value = ref.watch(notificationsProvider(uid));

    final list = value.value;
    if (list != null && _freshIds == null) {
      _freshIds = {for (final n in list.where((n) => n.unread)) n.id};
      if (_freshIds!.isNotEmpty) {
        Future.microtask(
          () => ref.read(notificationRepositoryProvider).markAllRead(uid),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('Bildirimler'))),
      body: AsyncView(
        value: value,
        builder: (items) {
          if (items.isEmpty) {
            return EmptyState(
              title: tr('Henüz bildirim yok'),
              message: tr(
                'Koçun ödev, görev ya da deneme sonucu gönderince burada göreceksin.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => FadeSlideIn(
              delay: FadeSlideIn.stagger(i.clamp(0, 10), 40),
              child: NotificationTile(
                notification: items[i],
                highlight: _freshIds?.contains(items[i].id) ?? false,
                onTap: () => openNotification(context, items[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    this.highlight = false,
    this.onTap,
  });

  final AppNotification notification;
  final bool highlight;
  final VoidCallback? onTap;

  static String timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return tr('az önce');
    if (d.inMinutes < 60) return tr('{n} dk önce', {'n': d.inMinutes});
    if (d.inHours < 24) return tr('{n} sa önce', {'n': d.inHours});
    if (d.inDays < 7) return tr('{n} gün önce', {'n': d.inDays});
    return DateFormat('d MMM', localeTag).format(t);
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: highlight ? context.brand.primary.withValues(alpha: 0.14) : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: switch (n.kind) {
                  NotificationKind.assignment => context.brand.primary,
                  NotificationKind.exam => context.brand.secondary,
                  NotificationKind.task => context.brand.success,
                  NotificationKind.note => context.brand.info,
                  NotificationKind.deletionRequest => context.brand.danger,
                  NotificationKind.meeting => context.brand.secondary,
                },
                foregroundColor:
                    n.kind == NotificationKind.exam ||
                        n.kind == NotificationKind.deletionRequest ||
                        n.kind == NotificationKind.meeting
                    ? Colors.white
                    : context.brand.ink,
                child: Icon(n.kind.icon, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (n.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        n.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(timeAgo(n.createdAt), style: text.labelSmall),
                  if (highlight) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.brand.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uygulama açıkken yeni bildirim gelirse yukarıdan kayan bir kart gösterir.
/// Öğrenci panelini sarar.
class InAppNotifier extends ConsumerStatefulWidget {
  const InAppNotifier({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InAppNotifier> createState() => _InAppNotifierState();
}

class _InAppNotifierState extends ConsumerState<InAppNotifier> {
  Set<String>? _seen;
  OverlayEntry? _entry;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _entry?.remove();
    super.dispose();
  }

  void _show(AppNotification n) {
    _timer?.cancel();
    _entry?.remove();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    HapticFeedback.mediumImpact();
    // Telefon bildirimiyle aynı, Mentoria'ya özel ses (ayarlardan kapatılabilir).
    unawaited(AppSounds.play(AppSound.notification));
    late OverlayEntry entry;
    void close() {
      if (_entry == entry) {
        _entry = null;
        entry.remove();
      }
    }

    entry = OverlayEntry(
      builder: (_) => _Banner(
        notification: n,
        onTap: () {
          close();
          if (mounted) openNotification(context, n);
        },
        onDismiss: close,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(seconds: 5), close);
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentProfileProvider).value?.id;
    if (uid != null) {
      ref.listen(notificationsProvider(uid), (_, next) {
        final list = next.value;
        if (list == null) return;
        final ids = {for (final n in list) n.id};
        final seen = _seen;
        _seen = ids;
        // İlk yüklemede eski bildirimler için kart çıkmasın.
        if (seen == null) return;
        final fresh = list.where((n) => n.unread && !seen.contains(n.id));
        if (fresh.isNotEmpty) _show(fresh.first);
      });
    }
    return widget.child;
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      left: 12,
      right: 12,
      top: top + 8,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: Motion.of(context) ? 520 : 0),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Transform.translate(
          offset: Offset(0, -120 * (1 - v)),
          child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
        ),
        child: Dismissible(
          key: ValueKey(notification.id),
          direction: DismissDirection.up,
          onDismissed: (_) => onDismiss(),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(20),
            color: context.brand.ink,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
                child: Row(
                  children: [
                    const Bizz(
                      size: 44,
                      mood: BizzMood.happy,
                      interactive: false,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (notification.body.isNotEmpty)
                            Text(
                              notification.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(notification.kind.icon, color: context.brand.primary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
